#!/usr/bin/env bash
# Prerequisites check — run before and after installation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

MODE="${1:-pre-install}"
load_env

PASS=0
FAIL=0

check() {
  local desc=$1
  shift
  if "$@" &>/dev/null; then
    echo "  [PASS] $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== OCP-V Dark Site Prerequisites Check (${MODE}) ==="
echo

if [[ "$MODE" == "--post-install" ]]; then
  require_cmd oc dig chronyc curl
  export KUBECONFIG="${REPO_ROOT}/install-config/auth/kubeconfig"

  echo "--- Cluster Health ---"
  check "All nodes Ready" oc get nodes --no-headers | awk '{print $2}' | grep -qv Ready
  check "ClusterOperators available" oc get co --no-headers | awk '{print $3}' | grep -qv True

  echo "--- DNS (production) ---"
  check "DNS VM resolves registry" dig "@${DNS_VM_IP}" "registry.${BASE_DOMAIN}" +short
  check "DNS VM resolves API" dig "@${DNS_VM_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short

  echo "--- NTP (production) ---"
  check "NTP VM reachable" chronyc -h "${NTP_VM_IP}" tracking

  echo "--- Registry ---"
  check "Mirror registry catalog" curl -sk "https://${MIRROR_REGISTRY}/v2/_catalog"

  echo "--- CNV ---"
  check "HyperConverged available" oc get hyperconverged -n openshift-cnv --no-headers

else
  require_cmd podman skopeo jq curl

  echo "--- Staging Machine Tools ---"
  check "podman available" command -v podman
  check "skopeo available" command -v skopeo
  check "oc client available" command -v oc
  check "jq available" command -v jq

  echo "--- Configuration ---"
  check ".env file exists" test -f "${REPO_ROOT}/.env"
  check "Pull secret exists" test -f "${PULL_SECRET_FILE:-/opt/ocp-mirror/pull-secret.json}"

  echo "--- Network (if in dark site) ---"
  check "Bastion reachable" ping -c1 -W2 "${BASTION_IP}"
  check "Registry reachable" ping -c1 -W2 "${MIRROR_REGISTRY_IP}"
  check "Bastion DNS" dig "@${BASTION_IP}" "registry.${BASE_DOMAIN}" +short
  check "Bastion NTP" chronyc -h "${BASTION_IP}" tracking
fi

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
