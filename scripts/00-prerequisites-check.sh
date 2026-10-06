#!/usr/bin/env bash
# Stage-aware checks that assert values, not exit codes (FR-I1, FR-I2, FR-I3).
#
#   ./scripts/00-prerequisites-check.sh --staging        low-side staging host, before Lab 06
#   ./scripts/00-prerequisites-check.sh --bastion        bastion, after Lab 07
#   ./scripts/00-prerequisites-check.sh --post-install   bastion, after Lab 14 (Lab 15)
#
# Each mode first asserts the pinned OS for that machine role (Lab 01, PRD §4.1) and then
# requires only the tools that exist at that stage. Exit 1 if any check fails.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

MODE="${1:-}"
case "${MODE}" in
  --staging|--bastion|--post-install) ;;
  *) log_error "usage: $0 --staging | --bastion | --post-install"; exit 2 ;;
esac

load_env
validate_env

PASS=0
FAIL=0
# check DESCRIPTION CMD... — CMD is a function or command that returns one status. No
# pipelines here: a pipe would bind outside check() and swallow the PASS/FAIL line (FR-I1).
check() {
  local desc=$1
  shift
  if "$@" &>/dev/null; then
    echo "  [PASS] ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

# OCPV_OS_RELEASE lets tests/run-scripts.sh supply a RHEL 9 identity; hosts use /etc/os-release.
OS_RELEASE="${OCPV_OS_RELEASE:-/etc/os-release}"
os_is_rhel9() { grep -q '^ID="rhel"' "${OS_RELEASE}" && grep -q '^VERSION_ID="9\.' "${OS_RELEASE}"; }
os_is_fedora() { grep -q '^ID=fedora' "${OS_RELEASE}"; }
has_cmds() { local c; for c in "$@"; do command -v "$c" || return 1; done; }
has_rpms() { rpm -q "$@"; }
pull_secret_ok() { jq -e '.auths | length > 0' "${PULL_SECRET_FILE}"; }
reachable() { curl -sS -m 10 -o /dev/null "$1"; }
unreachable() { ! curl -sS -m 5 -o /dev/null "$1"; }
registry_ok() {  # TLS verified against the system trust store: no -k (FR-I4)
  local code
  code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' "https://${MIRROR_REGISTRY}/v2/")" || return 1
  [[ "${code}" == "200" || "${code}" == "401" ]]
}
clients_match() { openshift-install version | grep -q "${OCP_VERSION}"; }

nodes_ready() {            # true only if the API answers and every node is Ready
  local out
  out=$(oc get nodes --no-headers) || return 1
  [[ -n "${out}" ]] && ! awk '$2 != "Ready" {bad=1} END {exit !bad}' <<<"${out}"
}
cos_healthy() {            # every ClusterOperator Available=True and Degraded=False
  local out
  out=$(oc get co --no-headers) || return 1
  [[ -n "${out}" ]] && ! awk '$3 != "True" || $5 != "False" {bad=1} END {exit !bad}' <<<"${out}"
}
hco_available() {
  [[ "$(oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
        -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')" == "True" ]]
}
default_sc() {
  [[ "$(oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}')" \
     == "$(render value VM_STORAGE_CLASS)" ]]
}
nncp_available() {
  [[ "$(oc get nncp "$1" -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')" == "True" ]]
}
mcp_updated() {
  [[ "$(oc get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}')" == "True" ]]
}
samples_removed() {        # its image streams point at registry.redhat.io (Lab 12)
  [[ "$(oc get configs.samples.operator.openshift.io cluster -o jsonpath='{.spec.managementState}')" == "Removed" ]]
}
only_mirrored_catalogs() {  # FR-G2: no default catalog sources pointing at registry.redhat.io
  local names
  names="$(oc get catalogsource -n openshift-marketplace -o jsonpath='{.items[*].metadata.name}')"
  [[ -n "${names}" && "${names}" != *redhat-operators* && "${names}" != *certified-operators* \
     && "${names}" != *community-operators* && "${names}" != *redhat-marketplace* ]]
}

echo "=== OCP-V dark site checks (${MODE}) ==="

case "${MODE}" in
  --staging)
    echo "--- Machine role: connected staging host (low side) ---"
    if os_is_rhel9; then
      check "OS is RHEL 9.x" true
    elif os_is_fedora; then
      log_warn "Fedora is tolerated for learning only; partner delivery uses RHEL 9.x"
      check "OS is RHEL 9.x or tolerated Fedora" true
    else
      check "OS is RHEL 9.x" false
    fi
    check "tools: curl jq tar sha256sum skopeo python3 mkksiso" has_cmds curl jq tar sha256sum skopeo python3 mkksiso
    check "python3-pyyaml importable" python3 -c 'import yaml'
    check "pull secret has auths (F1)" pull_secret_ok
    check "reaches mirror.openshift.com" reachable https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/
    check "reaches registry.redhat.io" reachable https://registry.redhat.io/v2/
    ;;

  --bastion)
    echo "--- Machine role: bastion (high side) ---"
    check "OS is RHEL 9.x" os_is_rhel9
    check "RPMs from the DVD: dnsmasq chrony podman nmstate httpd python3-pyyaml" \
      has_rpms dnsmasq chrony podman nmstate httpd python3-pyyaml
    check "no route to the internet (quay.io unreachable)" unreachable https://quay.io
    check "clients on PATH: oc oc-mirror openshift-install" has_cmds oc oc-mirror openshift-install
    check "openshift-install reports ${OCP_VERSION}" clients_match
    echo "--- Bastion DNS answers .env values (FR-I2) ---"
    check "registry -> ${MIRROR_REGISTRY_IP}" expect_dns "${BASTION_IP}" "${MIRROR_REGISTRY_HOSTNAME}" "${MIRROR_REGISTRY_IP}"
    check "api -> ${API_VIP}" expect_dns "${BASTION_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${API_VIP}"
    check "api-int -> ${API_VIP}" expect_dns "${BASTION_IP}" "api-int.${CLUSTER_NAME}.${BASE_DOMAIN}" "${API_VIP}"
    check "*.apps -> ${INGRESS_VIP}" expect_dns "${BASTION_IP}" "console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" "${INGRESS_VIP}"
    check "PTR ${MW01_IP} -> ${MW01_HOSTNAME}.${BASE_DOMAIN}" expect_ptr "${BASTION_IP}" "${MW01_IP}" "${MW01_HOSTNAME}.${BASE_DOMAIN}"
    echo "--- Time and registry ---"
    check "bastion NTP offset < 1 s (chronyd -Q probe)" ntp_offset_ok "${BASTION_IP}"
    check "registry https://${MIRROR_REGISTRY}/v2/ answers 200/401 with TLS verified" registry_ok
    check "merged auth file has ${MIRROR_REGISTRY}" jq -e --arg r "${MIRROR_REGISTRY}" '.auths[$r]' "${AUTH_FILE}"
    ;;

  --post-install)
    require_cmd oc dig chronyd
    use_kubeconfig
    echo "--- Cluster health ---"
    check "API answers and all nodes Ready" nodes_ready
    check "all ClusterOperators Available and not Degraded" cos_healthy
    check "only mirrored CatalogSources" only_mirrored_catalogs
    check "Cluster Samples Operator Removed" samples_removed
    echo "--- Production DNS (both VMs) ---"
    for ip in "${DNS_VM1_IP}" "${DNS_VM2_IP}"; do
      check "${ip}: api -> ${API_VIP}" expect_dns "${ip}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${API_VIP}"
      check "${ip}: registry -> ${MIRROR_REGISTRY_IP}" expect_dns "${ip}" "${MIRROR_REGISTRY_HOSTNAME}" "${MIRROR_REGISTRY_IP}"
      check "${ip}: PTR ${MW01_IP}" expect_ptr "${ip}" "${MW01_IP}" "${MW01_HOSTNAME}.${BASE_DOMAIN}"
    done
    echo "--- Time ---"
    check "NTP VM offset < 1 s" ntp_offset_ok "${NTP_VM_IP}"
    check "bastion NTP still serving (secondary, ADR-07)" ntp_offset_ok "${BASTION_IP}"
    echo "--- Registry ---"
    check "registry answers with TLS verified" registry_ok
    echo "--- Virtualization, storage, network ---"
    check "HyperConverged Available" hco_available
    check "default StorageClass is $(render value VM_STORAGE_CLASS)" default_sc
    check "NNCP vmnet-bridge-mapping Available" nncp_available vmnet-bridge-mapping
    check "NNCP dns-cutover Available" nncp_available dns-cutover
    check "MachineConfigPool master Updated" mcp_updated
    ;;
esac

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
