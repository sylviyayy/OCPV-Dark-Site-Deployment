#!/usr/bin/env bash
# Download and mirror OCP release artifacts on a staging machine (requires internet)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

load_env
require_cmd oc podman skopeo jq curl

MIRROR_DIR="${MIRROR_DIR:-/opt/ocp-mirror}"
PULL_SECRET="${PULL_SECRET_FILE:-${MIRROR_DIR}/pull-secret.json}"

log_info "OCP-V Dark Site Mirror Preparation"
log_info "Target version: ${OCP_VERSION}"
log_info "Mirror directory: ${MIRROR_DIR}"

if [[ ! -f "$PULL_SECRET" ]]; then
  log_error "Pull secret not found at ${PULL_SECRET}"
  log_error "Download from https://console.redhat.com/openshift/install/pull-secret"
  exit 1
fi

mkdir -p "${MIRROR_DIR}"

# Download openshift-install and oc client
RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${OCP_VERSION}-x86_64"
log_info "Pulling release image: ${RELEASE_IMAGE}"
oc adm release extract --tools --command=openshift-install "${RELEASE_IMAGE}" -C "${MIRROR_DIR}/"
oc adm release extract --tools --command=oc "${RELEASE_IMAGE}" -C "${MIRROR_DIR}/"

# Create mirror configuration
cat > "${MIRROR_DIR}/mirror-config.yaml" <<EOF
apiVersion: v1
data:
  mirror-config: |
    kind: ImageSetConfiguration
    apiVersion: mirror.openshift.io/v1alpha2
    storageConfig:
      registry:
        imageURL: ${MIRROR_REGISTRY}/ocp-mirror/mirror
        skipTLS: true
    mirror:
      platform:
        architectures:
          - amd64
        channels:
          - name: stable-${OCP_VERSION%.*}
            type: ocp-release
            minVersion: ${OCP_VERSION}
            maxVersion: ${OCP_VERSION}
      operators:
        - catalog: registry.redhat.io/redhat/redhat-operator-index:v4.14
          packages:
            - name: kubevirt-hyperconverged
              channels:
                - name: stable
            - name: cnv
              channels:
                - name: stable
      additionalImages:
        - name: registry.redhat.io/rhel9/rhel-guest-image:latest
        - name: quay.io/kubevirt/cirros-container-disk-demo:latest
EOF

log_info "Mirror config written to ${MIRROR_DIR}/mirror-config.yaml"

# Run oc mirror (requires oc-mirror plugin v2)
if command -v oc-mirror &>/dev/null; then
  log_info "Running oc mirror..."
  oc mirror --config="${MIRROR_DIR}/mirror-config.yaml" \
    --workspace="${MIRROR_DIR}/workspace" \
    docker://${MIRROR_REGISTRY}
  log_info "Mirror complete. Transfer ${MIRROR_DIR} to dark site."
else
  log_warn "oc-mirror plugin not found. Install with:"
  log_warn "  curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OCP_VERSION}/oc-mirror.tar.gz | tar xz -C /usr/local/bin"
  log_warn "Mirror config is ready at ${MIRROR_DIR}/mirror-config.yaml"
  log_warn "Run oc mirror manually after installing the plugin."
fi

# Create transport tarball instructions
log_info ""
log_info "=== Next Steps ==="
log_info "1. tar czf /tmp/ocp-mirror.tar.gz -C $(dirname ${MIRROR_DIR}) $(basename ${MIRROR_DIR})"
log_info "2. Copy tarball + RHEL ISO + this repo to dark site via USB/NAS"
log_info "3. Follow docs/03-kickstart-procedure.md"
