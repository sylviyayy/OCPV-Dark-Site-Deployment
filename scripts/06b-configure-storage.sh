#!/usr/bin/env bash
# Default StorageClass for VM disks (Lab 13 step 13.2, FR-G3, ADR-05).
#
# Without a StorageClass every DataVolume — including both DNS VM root disks — stays Pending.
#   hpp   : hostpath provisioner (ships with OpenShift Virtualization) in a directory on each
#           node's RAID1 OS disk. Node-local ReadWriteOnce, no live migration. INTERIM / LAB-GRADE:
#           it shares the disk with etcd until the storage array is attached.
#   ontap : Lenovo ThinkSystem DM or DG array (NetApp ONTAP) through NetApp Trident over NFS.
#           ReadWriteMany, so VMs live-migrate during node drains. The target design.
#   lvms  : LVM Storage on one empty disk per node — local drives, or one LUN per node from a
#           block-only array such as the Lenovo DS series. ReadWriteOnce, no live migration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd oc python3 jq
use_kubeconfig

STORAGE_CLASS="$(render value VM_STORAGE_CLASS)"
# Polls send stderr to /dev/null: NotFound is expected until the operator creates the object;
# each timeout path prints the real diagnostics.

case "${STORAGE_BACKEND}" in
hpp)
  # TODO(verify-4.22): storage-pool path requirements (directory creation, SELinux label) per
  # https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/storage
  oc apply -f - <<EOF
apiVersion: hostpathprovisioner.kubevirt.io/v1beta1
kind: HostPathProvisioner
metadata:
  name: hostpath-provisioner
spec:
  imagePullPolicy: IfNotPresent
  storagePools:
    - name: local
      path: /var/hpvolumes
  workload:
    nodeSelector:
      kubernetes.io/os: linux
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS}
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubevirt.io.hostpath-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
parameters:
  storagePool: local
EOF
  hpp_available() {
    [[ "$(oc get hostpathprovisioner hostpath-provisioner \
          -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)" == "True" ]]
  }
  wait_until 600 15 "HostPathProvisioner Available" hpp_available || {
    oc get hostpathprovisioner hostpath-provisioner -o yaml | sed -n '/status:/,$p'
    exit 1
  }
  ;;

ontap)
  # 1. Credentials for the SVM account. The password is prompted and reaches jq through its
  #    environment and oc through stdin, never argv (NFR-4).
  read -rsp "ONTAP password for ${ONTAP_USER}@${ONTAP_SVM}: " ontap_pass; echo
  ONTAP_PASS="${ontap_pass}" jq -n --arg user "${ONTAP_USER}" '{
    apiVersion: "v1", kind: "Secret", type: "Opaque",
    metadata: {name: "ontap-svm-credentials", namespace: "trident"},
    stringData: {username: $user, password: env.ONTAP_PASS}
  }' | oc apply -f -
  unset ontap_pass

  # 2. Trident itself. Autosupport is silenced: a dark site cannot send it anywhere.
  # TODO(verify-4.22): Trident's own images and CSI sidecars must be in the mirror; if pods in
  #   namespace trident show ImagePullBackOff, add those images to the ImageSet and re-mirror.
  oc apply -f - <<'EOF'
apiVersion: trident.netapp.io/v1
kind: TridentOrchestrator
metadata:
  name: trident
spec:
  namespace: trident
  imagePullPolicy: IfNotPresent
  silenceAutosupport: true
EOF
  trident_installed() {
    [[ "$(oc get tridentorchestrator trident -o jsonpath='{.status.status}' 2>/dev/null)" == "Installed" ]]
  }
  wait_until 900 15 "Trident installed" trident_installed || { oc get pods -n trident; exit 1; }

  # 3. The ONTAP backend: NFS from the SVM's data LIF. With autoExportPolicy Trident keeps the
  #    SVM export policy limited to the machine network, so nobody maintains host lists by hand.
  oc apply -f - <<EOF
apiVersion: trident.netapp.io/v1
kind: TridentBackendConfig
metadata:
  name: ontap-nas
  namespace: trident
spec:
  version: 1
  storageDriverName: ontap-nas
  managementLIF: ${ONTAP_MGMT_IP}
  dataLIF: ${ONTAP_DATA_IP}
  svm: ${ONTAP_SVM}
  autoExportPolicy: true
  autoExportCIDRs:
    - ${MACHINE_NETWORK_CIDR}
  credentials:
    name: ontap-svm-credentials
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${STORAGE_CLASS}
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.trident.netapp.io
parameters:
  backendType: ontap-nas
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
  backend_bound() {
    [[ "$(oc get tridentbackendconfig ontap-nas -n trident -o jsonpath='{.status.phase}' 2>/dev/null)" == "Bound" ]]
  }
  wait_until 300 10 "ONTAP backend Bound (management LIF ${ONTAP_MGMT_IP}, SVM ${ONTAP_SVM})" backend_bound || {
    oc get tridentbackendconfig ontap-nas -n trident -o jsonpath='{.status.lastOperationStatus}: {.status.message}{"\n"}'
    exit 1
  }

  # 4. CDI picks access and volume mode from the StorageProfile; state them so DataVolumes using
  #    the storage: API get ReadWriteMany filesystem volumes, which is what live migration needs.
  profile_exists() { oc get storageprofile "${STORAGE_CLASS}" &>/dev/null; }
  wait_until 120 10 "StorageProfile ${STORAGE_CLASS} created by CDI" profile_exists || exit 1
  oc patch storageprofile "${STORAGE_CLASS}" --type merge \
    -p '{"spec":{"claimPropertySets":[{"accessModes":["ReadWriteMany"],"volumeMode":"Filesystem"}]}}'
  ;;

lvms)
  # LVMS: one device class over every empty disk on each node; its StorageClass is lvms-vg1.
  oc apply -f - <<'EOF'
apiVersion: lvm.topolvm.io/v1alpha1
kind: LVMCluster
metadata:
  name: lvmcluster
  namespace: openshift-storage
spec:
  storage:
    deviceClasses:
      - name: vg1
        default: true
        thinPoolConfig:
          name: thin-pool-1
          sizePercent: 90
          overprovisionRatio: 10
EOF
  lvms_ready() {
    [[ "$(oc get lvmcluster lvmcluster -n openshift-storage -o jsonpath='{.status.state}' 2>/dev/null)" == "Ready" ]]
  }
  wait_until 900 15 "LVMCluster Ready (needs an empty disk or LUN per node)" lvms_ready || {
    oc get lvmcluster lvmcluster -n openshift-storage -o yaml | sed -n '/status:/,$p'
    exit 1
  }
  oc annotate storageclass "${STORAGE_CLASS}" storageclass.kubernetes.io/is-default-class=true --overwrite
  ;;
esac

# Exactly one default: demote any other StorageClass still marked default (for example the
# interim hostpath-csi after moving to the storage array), so new DataVolumes cannot land on it.
for sc in $(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{" "}{end}'); do
  [[ "${sc}" == "${STORAGE_CLASS}" ]] || oc annotate storageclass "${sc}" storageclass.kubernetes.io/is-default-class=false --overwrite
done


# VERIFY (AT-09): exactly one default StorageClass, and a 1 GiB DataVolume binds.
defaults="$(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}')"
if [[ "${defaults}" != "${STORAGE_CLASS}" ]]; then
  log_error "default StorageClass is '${defaults//$'\n'/,}', expected exactly '${STORAGE_CLASS}'"
  exit 1
fi

oc create namespace storage-smoke --dry-run=client -o yaml | oc apply -f -
# WaitForFirstConsumer would park a consumer-less DataVolume forever; the CDI annotation
# asks for immediate binding so this smoke test can reach Succeeded on its own.
oc apply -f - <<EOF
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: smoke-1gi
  namespace: storage-smoke
  annotations:
    cdi.kubevirt.io/storage.bind.immediate.requested: "true"
spec:
  source:
    blank: {}
  storage:
    storageClassName: ${STORAGE_CLASS}
    resources:
      requests:
        storage: 1Gi
EOF
dv_succeeded() {
  [[ "$(oc get datavolume smoke-1gi -n storage-smoke -o jsonpath='{.status.phase}' 2>/dev/null)" == "Succeeded" ]]
}
if ! wait_until 600 10 "1 GiB test DataVolume Succeeded" dv_succeeded; then
  oc describe datavolume smoke-1gi -n storage-smoke | tail -n 20
  exit 1
fi
oc delete namespace storage-smoke --wait=false

log_info "PASS: default StorageClass ${STORAGE_CLASS}; a 1 GiB DataVolume reached Succeeded"
log_info "Next (Lab 14): ./scripts/07-deploy-dns-vm.sh"
