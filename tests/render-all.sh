#!/usr/bin/env bash
# Render every template from tests/ci.env and prove the output (FR-I5; AT-01, AT-02, NFR-2).
#
#   tests/render-all.sh            needs: python3 + PyYAML, jq, openssl, ssh-keygen,
#                                  named-checkzone/named-checkconf (bind9-utils)
#
# Checks: YAML parses (including nested cloud-config and network-config), zones pass
# named-checkzone, no placeholder survives, the rendered MAC set equals .env, two renders
# are byte-identical, and the sample .env.example is rejected.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_TMP="$(mktemp -d)"
export CI_TMP OCPV_ENV_FILE="${REPO}/tests/ci.env"
trap 'rm -rf "${CI_TMP}"' EXIT

# shellcheck source=scripts/lib/common.sh
source "${REPO}/scripts/lib/common.sh"
# shellcheck source=tests/fixtures.sh
source "${REPO}/tests/fixtures.sh"

pass() { echo "  [PASS] $*"; }
die() { echo "  [FAIL] $*" >&2; exit 1; }

load_env
make_fixtures
validate_env

# Deterministic stand-ins for values the labs obtain interactively.
RHEL_GUEST_IMAGE_DIGEST="sha256:$(printf '0123456789abcdef%.0s' 1 2 3 4)"
export RHEL_GUEST_IMAGE_DIGEST
KS_PASSWORD_HASH="$(printf 'ci' | openssl passwd -6 -salt cisalt -stdin)"
export KS_PASSWORD_HASH

render_tree() {  # render_tree OUTDIR — every template into OUTDIR
  local out=$1
  mkdir -p "${out}"
  render imageset "${IMAGESET_CONFIG}"
  cp "${IMAGESET_CONFIG}" "${out}/imageset-config.yaml"
  render install-config "${out}/install-config.yaml"
  render agent-config "${out}/agent-config.yaml"
  render text "${REPO}/kickstart/ks-bastion.cfg.template" "${out}/ks-bastion.cfg"
  render text "${REPO}/kickstart/ks-registry.cfg.template" "${out}/ks-registry.cfg"
  VM_NAME=dns-a VM_IP="${DNS_VM1_IP}" render text "${REPO}/manifests/production/dns-vm/dns-vm.yaml.template" "${out}/dns-a.yaml"
  VM_NAME=dns-b VM_IP="${DNS_VM2_IP}" render text "${REPO}/manifests/production/dns-vm/dns-vm.yaml.template" "${out}/dns-b.yaml"
  VM_NAME=ntp VM_IP="${NTP_VM_IP}" render text "${REPO}/manifests/production/ntp-vm/ntp-vm.yaml.template" "${out}/ntp.yaml"
  render text "${REPO}/manifests/production/dns-vm/nncp-dns-cutover.yaml.template" "${out}/nncp-dns-cutover.yaml"
  render text "${REPO}/manifests/production/ntp-vm/machineconfig-chrony.yaml.template" "${out}/machineconfig-chrony.yaml"
  cp "${REPO}"/manifests/production/network/*.yaml "${out}/"
}

echo "== Render (AT-01)"
render_tree "${CI_TMP}/out1"
pass "all templates rendered from tests/ci.env"

echo "== Parse every YAML document, including nested cloud-config (FR-I5)"
python3 - "${CI_TMP}/out1" <<'PY'
import pathlib, sys, yaml
out = pathlib.Path(sys.argv[1])
for path in sorted(out.glob("*.yaml")):
    docs = [d for d in yaml.safe_load_all(path.read_text()) if d]
    for doc in docs:
        if doc.get("kind") == "Secret":
            for key, body in doc.get("stringData", {}).items():
                nested = yaml.safe_load(body)
                assert isinstance(nested, dict), f"{path.name}: {key} is not a mapping"
                if key == "userdata":
                    assert body.startswith("#cloud-config"), f"{path.name}: userdata lacks #cloud-config"
                    for wf in nested.get("write_files", []):
                        dest = out.parent / "guest-files" / path.stem / wf["path"].lstrip("/")
                        dest.parent.mkdir(parents=True, exist_ok=True)
                        dest.write_text(wf["content"])
    print(f"  [PASS] {path.name}: {len(docs)} document(s)")
PY

echo "== Zones and named.conf (FR-H4 done-when, FR-H13)"
for vm in dns-a dns-b; do
  guest="${CI_TMP}/guest-files/${vm}"
  # Point named at the extracted /var/named, then load config and both zones as named would.
  sed "s|\"/var/named\"|\"${guest}/var/named\"|" "${guest}/etc/named.conf" > "${guest}/named.ci.conf"
  named-checkconf -z "${guest}/named.ci.conf"
done
zone="${CI_TMP}/guest-files/dns-a/var/named/forward.zone"
grep -qE "^registry +IN A +${MIRROR_REGISTRY_IP}\$" "${zone}" || die "registry A record is not exactly ${MIRROR_REGISTRY_IP}"
pass "named-checkconf -z loads both zones on both VMs; registry A record exact"

echo "== Placeholders and pinning (metrics table, NFR-7, NFR-8)"
if grep -rnE '\$\{[A-Z_]+\}|<[A-Z][A-Z0-9_]{2,}>|00:50:56|\bens192\b|:latest\b|--plaintext' "${CI_TMP}/out1"; then
  die "placeholder, sample value, :latest or plaintext password in rendered output"
fi
pass "no placeholder, sample MAC, ens192, :latest or --plaintext in rendered output"

echo "== Cluster pull secret: mirror entry present, telemetry entry dropped (FR-D2)"
python3 - "${CI_TMP}/out1/install-config.yaml" "${MIRROR_REGISTRY}" <<'PY2'
import json, sys, yaml
auths = json.loads(yaml.safe_load(open(sys.argv[1]))["pullSecret"])["auths"]
assert sys.argv[2] in auths, "mirror registry missing from pullSecret"
assert "cloud.openshift.com" not in auths, "cloud.openshift.com must not reach the cluster"
print("  [PASS] pullSecret has", ", ".join(sorted(auths)))
PY2

echo "== Kickstart syntax (Red Hat ksvalidator, RHEL 9)"
if command -v ksvalidator >/dev/null; then
  for ks in ks-bastion ks-registry; do ksvalidator -v RHEL9 "${CI_TMP}/out1/${ks}.cfg" >/dev/null; done
  pass "ksvalidator accepts both rendered kickstarts"
else
  echo "  [SKIP] ksvalidator not installed (pip install pykickstart)"
fi

echo "== MAC set equals .env (AT-01)"
want="$(for n in MW01 MW02 MW03; do v="${n}_NICS"; tr ',' '\n' <<<"${!v}" | cut -d= -f2; done | sort)"
got="$(grep -oE 'macAddress: [0-9a-f:]+' "${CI_TMP}/out1/agent-config.yaml" | awk '{print $2}' | sort)"
[[ "${want}" == "${got}" ]] || die "MAC set differs: want ${want//$'\n'/ } got ${got//$'\n'/ }"
pass "12 MACs, identical to MW01..MW03_NICS"

echo "== Node chrony.conf decodes to NTP VM then upstream"
b64="$(grep -m1 -oE 'base64,[A-Za-z0-9+/=]+' "${CI_TMP}/out1/machineconfig-chrony.yaml" | cut -d, -f2)"
servers="$(base64 -d <<<"${b64}" | awk '$1 == "server" {print $2}' | paste -sd' ')"
[[ "${servers}" == "${NTP_VM_IP} ${TIME_UPSTREAM}" ]] || die "chrony servers are '${servers}'"
pass "chrony servers: ${servers}"

echo "== Determinism (NFR-2)"
render_tree "${CI_TMP}/out2"
diff -r "${CI_TMP}/out1" "${CI_TMP}/out2" \
  || die "two renders of the same .env differ"
pass "two renders are byte-identical"

echo "== Sample register is rejected (AT-02)"
set +e
msgs="$(OCPV_ENV_FILE="${REPO}/.env.example" "${REPO}/scripts/lib/validate-env.sh" 2>&1)"
rc=$?
set -e
[[ ${rc} -eq 1 ]] || die "validate-env.sh exited ${rc} on .env.example, expected 1"
for key in MW01_NICS MW02_NICS MW03_NICS BASE_DOMAIN PULL_SECRET_FILE; do
  [[ "$(grep -c "\[FAIL\] .. ${key}:" <<<"${msgs}")" == "1" ]] || die "expected exactly one message for ${key}"
done
pass "exit 1 with one message per offending key (sample MACs, domain, missing file)"

echo "All render checks passed."
