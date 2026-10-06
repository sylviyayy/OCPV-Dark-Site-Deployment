#!/usr/bin/env bash
# Create the Agent ISO in ${INSTALL_DIR} (Lab 08 step 8.2, FR-D7).
#
# openshift-install consumes install-config.yaml and agent-config.yaml when it builds the
# ISO. Copies are kept as *.orig so Lab 10 and any later audit can read what went in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env --probe   # B5/B6: the VIPs must not answer ping before install
refuse_root
# openshift-install validates each host's static networkConfig with nmstatectl.
require_cmd openshift-install nmstatectl

for f in install-config.yaml agent-config.yaml; do
  if [[ ! -f "${INSTALL_DIR}/${f}" ]]; then
    log_error "${INSTALL_DIR}/${f} not found. Run ./scripts/03-generate-install-config.sh first."
    exit 1
  fi
  cp -p "${INSTALL_DIR}/${f}" "${INSTALL_DIR}/${f}.orig"
done

log_info "openshift-install $(openshift-install version | head -n1 | awk '{print $2}') — expecting ${OCP_VERSION}"
log_info "Creating the Agent ISO in ${INSTALL_DIR} (pulls the release payload from ${MIRROR_REGISTRY})"
openshift-install agent create image --dir "${INSTALL_DIR}" --log-level info

ISO="${INSTALL_DIR}/agent.x86_64.iso"
if [[ ! -f "${ISO}" ]]; then
  log_error "openshift-install returned 0 but ${ISO} does not exist"
  exit 1
fi
sha256sum "${ISO}" | tee "${ISO}.sha256"

log_info "PASS: ${ISO} created; inputs kept as *.orig"
log_info "Next (Lab 10): mount the ISO on each XCC (${MW01_BMC_IP} ${MW02_BMC_IP} ${MW03_BMC_IP}),"
log_info "boot the rendezvous node (${RENDEZVOUS_IP}) first, then run ./scripts/05b-wait-install.sh"
