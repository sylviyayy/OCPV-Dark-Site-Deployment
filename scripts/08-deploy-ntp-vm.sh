#!/usr/bin/env bash
# Deploy production NTP VM (chrony) on OpenShift Virtualization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc

export KUBECONFIG="${REPO_ROOT}/install-config/auth/kubeconfig"
NAMESPACE="infrastructure"
MANIFEST_DIR="${REPO_ROOT}/manifests/production/ntp-vm"

log_info "Deploying NTP VM at ${NTP_VM_IP}"

oc create namespace "${NAMESPACE}" --dry-run=client -o yaml | oc apply -f -

for manifest in "${MANIFEST_DIR}"/*.yaml; do
  [[ -f "$manifest" ]] || continue
  log_info "Applying $(basename "$manifest")..."
  sed \
    -e "s|NTP_VM_IP|${NTP_VM_IP}|g" \
    -e "s|BASE_DOMAIN|${BASE_DOMAIN}|g" \
    -e "s|MIRROR_REGISTRY|${MIRROR_REGISTRY}|g" \
    -e "s|NETWORK_GATEWAY|${NETWORK_GATEWAY}|g" \
    -e "s|NETWORK_CIDR|${NETWORK_CIDR}|g" \
    "$manifest" | oc apply -f -
done

log_info "Waiting for NTP VM to start..."
oc wait --for=condition=Ready \
  --timeout=600s \
  vmi/ntp-server -n "${NAMESPACE}" 2>/dev/null || {
  log_warn "VM not ready yet. Monitor with: oc get vmi -n ${NAMESPACE} -w"
}

sleep 10
if chronyc -h "${NTP_VM_IP}" tracking &>/dev/null; then
  log_info "NTP VM is serving time!"
else
  log_warn "NTP not responding yet. VM may still be booting."
fi

# Apply MachineConfig to cutover cluster DNS/NTP
log_info "Applying DNS/NTP cutover MachineConfigs..."
if [[ -f "${MANIFEST_DIR}/../dns-vm/machineconfig-dns.yaml" ]]; then
  sed -e "s|DNS_VM_IP|${DNS_VM_IP}|g" \
    "${MANIFEST_DIR}/../dns-vm/machineconfig-dns.yaml" | oc apply -f -
fi
if [[ -f "${MANIFEST_DIR}/machineconfig-ntp.yaml" ]]; then
  sed -e "s|NTP_VM_IP|${NTP_VM_IP}|g" \
    "${MANIFEST_DIR}/machineconfig-ntp.yaml" | oc apply -f -
fi

log_info ""
log_info "=== NTP VM deployed at ${NTP_VM_IP} ==="
log_info "Nodes will reboot to apply new DNS/NTP config."
log_info "Monitor: watch oc get mcp"
log_info ""
log_info "After all nodes are updated, decommission bastion MVP services:"
log_info "  ssh root@${BASTION_IP} 'systemctl stop dnsmasq chronyd && systemctl disable dnsmasq chronyd'"
log_info ""
log_info "Run validation: ./scripts/00-prerequisites-check.sh --post-install"
