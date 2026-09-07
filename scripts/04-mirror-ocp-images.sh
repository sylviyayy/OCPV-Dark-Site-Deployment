#!/usr/bin/env bash
# Load mirrored OCP images into local podman registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

LOAD_ONLY=false
if [[ "${1:-}" == "--load-only" ]]; then
  LOAD_ONLY=true
fi

load_env
require_cmd podman skopeo

REGISTRY_DATA="/opt/registry/data"
REGISTRY_CERTS="/opt/registry/certs"
MIRROR_DIR="${MIRROR_DIR:-/opt/ocp-mirror}"

log_info "Mirror registry setup on ${MIRROR_REGISTRY}"

# Generate TLS certs if missing
if [[ ! -f "${REGISTRY_CERTS}/domain.crt" ]]; then
  log_info "Generating self-signed TLS certificate..."
  mkdir -p "${REGISTRY_CERTS}"
  openssl req -newkey rsa:4096 -nodes -sha256 \
    -keyout "${REGISTRY_CERTS}/domain.key" \
    -x509 -days 3650 \
    -out "${REGISTRY_CERTS}/domain.crt" \
    -subj "/CN=registry.${BASE_DOMAIN}" \
    -addext "subjectAltName=DNS:registry.${BASE_DOMAIN},IP:${MIRROR_REGISTRY_IP}"
fi

# Start local registry container
if ! podman ps --format '{{.Names}}' | grep -q '^local-registry$'; then
  log_info "Starting local registry container..."
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
  wait_for_port "${MIRROR_REGISTRY_IP}" 5000 30
fi

# Load mirrored images from tarball
if [[ -d "${MIRROR_DIR}/workspace" ]]; then
  log_info "Loading mirrored images from ${MIRROR_DIR}/workspace..."
  if command -v oc-mirror &>/dev/null; then
    oc mirror --from="${MIRROR_DIR}/workspace" \
      "docker://${MIRROR_REGISTRY}" \
      --v2
  else
    log_warn "oc-mirror not available. Loading images manually from tarballs..."
    for tarfile in "${MIRROR_DIR}"/workspace/**/*.tar; do
      [[ -f "$tarfile" ]] && skopeo copy \
        "docker-archive:${tarfile}" \
        "docker://${MIRROR_REGISTRY}/$(basename "${tarfile%.tar}")" \
        --dest-tls-verify=false
    done
  fi
  log_info "Images loaded into registry"
else
  log_warn "No mirror workspace found at ${MIRROR_DIR}/workspace"
  log_warn "Run 01-mirror-preparation.sh on staging machine first"
fi

# Verify
log_info "Registry catalog:"
curl -sk "https://${MIRROR_REGISTRY}/v2/_catalog" | jq . 2>/dev/null || \
  curl -sk "https://${MIRROR_REGISTRY}/v2/_catalog"

log_info "Registry is ready at https://${MIRROR_REGISTRY}"
