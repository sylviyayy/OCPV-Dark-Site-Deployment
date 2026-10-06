#!/usr/bin/env bash
# Render a helper-host kickstart from .env (Lab 04, FR-E4).
#
#   ./scripts/render-kickstart.sh bastion     -> ${INSTALL_DIR}/kickstart/ks-bastion.cfg
#   ./scripts/render-kickstart.sh registry    -> ${INSTALL_DIR}/kickstart/ks-registry.cfg
#
# WHERE: low-side staging host, as your user. The installer user's password is prompted
# and hashed with `openssl passwd -6 -stdin`, so it never appears in a file, in argv, or
# in git (FR-E3). Output lands outside the repo (ADR-08) with mode 600.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ROLE="${1:-}"
case "${ROLE}" in
  bastion|registry) ;;
  *) log_error "usage: $0 bastion|registry"; exit 2 ;;
esac

load_env
validate_env --scope kickstart   # site steps run before MACs, disks and the pull secret are known
require_cmd openssl python3

TEMPLATE="${REPO_ROOT}/kickstart/ks-${ROLE}.cfg.template"
OUT="${INSTALL_DIR}/kickstart/ks-${ROLE}.cfg"

read -rsp "Password for the 'installer' user on the ${ROLE}: " pass1; echo
read -rsp "Repeat: " pass2; echo
if [[ -z "${pass1}" || "${pass1}" != "${pass2}" ]]; then
  log_error "Passwords are empty or do not match"
  exit 1
fi
# printf is a shell builtin, so the password reaches openssl on stdin, never in argv (NFR-4).
KS_PASSWORD_HASH="$(printf '%s' "${pass1}" | openssl passwd -6 -stdin)"
unset pass1 pass2
export KS_PASSWORD_HASH

render text "${TEMPLATE}" "${OUT}"
unset KS_PASSWORD_HASH

if command -v ksvalidator &>/dev/null; then
  ksvalidator -v RHEL9 "${OUT}"
  log_info "ksvalidator: ${OUT} is valid RHEL 9 kickstart syntax"
else
  log_warn "ksvalidator not found (dnf install pykickstart); syntax not checked"
fi

log_info "PASS: rendered ${OUT} (mode 600)"
log_info "Next (Lab 04 step 4.3): embed it into the RHEL 9 DVD:"
log_info "  mkksiso --ks ${OUT} --add ${REPO_ROOT} <rhel-9.x-x86_64-dvd.iso> ${INSTALL_DIR}/kickstart/${ROLE}-ks.iso"
