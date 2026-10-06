#!/usr/bin/env bash
# Merged registry credentials for oc-mirror and the cluster pullSecret (FR-B3, FR-D2).
# Sourced by scripts 01 and 04 after common.sh.
#
# ${AUTH_FILE} (mode 600) = Red Hat pull secret [+ mirror registry entry].
#   Low side (script 01):  pull secret only — the mirror registry does not exist yet, and
#                          its password never needs to cross the air gap.
#   High side (script 04): `podman login` adds the registry entry, which also proves the
#                          password, the hostname and the CA trust in one step.

# build_authfile [--with-registry]
build_authfile() {
  local with_registry="${1:-}" base tmp reg_pass
  if [[ ! -f "${PULL_SECRET_FILE}" ]]; then
    log_error "Pull secret not found: ${PULL_SECRET_FILE} (Lab 01 step 1.2)"
    exit 1
  fi
  base="${PULL_SECRET_FILE}"
  [[ -f "${AUTH_FILE}" ]] && base="${AUTH_FILE}"

  mkdir -p "$(dirname "${AUTH_FILE}")"
  tmp="$(mktemp "${AUTH_FILE}.XXXXXX")"   # mktemp creates the file with mode 600
  jq . "${base}" > "${tmp}"

  if [[ "${with_registry}" == "--with-registry" ]]; then
    require_cmd podman
    read -rsp "Mirror registry password for ${MIRROR_REGISTRY_USER}@${MIRROR_REGISTRY}: " reg_pass; echo
    # The here-string reaches podman on stdin, so the password never appears in argv (NFR-4).
    if ! podman login --authfile "${tmp}" --username "${MIRROR_REGISTRY_USER}" \
         --password-stdin "${MIRROR_REGISTRY}" <<<"${reg_pass}"; then
      rm -f "${tmp}"
      log_error "Login to ${MIRROR_REGISTRY} failed: check the password, DNS for ${MIRROR_REGISTRY_HOSTNAME} and CA trust (Lab 06 step 6.7)"
      exit 1
    fi
    unset reg_pass
  fi

  chmod 600 "${tmp}"
  mv -f "${tmp}" "${AUTH_FILE}"
  log_info "Auth file ready: ${AUTH_FILE} (registries: $(jq -r '.auths | keys | join(", ")' "${AUTH_FILE}"))"
}
