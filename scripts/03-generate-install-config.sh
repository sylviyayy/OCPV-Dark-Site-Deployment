#!/usr/bin/env bash
# Generate install-config.yaml and agent-config.yaml for OCP 4.22 agent-based disconnected install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd jq

INSTALL_DIR="${REPO_ROOT}/install-config"
PULL_SECRET="${PULL_SECRET_FILE:-/opt/ocp-mirror/pull-secret.json}"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"
MIRROR_DIR="${MIRROR_DIR:-/opt/ocp-mirror}"
REGISTRY_CA="${MIRROR_DIR}/registry-ca.crt"
WORKDIR="${OC_MIRROR_WORKDIR:-${MIRROR_DIR}/oc-mirror-workdir}"

log_info "Generating OCP ${OCP_VERSION} agent-based install configuration"

if [[ ! -f "$PULL_SECRET" ]]; then
  log_error "Cluster pull secret not found: ${PULL_SECRET}"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  log_error "SSH public key not found: ${SSH_KEY}"
  exit 1
fi

mkdir -p "${INSTALL_DIR}/auth" "${INSTALL_DIR}/mirror"

# Registry CA for additionalTrustBundle
if [[ ! -f "$REGISTRY_CA" ]]; then
  log_warn "Registry CA not found at ${REGISTRY_CA}"
  log_warn "Attempting to fetch from registry..."
  echo | openssl s_client -connect "${MIRROR_REGISTRY_IP}:${MIRROR_REGISTRY##*:}" \
    -showcerts 2>/dev/null | openssl x509 -outform PEM > "$REGISTRY_CA" 2>/dev/null || true
fi

# Build install-config.yaml from template
sed \
  -e "s|ocpv-lab|${CLUSTER_NAME}|g" \
  -e "s|ocp-v.local|${BASE_DOMAIN}|g" \
  -e "s|10.10.0.100|${API_VIP}|g" \
  -e "s|10.10.0.101|${INGRESS_VIP}|g" \
  "${REPO_ROOT}/install-config/install-config.yaml.template" \
  > "${INSTALL_DIR}/install-config.yaml"

# Inject pull secret (compact JSON on one line)
PULL_JSON=$(jq -c . "$PULL_SECRET")
# Use python for safe YAML string replacement if available, else warn
if command -v python3 &>/dev/null; then
  python3 - "$INSTALL_DIR/install-config.yaml" "$PULL_JSON" <<'PY'
import sys, pathlib
path, secret = pathlib.Path(sys.argv[1]), sys.argv[2]
text = path.read_text().replace("'<PULL_SECRET>'", secret).replace("<PULL_SECRET>", secret)
path.write_text(text)
PY
else
  log_warn "Install pull secret manually into install-config.yaml"
fi

# Inject SSH key
SSH_CONTENT=$(cat "$SSH_KEY")
sed -i.bak "s|<SSH_PUBLIC_KEY>|${SSH_CONTENT}|g" "${INSTALL_DIR}/install-config.yaml"
rm -f "${INSTALL_DIR}/install-config.yaml.bak"

# Inject registry CA into additionalTrustBundle
if [[ -f "$REGISTRY_CA" ]]; then
  python3 - "$INSTALL_DIR/install-config.yaml" "$REGISTRY_CA" <<'PY' 2>/dev/null || true
import sys, pathlib
cfg, ca_file = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
ca = ca_file.read_text()
text = cfg.read_text().replace("<REGISTRY_CA_CERT>", ca.rstrip())
cfg.write_text(text)
PY
else
  log_warn "additionalTrustBundle not populated — add registry CA before creating ISO"
fi

# Generate agent-config.yaml with MAC addresses and rendezvousIP
export CP01_IP CP01_MAC CP02_IP CP02_MAC CP03_IP CP03_MAC
export WK01_IP WK01_MAC WK02_IP WK02_MAC
export BASTION_IP NETWORK_GATEWAY CLUSTER_NAME RENDEZVOUS_IP
export RENDEZVOUS_IP="${RENDEZVOUS_IP:-${CP01_IP}}"

envsubst '${CLUSTER_NAME} ${RENDEZVOUS_IP} ${CP01_IP} ${CP01_MAC} ${CP02_IP} ${CP02_MAC} \
${CP03_IP} ${CP03_MAC} ${WK01_IP} ${WK01_MAC} ${WK02_IP} ${WK02_MAC} \
${BASTION_IP} ${NETWORK_GATEWAY}' \
  < "${REPO_ROOT}/install-config/agent-config.yaml.template" \
  > "${INSTALL_DIR}/agent-config.yaml" 2>/dev/null || \
  sed \
    -e "s|ocpv-lab|${CLUSTER_NAME}|g" \
    -e "s|10.10.1.11|${CP01_IP}|g" \
    -e "s|10.10.0.5|${BASTION_IP}|g" \
    -e "s|10.10.0.1|${NETWORK_GATEWAY}|g" \
    -e "s|<RENDEZVOUS_IP>|${RENDEZVOUS_IP:-${CP01_IP}}|g" \
    -e "s|<CP01_MAC>|${CP01_MAC}|g" \
    -e "s|<CP02_MAC>|${CP02_MAC}|g" \
    -e "s|<CP03_MAC>|${CP03_MAC}|g" \
    -e "s|<WK01_MAC>|${WK01_MAC}|g" \
    -e "s|<WK02_MAC>|${WK02_MAC}|g" \
    "${REPO_ROOT}/install-config/agent-config.yaml.template" \
    > "${INSTALL_DIR}/agent-config.yaml"

# Copy oc-mirror cluster resources reference
if [[ -d "${WORKDIR}/cluster-resources" ]]; then
  cp -r "${WORKDIR}/cluster-resources" "${INSTALL_DIR}/cluster-resources"
  log_info "Copied oc-mirror cluster-resources to ${INSTALL_DIR}/cluster-resources/"
else
  log_warn "oc-mirror cluster-resources not found — apply after mirroring completes"
fi

log_info "Generated:"
log_info "  ${INSTALL_DIR}/install-config.yaml"
log_info "  ${INSTALL_DIR}/agent-config.yaml"
log_warn "Verify rendezvousIP=${RENDEZVOUS_IP:-${CP01_IP}} matches a control-plane node"
log_warn "Verify all MAC addresses match 'ip link' on each host"
log_info "Next: ./scripts/05-install-ocp-disconnected.sh"
