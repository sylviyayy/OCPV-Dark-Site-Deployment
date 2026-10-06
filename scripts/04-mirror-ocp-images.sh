#!/usr/bin/env bash
# High side — mirror registry and disk-to-mirror (Lab 06 steps 6.6 and 6.8).
#
#   sudo ./scripts/04-mirror-ocp-images.sh install-registry   on the registry host (may be the bastion)
#   ./scripts/04-mirror-ocp-images.sh load                    on the bastion, as installer
#
# One endpoint, one port, one CA (ADR-03): mirror registry for Red Hat OpenShift, addressed
# as ${MIRROR_REGISTRY_HOSTNAME}:${MIRROR_REGISTRY_PORT} (default 8443), never by IP, because
# the certificate it issues names the host. There is no fallback registry: the former
# Docker Hub registry image cannot be pulled in a dark site (FR-C2).
#
# Official: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/authfile.sh
source "${SCRIPT_DIR}/lib/authfile.sh"

MODE="${1:-}"
QUAY_ROOT=/opt/quay-install   # mirror-registry config and generated CA live here

registry_answers() {  # TLS must verify against the system trust store: no -k (FR-C4, FR-I4)
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://${MIRROR_REGISTRY}/v2/")" || return 1
  [[ "${code}" == "200" || "${code}" == "401" ]]
}

install_registry() {
  check_root   # FR-C5: the installer needs root; refuse up front instead of failing midway
  local mr="${MIRROR_DIR}/clients/mirror-registry/mirror-registry" pass1 pass2 owner
  if [[ ! -x "${mr}" ]]; then
    log_error "${mr} not found."
    log_error "It is downloaded on the low side by scripts/01-mirror-preparation.sh and carried on"
    log_error "the transfer media (Lab 06 step 6.3); copy clients/ into ${MIRROR_DIR}/clients/."
    exit 1
  fi

  if podman ps --format '{{.Names}}' | grep -q '^quay-app$'; then
    log_info "mirror registry already running; skipping install (NFR-1)"
  else
    read -rsp "Choose the mirror registry password for '${MIRROR_REGISTRY_USER}' (>= 8 chars): " pass1; echo
    read -rsp "Repeat: " pass2; echo
    if [[ ${#pass1} -lt 8 || "${pass1}" != "${pass2}" ]]; then
      log_error "Passwords are shorter than 8 characters or do not match"
      exit 1
    fi
    # NFR-4 exception: mirror-registry accepts the initial password only as an argument, so
    # it is visible in the process table for the minutes this root-only install runs.
    # Store the password in your vault now; scripts never write it to disk.
    "${mr}" install \
      --quayHostname "${MIRROR_REGISTRY_HOSTNAME}:${MIRROR_REGISTRY_PORT}" \
      --quayRoot "${QUAY_ROOT}" \
      --initUser "${MIRROR_REGISTRY_USER}" \
      --initPassword "${pass1}"
    unset pass1 pass2
  fi

  # FR-C3: the trust anchor is the CA mirror-registry generated, not a scraped leaf cert.
  # TODO(verify-4.22): path against the mirror-registry release notes.
  local ca="${QUAY_ROOT}/quay-rootCA/rootCA.pem"
  if [[ ! -f "${ca}" ]]; then
    log_error "${ca} not found; locate it with: find ${QUAY_ROOT} -name 'rootCA*.pem'"
    exit 1
  fi
  install -m 644 "${ca}" "${REGISTRY_CA_FILE}"
  owner="${SUDO_USER:-root}"
  chown "${owner}:" "${REGISTRY_CA_FILE}"
  cp "${ca}" /etc/pki/ca-trust/source/anchors/ocpv-mirror-registry.crt
  update-ca-trust

  if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port="${MIRROR_REGISTRY_PORT}/tcp"
    firewall-cmd --reload
  fi

  if ! registry_answers; then
    log_error "https://${MIRROR_REGISTRY}/v2/ does not answer 200/401 with TLS verification"
    exit 1
  fi
  log_info "PASS: ${MIRROR_REGISTRY} serves TLS signed by ${REGISTRY_CA_FILE}"
  log_info "If this is not the bastion, copy ${REGISTRY_CA_FILE} to the bastion (Lab 06 step 6.7)."
}

load_archive() {
  refuse_root
  require_cmd oc oc-mirror podman
  if ! registry_answers; then
    log_error "https://${MIRROR_REGISTRY}/v2/ fails TLS verification or is unreachable from this host."
    log_error "Trust the registry CA first (Lab 06 step 6.7):"
    log_error "  sudo cp ${REGISTRY_CA_FILE} /etc/pki/ca-trust/source/anchors/ && sudo update-ca-trust"
    exit 1
  fi
  shopt -s nullglob
  local archives=("${MIRROR_ARCHIVE_DIR}"/mirror_*.tar)
  if (( ${#archives[@]} == 0 )); then
    log_error "No mirror_*.tar in ${MIRROR_ARCHIVE_DIR}; copy them from the transfer media (Lab 06 step 6.4)"
    exit 1
  fi
  if [[ ! -f "${IMAGESET_CONFIG}" ]]; then
    log_error "${IMAGESET_CONFIG} missing: disk-to-mirror needs the exact ImageSet that produced the archive"
    exit 1
  fi

  build_authfile --with-registry   # FR-B3: pull secret + registry entry, verified by login

  # FR-B5: --from reads the archive; --workspace alone would try to pull from Red Hat.
  log_info "Loading ${#archives[@]} archive(s) into docker://${MIRROR_REGISTRY}"
  # --cache-dir: the archive is unpacked into the cache before upload; keep it on MIRROR_DIR.
  oc mirror -c "${IMAGESET_CONFIG}" --from "file://${MIRROR_ARCHIVE_DIR}" \
    "docker://${MIRROR_REGISTRY}" --v2 --authfile "${AUTH_FILE}" --cache-dir "${MIRROR_DIR}/cache"

  # TODO(verify-4.22): cluster-resources location for oc-mirror v2 disk-to-mirror.
  if [[ ! -f "${CLUSTER_RESOURCES_DIR}/idms-oc-mirror.yaml" ]] \
     || ! compgen -G "${CLUSTER_RESOURCES_DIR}/cs-*.yaml" >/dev/null; then
    log_error "oc mirror finished but ${CLUSTER_RESOURCES_DIR} lacks idms-oc-mirror.yaml or cs-*.yaml"
    exit 1
  fi
  ls -1 "${CLUSTER_RESOURCES_DIR}"
  log_info "PASS: registry loaded; cluster-resources in ${CLUSTER_RESOURCES_DIR}"
  log_info "Next: Lab 07 (sudo ./scripts/02-bootstrap-dns-ntp.sh)"
}

load_env
validate_env
case "${MODE}" in
  install-registry) install_registry ;;
  load) load_archive ;;
  *) log_error "usage: sudo $0 install-registry | $0 load"; exit 2 ;;
esac
