#!/usr/bin/env bash
# validate-env.sh — enforce the field register's Rule column before any script proceeds
# (PRD v2.0 FR-A3). A bad value surfaces here at second zero instead of as a stalled
# install 60-90 minutes later: the pre-flight checklist that catches the missing fuel cap
# on the ground. The rules themselves live in scripts/lib/render.py (one implementation).
#
# Sourced by scripts/lib/common.sh, which gives every script `validate_env`.
# Run directly for Lab 03:  ./scripts/lib/validate-env.sh [--env-file PATH] [--probe]

# validate_env [--probe] — exit 1 with one message per offending key.
validate_env() {
  if ! python3 "${REPO_ROOT}/scripts/lib/render.py" validate "$@"; then
    log_error "Fix the keys above in .env (field register: docs/labs/03-checklist.md), then re-run."
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  # shellcheck source=scripts/lib/common.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
  env_file=""
  probe=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env-file) env_file="$2"; shift 2 ;;
      --probe) probe=(--probe); shift ;;
      *) log_error "usage: $0 [--env-file PATH] [--probe]"; exit 2 ;;
    esac
  done
  load_env "${env_file:-${REPO_ROOT}/.env}"
  validate_env "${probe[@]}"
fi
