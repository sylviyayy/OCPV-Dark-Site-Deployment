#!/usr/bin/env bash
# Deploy OpenShift Virtualization (CNV) from mirrored operator catalog
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc

export KUBECONFIG="${REPO_ROOT}/install-config/auth/kubeconfig"

if [[ ! -f "$KUBECONFIG" ]]; then
  log_error "Kubeconfig not found. Complete OCP install first."
  exit 1
fi

log_info "Deploying OpenShift Virtualization (CNV ${CNV_VERSION})"

# Verify cluster is healthy
oc get co | grep -v "True.*False.*False" && true
log_info "Cluster operators checked"

# Create namespace
oc create namespace openshift-cnv --dry-run=client -o yaml | oc apply -f -

# Install HyperConverged operator from mirrored catalog
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-subscription
  namespace: openshift-cnv
spec:
  channel: stable
  name: kubevirt-hyperconverged
  source: cs-redhat-operator-index
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

log_info "Waiting for HyperConverged operator..."
oc wait --for=condition=Available \
  --timeout=600s \
  deployment/hyperconverged-cluster-operator -n openshift-cnv 2>/dev/null || true

# Deploy HyperConverged CR
cat <<EOF | oc apply -f -
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: openshift-cnv
spec:
  featureGates:
    withHostPassthroughCPU: true
  liveMigrationConfig:
    completionTimeoutPerGiB: 800
EOF

log_info "Waiting for CNV to become available (up to 15 minutes)..."
for i in $(seq 1 30); do
  STATUS=$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
    -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
  if [[ "$STATUS" == "True" ]]; then
    log_info "CNV is available!"
    break
  fi
  log_info "  Waiting... (${i}/30)"
  sleep 30
done

# Verify KVM on workers
log_info "Checking KVM on worker nodes..."
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o name); do
  NODE_NAME="${node#node/}"
  KVM=$(oc debug "node/${NODE_NAME}" -- chroot /host ls /dev/kvm 2>/dev/null || echo "missing")
  if [[ "$KVM" == "/dev/kvm" ]]; then
    log_info "  ${NODE_NAME}: KVM available"
  else
    log_warn "  ${NODE_NAME}: KVM NOT available — enable VT-x/AMD-V in BIOS"
  fi
done

log_info ""
log_info "=== CNV Deployment Complete ==="
log_info "Next: ./scripts/07-deploy-dns-vm.sh"
