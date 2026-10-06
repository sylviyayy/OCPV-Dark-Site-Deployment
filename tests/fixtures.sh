#!/usr/bin/env bash
# Build the stand-in inputs that Labs 01-06 would produce, under ${CI_TMP}:
# pull secret, SSH key, registry CA, merged auth file and oc-mirror cluster-resources.
# Sourced by tests/render-all.sh after tests/ci.env is loaded.

make_fixtures() {
  mkdir -p "${MIRROR_DIR}" "${CLUSTER_RESOURCES_DIR}"
  # Dummy credentials, built at run time so nothing credential-shaped is committed.
  jq -n --arg a "$(printf 'ci:ci' | base64)" \
    '{auths: {"registry.redhat.io": {auth: $a}, "cloud.openshift.com": {auth: $a}}}' > "${PULL_SECRET_FILE}"
  rm -f "${SSH_PUBLIC_KEY_FILE%.pub}" "${SSH_PUBLIC_KEY_FILE}"
  ssh-keygen -q -t ed25519 -N '' -C ci@bastion -f "${SSH_PUBLIC_KEY_FILE%.pub}"
  # stderr only carries openssl's key-generation progress; failures still exit non-zero.
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=ci-root-ca" \
    -keyout "${CI_TMP}/ca.key" -out "${REGISTRY_CA_FILE}" 2>/dev/null
  jq --arg r "${MIRROR_REGISTRY}" --arg a "$(printf 'init:ci' | base64)" '.auths[$r] = {auth: $a}' \
    "${PULL_SECRET_FILE}" > "${AUTH_FILE}"
  cat > "${CLUSTER_RESOURCES_DIR}/idms-oc-mirror.yaml" <<EOF
apiVersion: config.openshift.io/v1
kind: ImageDigestMirrorSet
metadata:
  name: idms-release-0
spec:
  imageDigestMirrors:
    - mirrors:
        - ${MIRROR_REGISTRY}/openshift/release
      source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
    - mirrors:
        - ${MIRROR_REGISTRY}/openshift/release-images
      source: quay.io/openshift-release-dev/ocp-release
EOF
  cat > "${CLUSTER_RESOURCES_DIR}/cs-redhat-operator-index-v4-22.yaml" <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cs-redhat-operator-index-v4-22
  namespace: openshift-marketplace
spec:
  image: ${MIRROR_REGISTRY}/redhat/redhat-operator-index:v4.22
  sourceType: grpc
EOF
}
