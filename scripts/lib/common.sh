#!/usr/bin/env bash
# Common functions for OCP-V dark site deployment scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

load_env() {
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/.env"
  elif [[ -f "${REPO_ROOT}/.env.example" ]]; then
    log_warn ".env not found, using .env.example defaults"
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/.env.example"
  else
    log_error "No .env or .env.example found in ${REPO_ROOT}"
    exit 1
  fi
}

log_info()  { echo "[INFO]  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo "[WARN]  $(date '+%H:%M:%S') $*" >&2; }
log_error() { echo "[ERROR] $(date '+%H:%M:%S') $*" >&2; }

require_cmd() {
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      log_error "Required command not found: $cmd"
      exit 1
    fi
  done
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
  fi
}

wait_for_port() {
  local host=$1 port=$2 timeout=${3:-60}
  local elapsed=0
  while ! nc -z "$host" "$port" 2>/dev/null; do
    sleep 2
    elapsed=$((elapsed + 2))
    if [[ $elapsed -ge $timeout ]]; then
      log_error "Timeout waiting for ${host}:${port}"
      return 1
    fi
  done
  log_info "${host}:${port} is reachable"
}
