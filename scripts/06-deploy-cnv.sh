#!/usr/bin/env bash
# Deploy OpenShift Virtualization 4.22 from mirrored operator catalog
#
# Official: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/installing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc

export KUBECONFIG="${REPO_ROOT}/install-config/auth/kubeconfig"
CNV_NS="openshift-cnv"
CATALOG_SOURCE="${CATALOG_SOURCE_NAME:-cs-redhat-operator-index}"

if [[ ! -f "$KUBECONFIG" ]]; then
  log_error "Kubeconfig not found. Complete OCP install first."
  exit 1
fi

log_info "Deploying OpenShift Virtualization (OCP ${OCP_VERSION}, channel ${CNV_CHANNEL})"

# Ensure mirrored catalog is available
if ! oc get catalogsource "${CATALOG_SOURCE}" -n openshift-marketplace &>/dev/null; then
  CLUSTER_RES="${REPO_ROOT}/install-config/cluster-resources"
  if [[ -d "$CLUSTER_RES" ]]; then
    log_info "Applying mirrored catalog from ${CLUSTER_RES}"
    oc apply -f "${CLUSTER_RES}/"
  else
    log_error "CatalogSource ${CATALOG_SOURCE} not found. Apply oc-mirror cluster-resources first."
    exit 1
  fi
fi

oc create namespace "${CNV_NS}" --dry-run=client -o yaml | oc apply -f -

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: kubevirt-hyperconverged-group
  namespace: ${CNV_NS}
spec:
  targetNamespaces:
    - ${CNV_NS}
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-subscription
  namespace: ${CNV_NS}
spec:
  channel: ${CNV_CHANNEL}
  name: ${CNV_PACKAGE}
  source: ${CATALOG_SOURCE}
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

log_info "Waiting for HyperConverged operator CSV..."
for i in $(seq 1 40); do
  PHASE=$(oc get csv -n "${CNV_NS}" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  [[ "$PHASE" == "Succeeded" ]] && break
  sleep 15
done

oc get csv -n "${CNV_NS}"

cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: ${CNV_NS}
spec:
  featureGates:
    withHostPassthroughCPU: true
  liveMigrationConfig:
    completionTimeoutPerGiB: 800
EOF

log_info "Waiting for HyperConverged Available condition..."
for i in $(seq 1 30); do
  STATUS=$(oc get hyperconverged kubevirt-hyperconverged -n "${CNV_NS}" \
    -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "")
  [[ "$STATUS" == "True" ]] && break
  sleep 30
done

oc get hyperconverged kubevirt-hyperconverged -n "${CNV_NS}" \
  -o jsonpath='Operator version: {.status.versions}{"\n"}'

log_info "Checking /dev/kvm on workers..."
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do
  if oc debug "node/${node}" -- chroot /host test -e /dev/kvm 2>/dev/null; then
    log_info "  ${node}: KVM available"
  else
    log_warn "  ${node}: KVM missing — enable VT-x/AMD-V in BIOS"
  fi
done

log_info "=== OpenShift Virtualization deployment complete ==="
log_info "Next: ./scripts/07-deploy-dns-vm.sh"
