#!/usr/bin/env bash
# Run every script in lab order against fakes of the external tools (tests/fake/fakecmd.py).
#
# Proves each script's control flow, argument handling, prompts, idempotent re-runs and
# failure paths. It cannot prove Red Hat tool behaviour — that is what the acceptance tests
# on reference hardware are for (docs/RELEASE.md).
#
#   tests/run-scripts.sh      run as a NON-root user with passwordless sudo (as on a CI runner)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $EUID -eq 0 ]]; then
  echo "run as a non-root user with passwordless sudo (scripts 03-08 refuse root)" >&2
  exit 2
fi

CI_TMP="$(mktemp -d)"
FAKE_DIR="${CI_TMP}/fake"
FAKE_STATE="${FAKE_DIR}/state.json"
FAKE_LOG="${FAKE_DIR}/calls.log"
OCPV_ENV_FILE="${REPO}/tests/ci.env"
OCPV_OS_RELEASE="${FAKE_DIR}/os-release"
export CI_TMP FAKE_DIR FAKE_STATE FAKE_LOG OCPV_ENV_FILE OCPV_OS_RELEASE
export PATH="${FAKE_DIR}/bin:${PATH}"
SYSTEM_BACKUP="${CI_TMP}/system-backup"

cleanup() {
  if [[ -n "${KEEP_TMP:-}" ]]; then echo "kept ${CI_TMP}"; return; fi
  # Undo the few system files the root-only scripts write on a real bastion.
  if [[ -d "${SYSTEM_BACKUP}" ]]; then
    sudo cp -a "${SYSTEM_BACKUP}/fstab" /etc/fstab 2>/dev/null || true          # best-effort restore
    sudo rm -f /etc/dnsmasq.d/ocp-v.conf /etc/yum.repos.d/rhel9-dvd.repo \
      /etc/pki/ca-trust/source/anchors/ocpv-mirror-registry.crt
    sudo rm -rf /opt/quay-install
  fi
  sudo rm -rf "${CI_TMP}"
}
trap cleanup EXIT

set -a
# shellcheck source=tests/ci.env
source "${OCPV_ENV_FILE}"
set +a

# --- Fakes and fixtures -------------------------------------------------------------
mkdir -p "${FAKE_DIR}/bin" "${FAKE_DIR}/downloads" "${FAKE_DIR}/pkg"
wrap() {  # wrap TOOL DIR — a one-line executable that forwards to the dispatcher
  printf '#!/bin/sh\nexec python3 %q %q "$@"\n' "${REPO}/tests/fake/fakecmd.py" "$1" > "$2/$1"
  chmod +x "$2/$1"
}
for t in oc openshift-install curl skopeo podman dig chronyd ping rpm mount mountpoint \
         systemctl firewall-cmd update-ca-trust dnf nmstatectl mkksiso dnsmasq; do
  wrap "${t}" "${FAKE_DIR}/bin"
done
# Poll loops count elapsed time by their interval, so an instant sleep keeps every timeout
# path exercised while a stuck loop fails in seconds instead of minutes.
printf '#!/bin/sh\nexit 0\n' > "${FAKE_DIR}/bin/sleep"
chmod +x "${FAKE_DIR}/bin/sleep"
printf 'ID="rhel"\nVERSION_ID="9.6"\n' > "${OCPV_OS_RELEASE}"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=fake-quay-root" \
  -keyout "${FAKE_DIR}/rootCA.key" -out "${FAKE_DIR}/rootCA.pem" 2>/dev/null   # stderr: keygen progress only

# Client archives as mirror.openshift.com publishes them, plus decoys the pattern must skip.
pack() {  # pack ARCHIVE TOOL...
  local stage="${FAKE_DIR}/pkg/$1"
  mkdir -p "${stage}"
  for t in "${@:2}"; do wrap "${t}" "${stage}"; done
  echo "fake" > "${stage}/README.md"
  tar -czf "${FAKE_DIR}/downloads/$1" -C "${stage}" .
}
pack "openshift-install-rhel9-amd64.tar.gz" openshift-install
pack "openshift-client-linux-amd64-rhel9-${OCP_VERSION}.tar.gz" oc kubectl
pack "oc-mirror.rhel9.tar.gz" oc-mirror
pack "openshift-install-linux-${OCP_VERSION}.tar.gz" openshift-install      # decoy (RHEL 8 build)
pack "mirror-registry-amd64.tar.gz" mirror-registry
(cd "${FAKE_DIR}/downloads" && sha256sum ./*.tar.gz | sed 's| \./| |' > sha256sum.txt)

# Directories a RHEL 9 bastion already has.
sudo mkdir -p /etc/dnsmasq.d /etc/yum.repos.d /etc/pki/ca-trust/source/anchors
mkdir -p "${SYSTEM_BACKUP}"
cp -a /etc/fstab "${SYSTEM_BACKUP}/fstab" 2>/dev/null || touch "${SYSTEM_BACKUP}/fstab"

# --- Runner -------------------------------------------------------------------------
passed=0
failed=0
step() {  # step "description" EXPECTED_EXIT [--root] [--stdin TEXT] [VAR=value...] -- CMD...
  local desc=$1 want=$2 root=false input="" envs=() rc
  shift 2
  while [[ $1 != -- ]]; do
    case $1 in
      --root) root=true ;;
      --stdin) input=$2; shift ;;
      *) envs+=("$1") ;;
    esac
    shift
  done
  shift
  local log="${CI_TMP}/step-$((passed + failed + 1)).log"
  set +e
  if [[ ${root} == true ]]; then
    # The log is written by this (non-root) shell on purpose, so the redirect stays outside sudo.
    # shellcheck disable=SC2024
    printf '%b' "${input}" | sudo env "PATH=${PATH}" "CI_TMP=${CI_TMP}" "FAKE_DIR=${FAKE_DIR}" \
      "FAKE_STATE=${FAKE_STATE}" "FAKE_LOG=${FAKE_LOG}" "OCPV_ENV_FILE=${OCPV_ENV_FILE}" \
      "OCPV_OS_RELEASE=${OCPV_OS_RELEASE}" "${envs[@]}" "$@" >"${log}" 2>&1
    rc=$?
    sudo chown -R "$(id -u):$(id -g)" "${CI_TMP}"
  else
    printf '%b' "${input}" | env "${envs[@]}" "$@" >"${log}" 2>&1
    rc=$?
  fi
  set -e
  if [[ ${rc} -eq ${want} ]]; then
    printf '  [PASS] %-62s exit %s\n' "${desc}" "${rc}"
    passed=$((passed + 1))
  else
    printf '  [FAIL] %-62s exit %s, expected %s\n' "${desc}" "${rc}" "${want}"
    sed 's/^/         | /' "${log}" | tail -n 25
    failed=$((failed + 1))
  fi
}
S="${REPO}/scripts"
PW='Corr3ct-Horse\nCorr3ct-Horse\n'

tree_before="$(git -C "${REPO}" status --porcelain --ignored)"

echo "== Lab 01-03: staging host and field register"
step "sample .env.example is rejected (AT-02)" 1 -- "${S}/lib/validate-env.sh" --env-file "${REPO}/.env.example"
step "no .env at all: refuse, no fallback (FR-A4)" 1 OCPV_ENV_FILE="${CI_TMP}/missing.env" -- "${S}/lib/validate-env.sh"
mkdir -p "${MIRROR_DIR}"
jq -n '{auths: {"registry.redhat.io": {auth: "Y2k6Y2k="}, "cloud.openshift.com": {auth: "Y2k6Y2k="}}}' > "${PULL_SECRET_FILE}"
ssh-keygen -q -t ed25519 -N '' -C installer@staging -f "${SSH_PUBLIC_KEY_FILE%.pub}"
step "CI register passes validation" 0 -- "${S}/lib/validate-env.sh"
step "00 --staging" 0 -- "${S}/00-prerequisites-check.sh" --staging

echo "== Lab 04: kickstarts"
step "render bastion kickstart (password prompt)" 0 --stdin "${PW}" -- "${S}/render-kickstart.sh" bastion
step "render registry kickstart" 0 --stdin "${PW}" -- "${S}/render-kickstart.sh" registry
step "mismatched passwords are refused" 1 --stdin 'a\nb\n' -- "${S}/render-kickstart.sh" bastion

echo "== Lab 06: low side, media, high side"
step "01 clients, auth, ImageSet" 0 -- "${S}/01-mirror-preparation.sh"
step "01 --mirror-to-disk" 0 -- "${S}/01-mirror-preparation.sh" --mirror-to-disk
step "01 re-run is idempotent (NFR-1)" 0 -- "${S}/01-mirror-preparation.sh" --mirror-to-disk
step "01 unknown profile fails" 1 -- "${S}/01-mirror-preparation.sh" --profile nope
echo "fake dvd" > "${MIRROR_DIR}/rhel9-dvd.iso"
step "04b serve DVD repo (root)" 0 --root -- "${S}/04b-serve-dvd-repo.sh"
step "04 load before the registry exists fails loudly" 1 --stdin 'x\n' FAKE_NO_REGISTRY=1 -- "${S}/04-mirror-ocp-images.sh" load
step "04 install-registry as non-root is refused (FR-C5)" 1 -- "${S}/04-mirror-ocp-images.sh" install-registry
step "04 install-registry (root, password prompt)" 0 --root --stdin "${PW}" -- "${S}/04-mirror-ocp-images.sh" install-registry
step "04 install-registry re-run skips install" 0 --root -- "${S}/04-mirror-ocp-images.sh" install-registry
step "04 load (disk to mirror)" 0 --stdin 'Corr3ct-Horse\n' -- "${S}/04-mirror-ocp-images.sh" load

echo "== Lab 07: bastion DNS and NTP"
step "02 bootstrap DNS/NTP (root)" 0 --root -- "${S}/02-bootstrap-dns-ntp.sh"
step "02 --print-config" 0 -- "${S}/02-bootstrap-dns-ntp.sh" --print-config
step "00 --bastion" 0 -- "${S}/00-prerequisites-check.sh" --bastion

echo "== Lab 08-10: install"
step "03 render install inputs" 0 -- "${S}/03-generate-install-config.sh"
step "03 re-render before install" 0 -- "${S}/03-generate-install-config.sh"
step "05a refuses when a VIP answers ping" 1 FAKE_VIP_TAKEN=1 -- "${S}/05a-create-agent-iso.sh"
step "05a create Agent ISO" 0 -- "${S}/05a-create-agent-iso.sh"
step "05b wait for install" 0 -- "${S}/05b-wait-install.sh"
step "03 refuses to overwrite an installed cluster" 1 -- "${S}/03-generate-install-config.sh"

echo "== Lab 12-15: platform, services, validation"
step "Lab 12: disable default catalog sources" 0 -- oc patch OperatorHub cluster --type merge -p '{"spec":{"disableAllDefaultSources":true}}'
step "Lab 12: apply cluster-resources" 0 -- oc apply -f "${CLUSTER_RESOURCES_DIR}/"
step "06 operators" 0 -- "${S}/06-deploy-cnv.sh"
step "06b storage" 0 -- "${S}/06b-configure-storage.sh"
step "07 DNS VMs" 0 -- "${S}/07-deploy-dns-vm.sh"
step "08 NTP VM and cut-over" 0 -- "${S}/08-deploy-ntp-vm.sh"
step "00 --post-install" 0 -- "${S}/00-prerequisites-check.sh" --post-install
step "00 --post-install with a NotReady node fails (AT-11)" 1 FAKE_NODE_NOTREADY=1 -- "${S}/00-prerequisites-check.sh" --post-install

echo "== Nothing written into the repository (AT-13)"
tree_after="$(git -C "${REPO}" status --porcelain --ignored)"
if [[ "${tree_before}" == "${tree_after}" ]]; then
  echo "  [PASS] git status --ignored is unchanged by the run"
  passed=$((passed + 1))
else
  diff <(echo "${tree_before}") <(echo "${tree_after}") || true   # diff exits 1 on difference
  echo "  [FAIL] the run left files in the working tree"
  failed=$((failed + 1))
fi

echo
echo "run-scripts: ${passed} passed, ${failed} failed"
[[ ${failed} -eq 0 ]]
