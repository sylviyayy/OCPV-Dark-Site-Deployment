#!/usr/bin/env bash
# Steady-state NTP VM, then cut the nodes over (Lab 14 step 14.2; FR-H6, FR-H9, FR-H12).
#
# Order matters: the resolver NNCP and the chrony MachineConfig roll out only after both DNS
# VMs answer, and the bastion keeps serving DNS and NTP as the permanent secondary (ADR-07).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd oc python3 dig chronyd
use_kubeconfig

NS=infrastructure
OUT="${INSTALL_DIR}/manifests"
mkdir -p "${OUT}"

# --- NTP VM ---
VM_NAME=ntp VM_IP="${NTP_VM_IP}" \
  render text "${REPO_ROOT}/manifests/production/ntp-vm/ntp-vm.yaml.template" "${OUT}/ntp.yaml"
oc apply -f "${OUT}/ntp.yaml"
if ! oc wait vm/ntp -n "${NS}" --for=condition=Ready --timeout=1800s; then   # VM, not VMI: see script 07
  oc get vm,vmi,dv,pvc -n "${NS}"
  exit 1
fi
ntp_vm_ok() { ntp_offset_ok "${NTP_VM_IP}"; }
if ! wait_until 900 20 "NTP VM ${NTP_VM_IP} serves time with offset < 1 s" ntp_vm_ok; then
  log_error "Check cloud-init in the guest: virtctl console ntp -n ${NS}"
  exit 1
fi

# --- Precondition for the cut-over: both DNS VMs answer (FR-H9 ordering) ---
for ip in "${DNS_VM1_IP}" "${DNS_VM2_IP}"; do
  if ! expect_dns "${ip}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${API_VIP}"; then
    log_error "DNS VM ${ip} does not answer; finish ./scripts/07-deploy-dns-vm.sh before cutting over"
    exit 1
  fi
done

# --- Resolver cut-over through NMState, never a MachineConfig over resolv.conf (FR-H6) ---
render text "${REPO_ROOT}/manifests/production/dns-vm/nncp-dns-cutover.yaml.template" "${OUT}/nncp-dns-cutover.yaml"
oc apply -f "${OUT}/nncp-dns-cutover.yaml"
if ! oc wait nncp/dns-cutover --for=condition=Available --timeout=300s; then
  oc get nncp,nnce
  exit 1
fi

# --- Node time sources: NTP VM first, TIME_SOURCE (or the bastion) second ---
render text "${REPO_ROOT}/manifests/production/ntp-vm/machineconfig-chrony.yaml.template" "${OUT}/machineconfig-chrony.yaml"
oc apply -f "${OUT}/machineconfig-chrony.yaml"
log_info "MachineConfig rolling out: nodes drain and reboot one at a time."
# Done means: the pool's desired config includes our MachineConfig, every node runs it
# (status == spec), and the pool reports Updated. Checking Updated alone can pass before the
# Machine Config Operator has even started, because the pool was Updated before the change.
mcp_rolled_out() {
  local src cur want upd
  src="$(oc get mcp master -o jsonpath='{.spec.configuration.source[*].name}')"
  want="$(oc get mcp master -o jsonpath='{.spec.configuration.name}')"
  cur="$(oc get mcp master -o jsonpath='{.status.configuration.name}')"
  upd="$(oc get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}')"
  [[ " ${src} " == *" 99-master-chrony-production "* && -n "${want}" && "${cur}" == "${want}" && "${upd}" == "True" ]]
}
if ! wait_until 5400 30 "mcp/master rolled out 99-master-chrony-production to every node" mcp_rolled_out; then
  oc get mcp
  oc get nodes
  exit 1
fi

log_info "PASS: NTP VM serving; node resolvers are ${DNS_VM1_IP}, ${DNS_VM2_IP}, ${BASTION_IP}; mcp/master Updated"
log_info "Keep dnsmasq and chronyd RUNNING on the bastion: it is the secondary resolver and time"
log_info "source, and the only one available during a cold start (ADR-07, FR-H12)."
log_info "Run validation: ./scripts/00-prerequisites-check.sh --post-install"
