#!/usr/bin/env bash
# Default StorageClass for VM disks (Lab 13 step 13.2, FR-G3, ADR-05).
#
# Without a StorageClass every DataVolume — including both DNS VM root disks — stays Pending.
#   STORAGE_BACKEND=hpp  : hostpath provisioner (ships with OpenShift Virtualization), a
#                          directory on each node's RAID1 RHCOS disk. Node-local ReadWriteOnce:
#                          no live migration. LAB-GRADE (shares the disk with etcd).
#   STORAGE_BACKEND=lvms : LVM Storage on an empty data drive per node (none on the
#                          reference BOM; add drives first).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd oc python3
use_kubeconfig

STORAGE_CLASS="$(render value VM_STORAGE_CLASS)"

if [[ "${STORAGE_BACKEND}" == "hpp" ]]; then
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
else
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
  wait_until 900 15 "LVMCluster Ready (needs an empty data disk per node)" lvms_ready || {
    oc get lvmcluster lvmcluster -n openshift-storage -o yaml | sed -n '/status:/,$p'
    exit 1
  }
  oc annotate storageclass "${STORAGE_CLASS}" storageclass.kubernetes.io/is-default-class=true --overwrite
fi

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
