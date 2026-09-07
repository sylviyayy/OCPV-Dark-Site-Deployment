#!/usr/bin/env bash
# Deploy production DNS VM (BIND9) on OpenShift Virtualization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc

export KUBECONFIG="${REPO_ROOT}/install-config/auth/kubeconfig"
NAMESPACE="infrastructure"
MANIFEST_DIR="${REPO_ROOT}/manifests/production/dns-vm"

log_info "Deploying DNS VM at ${DNS_VM_IP}"

oc create namespace "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

# Apply all manifests with variable substitution
for manifest in "${MANIFEST_DIR}"/*.yaml; do
  [[ -f "$manifest" ]] || continue
  log_info "Applying $(basename "$manifest")..."
  sed \
    -e "s|DNS_VM_IP|${DNS_VM_IP}|g" \
    -e "s|BASE_DOMAIN|${BASE_DOMAIN}|g" \
    -e "s|CLUSTER_NAME|${CLUSTER_NAME}|g" \
    -e "s|MIRROR_REGISTRY|${MIRROR_REGISTRY}|g" \
    -e "s|BASTION_IP|${BASTION_IP}|g" \
    -e "s|MIRROR_REGISTRY_IP|${MIRROR_REGISTRY_IP}|g" \
    -e "s|API_VIP|${API_VIP}|g" \
    -e "s|INGRESS_VIP|${INGRESS_VIP}|g" \
    -e "s|CP01_IP|${CP01_IP}|g" \
    -e "s|CP02_IP|${CP02_IP}|g" \
    -e "s|CP03_IP|${CP03_IP}|g" \
    -e "s|WK01_IP|${WK01_IP}|g" \
    -e "s|WK02_IP|${WK02_IP}|g" \
    -e "s|NTP_VM_IP|${NTP_VM_IP}|g" \
    -e "s|NETWORK_GATEWAY|${NETWORK_GATEWAY}|g" \
    "$manifest" | oc apply -f -
done

log_info "Waiting for DNS VM to start..."
oc wait --for=condition=Ready \
  --timeout=600s \
  vmi/dns-server -n "${NAMESPACE}" 2>/dev/null || {
  log_warn "VM not ready yet. Monitor with: oc get vmi -n ${NAMESPACE} -w"
}

# Verify DNS
sleep 10
if dig "@${DNS_VM_IP}" "registry.${BASE_DOMAIN}" +short &>/dev/null; then
  log_info "DNS VM is serving queries!"
else
  log_warn "DNS not responding yet. VM may still be booting."
  log_warn "Check: oc console vmi/dns-server -n ${NAMESPACE}"
fi

if [[ "${1:-}" == "--update-zone" ]]; then
  log_info "Zone update requested — SSH to VM and reload BIND"
  log_info "  ssh root@${DNS_VM_IP} rndc reload"
fi

log_info ""
log_info "=== DNS VM deployed at ${DNS_VM_IP} ==="
log_info "Next: ./scripts/08-deploy-ntp-vm.sh"
