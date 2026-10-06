#!/usr/bin/env bash
# Install the operators Labs 13-14 need from the mirrored catalogs (Lab 13 step 13.1):
# OpenShift Virtualization and Kubernetes NMState, plus the storage operator STORAGE_BACKEND
# selects: NetApp Trident (ontap, certified catalog) or LVM Storage (lvms).
#
# Precondition: Lab 12 applied cluster-resources and disabled the default catalog sources.
# Official: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/installing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd oc python3
use_kubeconfig

# FR-G1: oc-mirror v2 names the CatalogSource after catalog image and tag (for example
# cs-redhat-operator-index-v4-22). Read the name from its output instead of guessing.
# TODO(verify-4.22): naming per the oc-mirror v2 documentation.
# Polling below sends stderr to /dev/null: while an object is still being created, `oc get`
# reports NotFound on every poll, and the timeout path prints the real diagnostics instead.
# wait_catalog INDEX — print the CatalogSource name oc-mirror gave INDEX once it is READY.
wait_catalog() {
  local cs
  cs="$(render catalog-source "$1")"
  catalog_ready() {
    [[ "$(oc get catalogsource "${cs}" -n openshift-marketplace \
          -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null)" == "READY" ]]
  }
  if ! wait_until 600 15 "CatalogSource ${cs} READY" catalog_ready >&2; then
    oc get catalogsource -n openshift-marketplace >&2
    log_error "Apply ${CLUSTER_RESOURCES_DIR} first (Lab 12)."
    exit 1
  fi
  echo "${cs}"
}
CATALOG_SOURCE="$(wait_catalog redhat-operator-index)"

# install_operator NAMESPACE PACKAGE CHANNEL [SOURCE] — OperatorGroup + Subscription, then wait
# for the subscribed CSV to reach Succeeded or exit 1 with diagnostics (FR-G4).
install_operator() {
  local ns=$1 pkg=$2 channel=$3 source=${4:-${CATALOG_SOURCE}}
  oc create namespace "${ns}" --dry-run=client -o yaml | oc apply -f -
  oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${pkg}-group
  namespace: ${ns}
spec:
  targetNamespaces:
    - ${ns}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${pkg}
  namespace: ${ns}
spec:
  channel: ${channel}
  name: ${pkg}
  source: ${source}
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
  csv_succeeded() {
    local csv
    csv="$(oc get subscription "${pkg}" -n "${ns}" -o jsonpath='{.status.installedCSV}' 2>/dev/null)"
    [[ -n "${csv}" && "$(oc get csv "${csv}" -n "${ns}" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Succeeded" ]]
  }
  if ! wait_until 900 15 "${pkg} CSV Succeeded in ${ns}" csv_succeeded; then
    oc get subscription,installplan,csv -n "${ns}"
    oc get subscription "${pkg}" -n "${ns}" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
    exit 1
  fi
}

# --- OpenShift Virtualization ---
install_operator openshift-cnv kubevirt-hyperconverged stable

# Only one non-default setting (FR-G5): automatic import of Red Hat golden OS images is off,
# because it pulls from registry.redhat.io and in a dark site retries and fails forever. VMs
# here use the digest-pinned guest image from the mirror instead (Lab 14).
oc apply -f - <<'EOF'
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  enableCommonBootImageImport: false
EOF
hco_available() {
  [[ "$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)" == "True" ]]
}
if ! wait_until 1200 30 "HyperConverged Available" hco_available; then
  oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
    -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
  oc get pods -n openshift-cnv --field-selector=status.phase!=Running
  exit 1
fi

# --- Kubernetes NMState: localnet bridge mapping and DNS cut-over NNCPs (ADR-06, ADR-07) ---
install_operator openshift-nmstate kubernetes-nmstate-operator stable
oc apply -f - <<'EOF'
apiVersion: nmstate.io/v1
kind: NMState
metadata:
  name: nmstate
EOF
handler_ready() { oc rollout status daemonset/nmstate-handler -n openshift-nmstate --timeout=10s &>/dev/null; }
if ! wait_until 600 15 "nmstate-handler DaemonSet rolled out" handler_ready; then
  oc get pods -n openshift-nmstate
  exit 1
fi

# --- Storage operator for STORAGE_BACKEND (ADR-05) ---
case "${STORAGE_BACKEND}" in
  ontap)
    # NetApp Trident for a Lenovo DM/DG (ONTAP) array, from the mirrored certified catalog.
    # TODO(verify-4.22): install mode and channel per the trident-operator bundle.
    install_operator trident trident-operator stable "$(wait_catalog certified-operator-index)" ;;
  lvms)
    install_operator openshift-storage lvms-operator "stable-${OCP_VERSION%.*}" ;;
esac

# --- /dev/kvm on every node (compact: all three run VMs). FR-G4: fail, do not warn. ---
missing=()
for node in $(oc get nodes -o jsonpath='{.items[*].metadata.name}'); do
  if oc debug "node/${node}" --quiet -- chroot /host test -c /dev/kvm; then
    log_info "${node}: /dev/kvm present"
  else
    missing+=("${node}")
  fi
done
if (( ${#missing[@]} > 0 )); then
  log_error "/dev/kvm missing on: ${missing[*]} — enable AMD SVM in UEFI (Lab 05 step 5.2)"
  exit 1
fi

oc get csv -n openshift-cnv
log_info "PASS: OpenShift Virtualization Available; NMState ready; KVM on all nodes"
log_info "Next (Lab 13 step 13.2): ./scripts/06b-configure-storage.sh"
