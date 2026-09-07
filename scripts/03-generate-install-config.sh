#!/usr/bin/env bash
# Generate install-config.yaml and agent-config.yaml from templates and .env
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd jq

INSTALL_DIR="${REPO_ROOT}/install-config"
PULL_SECRET="${PULL_SECRET_FILE:-/opt/ocp-mirror/pull-secret.json}"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"

log_info "Generating install configuration"

if [[ ! -f "$PULL_SECRET" ]]; then
  log_error "Pull secret not found: ${PULL_SECRET}"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  log_error "SSH public key not found: ${SSH_KEY}"
  exit 1
fi

PULL_SECRET_CONTENT=$(cat "$PULL_SECRET" | jq -c .)
SSH_KEY_CONTENT=$(cat "$SSH_KEY")

# Fetch registry CA cert
REGISTRY_CA=""
if curl -sk "https://${MIRROR_REGISTRY}/v2/" &>/dev/null; then
  REGISTRY_CA=$(echo | openssl s_client -connect "${MIRROR_REGISTRY_IP}:5000" -showcerts 2>/dev/null \
    | openssl x509 -outform PEM 2>/dev/null || true)
fi

mkdir -p "${INSTALL_DIR}/auth"

# Generate install-config.yaml
sed \
  -e "s|<PULL_SECRET>|${PULL_SECRET_CONTENT}|g" \
  -e "s|<SSH_PUBLIC_KEY>|${SSH_KEY_CONTENT}|g" \
  -e "s|ocpv-lab|${CLUSTER_NAME}|g" \
  -e "s|ocp-v.local|${BASE_DOMAIN}|g" \
  -e "s|10.10.0.100|${API_VIP}|g" \
  -e "s|10.10.0.101|${INGRESS_VIP}|g" \
  "${REPO_ROOT}/install-config/install-config.yaml.template" \
  > "${INSTALL_DIR}/install-config.yaml"

# Generate agent-config.yaml
sed \
  -e "s|ocpv-lab|${CLUSTER_NAME}|g" \
  -e "s|10.10.1.11|${CP01_IP}|g" \
  -e "s|10.10.0.5|${BASTION_IP}|g" \
  -e "s|10.10.0.1|${NETWORK_GATEWAY}|g" \
  "${REPO_ROOT}/install-config/agent-config.yaml.template" \
  > "${INSTALL_DIR}/agent-config.yaml"

# Generate mirror config for post-install
sed \
  -e "s|registry.ocp-v.local:5000|${MIRROR_REGISTRY}|g" \
  -e "s|v4.14|v${OCP_VERSION%.*}|g" \
  "${REPO_ROOT}/install-config/mirror-config.yaml.template" \
  > "${INSTALL_DIR}/mirror-config-generated.yaml"

log_info "Generated files:"
log_info "  ${INSTALL_DIR}/install-config.yaml"
log_info "  ${INSTALL_DIR}/agent-config.yaml"
log_info "  ${INSTALL_DIR}/mirror-config-generated.yaml"
log_warn ""
log_warn "IMPORTANT: Edit agent-config.yaml to set correct MAC addresses for each node"
log_warn "  interfaces[].macAddress fields must match your hardware"
log_info ""
log_info "Next: ./scripts/05-install-ocp-disconnected.sh"
