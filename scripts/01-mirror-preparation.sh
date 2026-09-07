#!/usr/bin/env bash
# Download CLI tools and mirror OCP 4.22 images using oc-mirror plugin v2 (connected staging host)
#
# Official references:
# - https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/
# - https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc jq curl

MIRROR_DIR="${MIRROR_DIR:-/opt/ocp-mirror}"
PULL_SECRET="${PULL_SECRET_FILE:-${MIRROR_DIR}/pull-secret.json}"
IMAGESET="${IMAGESET_CONFIG:-${MIRROR_DIR}/imageset-config.yaml}"
WORKDIR="${OC_MIRROR_WORKDIR:-${MIRROR_DIR}/oc-mirror-workdir}"
OCP_MINOR="${OCP_VERSION%.*}"

log_info "OCP 4.22 disconnected mirror preparation"
log_info "Version: ${OCP_VERSION}  Channel: ${OCP_CHANNEL:-stable-${OCP_MINOR}}"

if [[ ! -f "$PULL_SECRET" ]]; then
  log_error "Pull secret not found: ${PULL_SECRET}"
  log_error "Download from https://console.redhat.com/openshift/install/pull-secret"
  exit 1
fi

mkdir -p "${MIRROR_DIR}" "${WORKDIR}"

# --- Step 1: Download openshift-install, oc, oc-mirror from Red Hat mirror ---
TOOLS_DIR="${MIRROR_DIR}/clients"
mkdir -p "${TOOLS_DIR}"

CLIENT_BASE="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}"
log_info "Downloading OpenShift CLI tools from ${CLIENT_BASE}"

for tool in openshift-install oc oc-mirror; do
  if [[ ! -x "${TOOLS_DIR}/${tool}" ]]; then
    curl -fsSL "${CLIENT_BASE}/${tool}.tar.gz" -o "/tmp/${tool}.tar.gz"
    tar xzf "/tmp/${tool}.tar.gz" -C "${TOOLS_DIR}"
    chmod +x "${TOOLS_DIR}/${tool}"
    rm -f "/tmp/${tool}.tar.gz"
    log_info "  Installed ${tool}"
  fi
done

export PATH="${TOOLS_DIR}:${PATH}"

if ! oc mirror --v2 --help &>/dev/null; then
  log_error "oc-mirror plugin v2 not available. Verify ${TOOLS_DIR}/oc-mirror"
  exit 1
fi

# --- Step 2: Generate ImageSetConfiguration ---
if [[ ! -f "${IMAGESET}" ]]; then
  sed \
    -e "s|stable-4.22|${OCP_CHANNEL:-stable-${OCP_MINOR}}|g" \
    -e "s|4.22.2|${OCP_VERSION}|g" \
    -e "s|redhat-operator-index:v4.22|redhat-operator-index:v${OCP_MINOR}|g" \
    "${REPO_ROOT}/mirror/imageset-config.yaml.template" > "${IMAGESET}"
  log_info "Generated ${IMAGESET}"
fi

# --- Step 3: Configure mirror registry credentials (separate from cluster pull secret) ---
REG_CREDS="${MIRROR_DIR}/mirror-registry-creds.json"
if [[ ! -f "${REG_CREDS}" ]]; then
  log_warn "Creating mirror registry credentials template at ${REG_CREDS}"
  log_warn "Edit this file — add your mirror registry auth (NOT the cluster pull secret)"
  jq --arg reg "${MIRROR_REGISTRY}" \
     --arg user "${MIRROR_REGISTRY_USER:-init}" \
     --arg pass "${MIRROR_REGISTRY_PASSWORD:-changeme}" \
     '.auths[$reg] = {"auth": (("\($user):\($pass)" | @base64)), "email": "mirror@local"}' \
     "${PULL_SECRET}" > "${REG_CREDS}"
fi

log_info ""
log_info "=== Mirror workflow (choose one) ==="
log_info ""
log_info "A) Mirror-to-disk (fully disconnected transport via USB):"
log_info "   oc mirror -c ${IMAGESET} --workspace file://${WORKDIR} --v2"
log_info "   # Transfer ${WORKDIR} tarball to dark site, then run scripts/04-mirror-ocp-images.sh"
log_info ""
log_info "B) Mirror-to-mirror (staging host can reach dark-site registry):"
log_info "   oc mirror -c ${IMAGESET} --workspace file://${WORKDIR} docker://${MIRROR_REGISTRY} --v2"
log_info ""
log_info "Optional: install mirror-registry for Red Hat OpenShift on dark site:"
log_info "   https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index"
log_info "   Download mirror-registry CLI from console.redhat.com → Downloads"
log_info ""
log_info "After mirroring, verify cluster-resources were generated:"
log_info "   ls ${WORKDIR}/cluster-resources/"

# Auto-run mirror-to-disk if --mirror flag passed
if [[ "${1:-}" == "--mirror-to-disk" ]]; then
  log_info "Running mirror-to-disk..."
  oc mirror -c "${IMAGESET}" --workspace "file://${WORKDIR}" --v2
  log_info "Mirror archive ready in ${WORKDIR}"
fi

if [[ "${1:-}" == "--mirror-to-registry" ]]; then
  log_info "Running mirror-to-mirror → docker://${MIRROR_REGISTRY}"
  oc mirror -c "${IMAGESET}" --workspace "file://${WORKDIR}" "docker://${MIRROR_REGISTRY}" --v2
fi
