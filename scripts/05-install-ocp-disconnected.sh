#!/usr/bin/env bash
# Disconnected OpenShift 4.22 installation using Agent-based Installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd openshift-install oc

INSTALL_DIR="${REPO_ROOT}/install-config"

if [[ ! -f "${INSTALL_DIR}/install-config.yaml" ]]; then
  log_error "install-config.yaml not found. Run 03-generate-install-config.sh first"
  exit 1
fi

log_info "Starting disconnected OCP ${OCP_VERSION} installation (Agent-based Installer)"
log_info "Cluster: ${CLUSTER_NAME}.${BASE_DOMAIN}"
log_info "Install directory: ${INSTALL_DIR}"

# Generate cluster manifests
log_info "Creating cluster manifests..."
openshift-install agent create cluster-manifests \
  --dir="${INSTALL_DIR}" \
  --log-level=info

# Generate discovery ISO
log_info "Creating agent discovery ISO..."
openshift-install agent create image \
  --dir="${INSTALL_DIR}" \
  --log-level=info

ISO_PATH="${INSTALL_DIR}/agent.x86_64.iso"
if [[ -f "$ISO_PATH" ]]; then
  log_info "Discovery ISO created: ${ISO_PATH}"
  log_info "Copy this ISO to USB and boot each node"
else
  log_error "ISO generation failed"
  exit 1
fi

echo
log_info "=== Boot Instructions ==="
log_info "1. Boot cp01, cp02, cp03 from the discovery ISO"
log_info "2. Boot wk01, wk02 from the discovery ISO"
log_info "3. Monitor installation:"
log_info "   openshift-install agent wait-for install-complete --dir=${INSTALL_DIR}"
echo

read -rp "Press Enter when all nodes have been booted from the ISO..."

log_info "Waiting for installation to complete (this takes 60-90 minutes)..."
openshift-install agent wait-for install-complete \
  --dir="${INSTALL_DIR}" \
  --log-level=info

export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"

log_info "Installation complete!"
oc get nodes

# Apply oc-mirror v2 cluster resources (IDMS, ITMS, CatalogSource)
CLUSTER_RES="${INSTALL_DIR}/cluster-resources"
if [[ -d "$CLUSTER_RES" ]]; then
  log_info "Applying mirror registry cluster resources from ${CLUSTER_RES}..."
  oc apply -f "${CLUSTER_RES}/"
else
  log_warn "cluster-resources/ not found — apply oc-mirror output manually"
  log_warn "  oc apply -f \${OC_MIRROR_WORKDIR}/cluster-resources/"
fi

log_info ""
log_info "=== Next Steps ==="
log_info "1. Verify cluster: oc get co"
log_info "2. Deploy OCP-V: ./scripts/06-deploy-cnv.sh"
log_info "3. Deploy DNS/NTP VMs: ./scripts/07-deploy-dns-vm.sh"
