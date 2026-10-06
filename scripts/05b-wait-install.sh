#!/usr/bin/env bash
# Wait for the Agent-based install to finish, then prove the result (Lab 10, FR-D7).
#
# Applying oc-mirror cluster-resources is NOT done here: Lab 12 owns that step (FR-D9).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd openshift-install oc

if [[ ! -f "${INSTALL_DIR}/agent.x86_64.iso" ]]; then
  log_error "No Agent ISO in ${INSTALL_DIR}. Run ./scripts/05a-create-agent-iso.sh (Lab 08) first."
  exit 1
fi

log_info "Waiting for bootstrap (the rendezvous node ${RENDEZVOUS_IP} runs the temporary control plane)"
openshift-install agent wait-for bootstrap-complete --dir "${INSTALL_DIR}" --log-level info
log_info "Waiting for install-complete (typically 60-90 minutes)"
openshift-install agent wait-for install-complete --dir "${INSTALL_DIR}" --log-level info

use_kubeconfig
oc get nodes -o wide

# VERIFY (AT-07): three Ready nodes, each bond0 with four members up.
ready="$(oc get nodes --no-headers | awk '$2 == "Ready"' | wc -l)"
if [[ "${ready}" != "3" ]]; then
  log_error "expected 3 Ready nodes, found ${ready}"
  exit 1
fi
for node in "${CP01_HOSTNAME}" "${CP02_HOSTNAME}" "${CP03_HOSTNAME}"; do
  # stderr carries oc debug's pod start/stop chatter; the bonding file arrives on stdout.
  bonding="$(oc debug "node/${node}" --quiet -- chroot /host cat /proc/net/bonding/bond0 2>/dev/null)"
  members="$(grep -c '^Slave Interface:' <<<"${bonding}" || true)"   # grep -c exits 1 on zero
  up="$(grep -c '^MII Status: up' <<<"${bonding}" || true)"
  if [[ "${members}" != "4" || "${up}" != "5" ]]; then
    log_error "${node}: bond0 has ${members} members and ${up} 'MII Status: up' lines (expect 4 and 5)"
    exit 1
  fi
  log_info "${node}: bond0 has 4 members, all up"
done

log_info "PASS: install complete; 3 nodes Ready; every bond0 has 4 members up"
log_info "Next: Lab 11 (oc access), then Lab 12 (apply mirror cluster-resources)"
