#!/usr/bin/env bash
# Install mirror registry and load oc-mirror v2 archive (dark site)
#
# Supports:
# - mirror registry for Red Hat OpenShift (recommended, port 443) — official RH tool
# - Fallback: podman registry:2 on port 5000 (lab only)
#
# Official: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

MODE="${1:-disk-to-mirror}"
load_env

MIRROR_DIR="${MIRROR_DIR:-/opt/ocp-mirror}"
WORKDIR="${OC_MIRROR_WORKDIR:-${MIRROR_DIR}/oc-mirror-workdir}"
REGISTRY_DATA="/opt/registry/data"
REGISTRY_CERTS="/opt/registry/certs"

require_cmd podman curl jq

install_mirror_registry_rh() {
  # mirror-registry for Red Hat OpenShift — download from console.redhat.com
  if command -v mirror-registry &>/dev/null; then
    log_info "Installing mirror registry for Red Hat OpenShift..."
    mirror-registry install \
      --quayHostname "${MIRROR_REGISTRY_HOSTNAME}" \
      --quayRoot "${REGISTRY_DATA}" \
      --initPassword "${MIRROR_REGISTRY_PASSWORD}" \
      --initUser "${MIRROR_REGISTRY_USER}"
    return 0
  fi
  return 1
}

install_podman_registry_fallback() {
  log_warn "mirror-registry CLI not found — using podman registry:2 (lab only)"
  log_warn "Download mirror-registry from https://console.redhat.com/openshift/downloads"

  if [[ ! -f "${REGISTRY_CERTS}/domain.crt" ]]; then
    mkdir -p "${REGISTRY_CERTS}"
    openssl req -newkey rsa:4096 -nodes -sha256 \
      -keyout "${REGISTRY_CERTS}/domain.key" \
      -x509 -days 3650 \
      -out "${REGISTRY_CERTS}/domain.crt" \
      -subj "/CN=${MIRROR_REGISTRY_HOSTNAME}" \
      -addext "subjectAltName=DNS:${MIRROR_REGISTRY_HOSTNAME},IP:${MIRROR_REGISTRY_IP}"
  fi

  if ! podman ps --format '{{.Names}}' | grep -q '^local-registry$'; then
    mkdir -p "${REGISTRY_DATA}"
    podman run -d \
      --name local-registry \
      --restart=always \
      -p 5000:5000 \
      -v "${REGISTRY_DATA}:/var/lib/registry:z" \
      -v "${REGISTRY_CERTS}:/certs:z" \
      -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
      -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
      -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
      docker.io/library/registry:2
  fi
}

# --- Install registry ---
if ! install_mirror_registry_rh; then
  install_podman_registry_fallback
fi

# --- disk-to-mirror: load oc-mirror archive into registry ---
if [[ "$MODE" == "disk-to-mirror" || "$MODE" == "--load-only" ]]; then
  if ! command -v oc-mirror &>/dev/null && [[ -x "${MIRROR_DIR}/clients/oc-mirror" ]]; then
    export PATH="${MIRROR_DIR}/clients:${PATH}"
  fi

  if [[ ! -d "${WORKDIR}" ]]; then
    log_error "oc-mirror workdir not found: ${WORKDIR}"
    log_error "Transfer archive from staging host first (see scripts/01-mirror-preparation.sh)"
    exit 1
  fi

  log_info "Loading images from ${WORKDIR} → docker://${MIRROR_REGISTRY}"
  oc mirror -c "${IMAGESET_CONFIG:-${MIRROR_DIR}/imageset-config.yaml}" \
    --workspace "file://${WORKDIR}" \
    "docker://${MIRROR_REGISTRY}" \
    --v2

  log_info "Cluster mirror resources:"
  ls -la "${WORKDIR}/cluster-resources/" 2>/dev/null || \
    find "${WORKDIR}" -path '*/cluster-resources/*.yaml' -print
fi

# --- Verify registry ---
REG_PORT="${MIRROR_REGISTRY##*:}"
curl -sk "https://${MIRROR_REGISTRY}/v2/" >/dev/null && \
  log_info "Registry API reachable at https://${MIRROR_REGISTRY}/v2/" || \
  log_warn "Registry not yet reachable on https://${MIRROR_REGISTRY}"

# Save CA cert for install-config additionalTrustBundle
if [[ -f "${REGISTRY_CERTS}/domain.crt" ]]; then
  cp "${REGISTRY_CERTS}/domain.crt" "${MIRROR_DIR}/registry-ca.crt"
  log_info "Registry CA saved to ${MIRROR_DIR}/registry-ca.crt"
fi

log_info ""
log_info "Next: ./scripts/03-generate-install-config.sh"
