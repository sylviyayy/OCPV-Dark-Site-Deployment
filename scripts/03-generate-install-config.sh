#!/usr/bin/env bash
# Render install-config.yaml and agent-config.yaml into ${INSTALL_DIR} (Lab 08).
#
# WHERE: bastion, as installer. Inputs: .env, ${AUTH_FILE}, ${REGISTRY_CA_FILE} and
# ${CLUSTER_RESOURCES_DIR}/idms-oc-mirror.yaml (all produced in Lab 06).
# The renderer builds data structures (host list, bond ports, PEM bundle), so generation
# is complete: no hand edit of the output is expected or allowed (FR-A1, rule E2).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd python3

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

if [[ -f "${INSTALL_DIR}/auth/kubeconfig" && "${FORCE}" == false ]]; then
  log_error "${INSTALL_DIR} already holds an installed cluster's kubeconfig."
  log_error "Re-rendering is only for a reinstall (Lab 16). Re-run with --force if that is the intent."
  exit 1
fi

mkdir -p "${INSTALL_DIR}"
chmod 700 "${INSTALL_DIR}"

log_info "Rendering ${INSTALL_DIR}/install-config.yaml"
render install-config "${INSTALL_DIR}/install-config.yaml"
log_info "Rendering ${INSTALL_DIR}/agent-config.yaml"
render agent-config "${INSTALL_DIR}/agent-config.yaml"

# VERIFY (Lab 08 step 8.1): assert values, not exit codes.
macs="$(grep -c 'macAddress:' "${INSTALL_DIR}/agent-config.yaml")"
if [[ "${macs}" != "12" ]]; then
  log_error "expected 12 macAddress entries (3 nodes x 4 bond members), found ${macs}"
  exit 1
fi
if grep -q -i '00:50:56' "${INSTALL_DIR}/agent-config.yaml"; then
  log_error "a VMware-OUI sample MAC reached agent-config.yaml"
  exit 1
fi
for src in ocp-release ocp-v4.0-art-dev; do
  if ! grep -q "quay.io/openshift-release-dev/${src}" "${INSTALL_DIR}/install-config.yaml"; then
    log_error "imageDigestSources does not map quay.io/openshift-release-dev/${src}"
    exit 1
  fi
done

log_info "PASS: 12 MACs from .env, no sample MACs, release mirrors mapped"
log_info "Next (Lab 08 step 8.2): ./scripts/05a-create-agent-iso.sh"
