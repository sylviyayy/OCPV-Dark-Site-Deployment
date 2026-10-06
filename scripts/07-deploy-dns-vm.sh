#!/usr/bin/env bash
# Steady-state DNS: two anti-affine authoritative DNS VMs on OpenShift Virtualization
# (Lab 14 step 14.1; ADR-06, ADR-07; FR-H1..H5, H7, H8, H13).
#
# Manifests are rendered by scripts/lib/render.py into ${INSTALL_DIR}/manifests (FR-H4):
# no sed token chains, so MIRROR_REGISTRY can never corrupt MIRROR_REGISTRY_IP again.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

load_env
validate_env
refuse_root
require_cmd oc python3 jq dig
use_kubeconfig

if [[ "${VM_NETWORK_MODEL}" != "localnet" ]]; then
  # ADR-06's linux-bridge alternative needs spare-NIC port names the v2.0 field register
  # does not define; fail loudly rather than build a bridge with no uplink.
  log_error "VM_NETWORK_MODEL=${VM_NETWORK_MODEL} is not implemented in v2.0; use localnet (docs/DECISIONS.md ADR-06)"
  exit 1
fi

NS=infrastructure
OUT="${INSTALL_DIR}/manifests"
mkdir -p "${OUT}"
oc create namespace "${NS}" --dry-run=client -o yaml | oc apply -f -

# --- VM network: localnet "vmnet" on br-ex, plus the PriorityClass (FR-H5, FR-H11) ---
oc apply -f "${REPO_ROOT}/manifests/production/network/"
if ! oc wait nncp/vmnet-bridge-mapping --for=condition=Available --timeout=300s; then
  oc get nncp,nnce
  exit 1
fi

# --- What the CDI importer needs to pull the guest image from the mirror (FR-H7) ---
oc create configmap registry-ca -n "${NS}" --from-file=ca.pem="${REGISTRY_CA_FILE}" \
  --dry-run=client -o yaml | oc apply -f -
creds="$(jq -r --arg r "${MIRROR_REGISTRY}" '.auths[$r].auth // empty' "${AUTH_FILE}" | base64 -d)"
if [[ "${creds}" != *:* ]]; then
  log_error "${AUTH_FILE} has no credentials for ${MIRROR_REGISTRY} (Lab 06 step 6.8)"
  exit 1
fi
# The credentials reach jq through its environment and oc through stdin, never argv
# (NFR-4); jq JSON-encodes them, so any character in the password is safe.
CREDS="${creds}" NS="${NS}" jq -n '{
  apiVersion: "v1", kind: "Secret", type: "Opaque",
  metadata: {name: "registry-pull", namespace: env.NS},
  stringData: {accessKeyId: (env.CREDS | split(":")[0]), secretKey: (env.CREDS | sub("^[^:]*:"; ""))}
}' | oc apply -f -
unset creds

# --- Two DNS VMs, rendered from one template ---
for vm in "dns-a:${DNS_VM1_IP}" "dns-b:${DNS_VM2_IP}"; do
  VM_NAME="${vm%%:*}" VM_IP="${vm#*:}" \
    render text "${REPO_ROOT}/manifests/production/dns-vm/dns-vm.yaml.template" "${OUT}/${vm%%:*}.yaml"
  oc apply -f "${OUT}/${vm%%:*}.yaml"
done

for vm in dns-a dns-b; do
  if ! oc wait "vmi/${vm}" -n "${NS}" --for=condition=Ready --timeout=1200s; then
    oc get vm,vmi,dv,pvc -n "${NS}"
    oc describe datavolume "${vm}-rootdisk" -n "${NS}" | tail -n 20
    exit 1
  fi
done
nodes="$(oc get vmi dns-a dns-b -n "${NS}" -o jsonpath='{.items[*].status.nodeName}')"
read -r node_a node_b <<<"${nodes}"
if [[ "${node_a}" == "${node_b}" ]]; then
  log_error "dns-a and dns-b both run on ${node_a}; anti-affinity was not honoured (FR-H8)"
  exit 1
fi

# --- VERIFY from the bastion: answers match .env (cloud-init needs a few minutes) ---
answers_ok() {
  local ip
  for ip in "${DNS_VM1_IP}" "${DNS_VM2_IP}"; do
    expect_dns "${ip}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${API_VIP}" || return 1
    expect_dns "${ip}" "${MIRROR_REGISTRY_HOSTNAME}" "${MIRROR_REGISTRY_IP}" || return 1
    expect_dns "${ip}" "console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" "${INGRESS_VIP}" || return 1
    expect_ptr "${ip}" "${MW01_IP}" "${MW01_HOSTNAME}.${BASE_DOMAIN}" || return 1
  done
}
if ! wait_until 900 20 "both DNS VMs answer A, wildcard and PTR records from .env" answers_ok; then
  log_error "Check cloud-init in the guest: virtctl console dns-a -n ${NS}; then 'cloud-init status --long'"
  exit 1
fi

log_info "PASS: dns-a (${DNS_VM1_IP}, ${node_a}) and dns-b (${DNS_VM2_IP}, ${node_b}) serve .env records"
log_info "Next (Lab 14 step 14.2): ./scripts/08-deploy-ntp-vm.sh"
