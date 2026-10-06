#!/usr/bin/env bash
# Common functions for OCP-V dark site deployment scripts.
# Sourced by every script after `set -euo pipefail`; never executed on its own.

# Resolve the repo from this file's own location. BASH_SOURCE[0] is common.sh itself,
# so the repo root is two levels up (scripts/lib -> scripts -> repo). Deriving it from
# the caller's SCRIPT_DIR instead made REPO_ROOT point at scripts/ and every load_env fail.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${COMMON_DIR}/../.." && pwd)"
export REPO_ROOT

log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }

# load_env [ENV_FILE] — export every .env key (set -a) so child processes such as
# render.py and openshift-install inherit them. There is deliberately no fallback to
# .env.example: running on sample values is how sample MACs reach an ISO (FR-A4).
# OCPV_ENV_FILE selects another register explicitly (CI uses tests/ci.env).
load_env() {
  local env_file="${1:-${OCPV_ENV_FILE:-${REPO_ROOT}/.env}}"
  if [[ ! -f "${env_file}" ]]; then
    log_error "${env_file} not found."
    log_error "Create it from the template and fill in the field register (Lab 03):"
    log_error "  cp .env.example .env && vim .env"
    exit 1
  fi
  # sudo resets HOME to /root; expand ${HOME} in .env as the invoking user so root-run
  # steps (02, 04 install-registry, 04b) resolve the same paths as everything else.
  if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" ]]; then
    HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
  fi
  set -a
  # shellcheck disable=SC1090  # path is chosen at run time
  source "${env_file}"
  set +a
  if [[ "${ENV_SCHEMA_VERSION:-1}" != "2" ]]; then
    log_error "${env_file} uses schema v${ENV_SCHEMA_VERSION:-1}; v2.0 scripts need ENV_SCHEMA_VERSION=2."
    log_error "Re-create it from .env.example (the key names changed; see CHANGELOG)."
    exit 1
  fi
  # Clients downloaded by Lab 06 take precedence over anything else on PATH.
  if [[ -n "${MIRROR_DIR:-}" && -d "${MIRROR_DIR}/clients" ]]; then
    PATH="${MIRROR_DIR}/clients:${PATH}"
  fi
  DNS_VM1_IP="${DNS_VM_IPS%%,*}"
  DNS_VM2_IP="${DNS_VM_IPS##*,}"
  if [[ "${TIME_SOURCE:-}" == "orphan" ]]; then
    TIME_UPSTREAM="${BASTION_IP:-}"
  else
    TIME_UPSTREAM="${TIME_SOURCE:-}"
  fi
  export PATH DNS_VM1_IP DNS_VM2_IP TIME_UPSTREAM
}

require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This step must run as root (use sudo)"
    exit 1
  fi
}

refuse_root() {
  if [[ $EUID -eq 0 ]]; then
    log_error "Run this step as the installer user, not root: files it writes must stay user-owned"
    exit 1
  fi
}

# render ARGS... — the single entry point to scripts/lib/render.py.
render() {
  python3 "${REPO_ROOT}/scripts/lib/render.py" "$@"
}

use_kubeconfig() {
  export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
  if [[ ! -f "${KUBECONFIG}" ]]; then
    log_error "${KUBECONFIG} not found. Complete Lab 10 (05b-wait-install.sh) first."
    exit 1
  fi
}

# expect_dns SERVER NAME EXPECTED — compare the answer, not the exit code (FR-I2).
expect_dns() {
  local server=$1 name=$2 expected=$3 got
  got="$(dig +short +time=2 +tries=1 "@${server}" "${name}" | tail -n1)"
  [[ "${got}" == "${expected}" ]]
}

# expect_ptr SERVER IP EXPECTED_FQDN — reverse lookup must return the node name.
expect_ptr() {
  local server=$1 ip=$2 expected=$3 got
  got="$(dig +short +time=2 +tries=1 "@${server}" -x "${ip}" | head -n1)"
  [[ "${got}" == "${expected}." ]]
}

# ntp_offset_ok SERVER — client-side probe; chronyd -Q prints the offset without touching
# the clock and needs no cmdallow on the server, unlike `chronyc -h` (FR-F2).
ntp_offset_ok() {
  local server=$1 line offset
  line="$(chronyd -Q -t 15 "server ${server} iburst maxsamples 4" 2>&1 | grep -m1 'System clock wrong by')" || return 1
  offset="$(sed -E 's/.*wrong by (-?[0-9.]+) seconds.*/\1/' <<<"${line}")"
  awk -v o="${offset}" 'BEGIN { if (o < 0) o = -o; exit !(o < 1.0) }'
}

# wait_until TIMEOUT_S INTERVAL_S DESCRIPTION CMD... — poll, then fail loudly (NFR-3).
wait_until() {
  local timeout=$1 interval=$2 desc=$3 elapsed=0
  shift 3
  until "$@"; do
    if (( elapsed >= timeout )); then
      log_error "Timed out after ${timeout}s waiting for: ${desc}"
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
  log_info "OK: ${desc}"
}

# shellcheck source=scripts/lib/validate-env.sh
source "${COMMON_DIR}/validate-env.sh"
