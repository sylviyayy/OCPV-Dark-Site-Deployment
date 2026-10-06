#!/usr/bin/env bash
# Low side (connected RHEL 9 staging host) — Lab 06 steps 6.1-6.2.
#
#   ./scripts/01-mirror-preparation.sh [--profile default|poc|poc,odf|coe]   clients, auth, ImageSet
#   ./scripts/01-mirror-preparation.sh --mirror-to-disk [--profile]  ... then mirror to disk
#
# This host never joins the machine network (ADR-02). Its output crosses the air gap on
# approved media with SHA256SUMS (Lab 06 step 6.3); devices do not.
#
# Official: https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/authfile.sh
source "${SCRIPT_DIR}/lib/authfile.sh"

PROFILE=default
MIRROR_TO_DISK=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --mirror-to-disk) MIRROR_TO_DISK=true; shift ;;
    *) log_error "usage: $0 [--profile default|poc|poc,odf|coe] [--mirror-to-disk]"; exit 2 ;;
  esac
done

load_env
validate_env
refuse_root
# FR-B2: require only what must already exist; oc and oc-mirror are downloaded below.
require_cmd curl jq tar sha256sum skopeo python3

CLIENTS="${MIRROR_DIR}/clients"
DL="${CLIENTS}/downloads"
mkdir -p "${DL}" "${MIRROR_ARCHIVE_DIR}"

# --- Step 1: OpenShift clients, verified against Red Hat's published checksums (FR-B1) ---
# File names vary by release, so they are picked from sha256sum.txt by pattern.
# TODO(verify-4.22): https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/
CLIENT_BASE="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}"
log_info "Fetching ${CLIENT_BASE}/sha256sum.txt"
if ! curl -fsSL "${CLIENT_BASE}/sha256sum.txt" -o "${DL}/sha256sum.txt"; then
  log_error "No sha256sum.txt for ${OCP_VERSION}: is that z-stream published in ${OCP_CHANNEL}? (A3)"
  exit 1
fi

pick() {  # pick REGEX — the one RHEL 9 artefact in sha256sum.txt matching REGEX
  local matches
  matches="$(awk -v re="$1" '$2 ~ re {print $2}' "${DL}/sha256sum.txt")"
  if [[ "$(grep -c . <<<"${matches}")" != "1" ]]; then
    log_error "expected exactly one file matching /$1/ in sha256sum.txt, found: ${matches:-none}"
    exit 1
  fi
  echo "${matches}"
}
ARTEFACTS=(
  "$(pick '^openshift-install-rhel9-amd64\.tar\.gz$')"
  "$(pick '^openshift-client-linux-amd64-rhel9(-[0-9.]+)?\.tar\.gz$')"
  "$(pick '^oc-mirror\.rhel9\.tar\.gz$')"
)
for f in "${ARTEFACTS[@]}"; do
  [[ -f "${DL}/${f}" ]] || curl -fSL "${CLIENT_BASE}/${f}" -o "${DL}/${f}"
done
(cd "${DL}" && awk -v a="${ARTEFACTS[0]}" -v b="${ARTEFACTS[1]}" -v c="${ARTEFACTS[2]}" \
  '$2 == a || $2 == b || $2 == c' sha256sum.txt | sha256sum -c -)
for f in "${ARTEFACTS[@]}"; do
  tar -xzf "${DL}/${f}" -C "${CLIENTS}"
done
chmod +x "${CLIENTS}/oc-mirror"
export PATH="${CLIENTS}:${PATH}"
require_cmd oc oc-mirror openshift-install
if ! openshift-install version | grep -q "${OCP_VERSION}"; then
  log_error "openshift-install does not report ${OCP_VERSION}"
  exit 1
fi
oc mirror --v2 --help >/dev/null
log_info "PASS: openshift-install, oc, oc-mirror ${OCP_VERSION} checksum-verified in ${CLIENTS}"

# --- Step 1b: mirror registry for Red Hat OpenShift (installed on the high side, FR-C2) ---
# TODO(verify-4.22): the same archive is on console.redhat.com/openshift/downloads.
MR_URL="https://mirror.openshift.com/pub/cgw/mirror-registry/latest/mirror-registry-amd64.tar.gz"
if [[ ! -x "${CLIENTS}/mirror-registry/mirror-registry" ]]; then
  if ! curl -fSL "${MR_URL}" -o "${DL}/mirror-registry-amd64.tar.gz"; then
    log_error "Could not download ${MR_URL}."
    log_error "Download mirror-registry-amd64.tar.gz from https://console.redhat.com/openshift/downloads"
    log_error "into ${DL}/ and re-run this script."
    exit 1
  fi
  mkdir -p "${CLIENTS}/mirror-registry"
  tar -xzf "${DL}/mirror-registry-amd64.tar.gz" -C "${CLIENTS}/mirror-registry"
fi
log_info "PASS: mirror-registry present in ${CLIENTS}/mirror-registry"

# --- Step 2: auth file for oc-mirror (FR-B3) ---
build_authfile

# --- Step 3: ImageSet with every additional image pinned by digest (FR-B6, NFR-8) ---
# The digest is resolved once and then reused, so a re-run never silently changes the guest
# image after it was mirrored. Delete ${IMAGESET_CONFIG} to re-resolve deliberately.
GUEST_REPO="registry.redhat.io/rhel9/rhel-guest-image"
GUEST_RESOLVE_TAG="latest"   # read once here; nothing downstream references the tag
RHEL_GUEST_IMAGE_DIGEST=""
if [[ -f "${IMAGESET_CONFIG}" ]]; then
  RHEL_GUEST_IMAGE_DIGEST="$(grep -oE 'rhel-guest-image@sha256:[0-9a-f]{64}' "${IMAGESET_CONFIG}" | cut -d@ -f2 || true)"  # empty if absent
fi
if [[ -z "${RHEL_GUEST_IMAGE_DIGEST}" ]]; then
  RHEL_GUEST_IMAGE_DIGEST="$(skopeo inspect --authfile "${AUTH_FILE}" --format '{{.Digest}}' "docker://${GUEST_REPO}:${GUEST_RESOLVE_TAG}")"
fi
export RHEL_GUEST_IMAGE_DIGEST
render imageset "${IMAGESET_CONFIG}" --profile "${PROFILE}"
log_info "PASS: ${IMAGESET_CONFIG} (profile ${PROFILE}, guest image ${RHEL_GUEST_IMAGE_DIGEST})"

# --- Step 4: mirror to disk (FR-B4): destination is file://, not a --workspace alone ---
if [[ "${MIRROR_TO_DISK}" == true ]]; then
  log_info "Mirroring to ${MIRROR_ARCHIVE_DIR} (large download; can take hours)"
  # --cache-dir keeps oc-mirror's layer cache on the sized mirror filesystem, not in ~/.oc-mirror.
  oc mirror -c "${IMAGESET_CONFIG}" "file://${MIRROR_ARCHIVE_DIR}" --v2 --authfile "${AUTH_FILE}" \
    --cache-dir "${MIRROR_DIR}/cache"
  shopt -s nullglob
  archives=("${MIRROR_ARCHIVE_DIR}"/mirror_*.tar)
  if (( ${#archives[@]} == 0 )); then
    log_error "oc mirror returned 0 but no mirror_*.tar exists in ${MIRROR_ARCHIVE_DIR}"
    exit 1
  fi
  du -ch "${archives[@]}" | tail -n1
  log_info "PASS: ${#archives[@]} archive(s) in ${MIRROR_ARCHIVE_DIR}; media needs at least 2x this size"
  log_info "Next (Lab 06 step 6.3): copy to approved media and generate SHA256SUMS"
else
  log_info "Next: ./scripts/01-mirror-preparation.sh --mirror-to-disk --profile ${PROFILE}"
fi
