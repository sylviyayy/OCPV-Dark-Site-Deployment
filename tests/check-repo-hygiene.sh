#!/usr/bin/env bash
# Repo-wide "Done when" searches from the PRD, run against tracked files (FR-I5).
# Each rule: a pattern that must not appear, optionally outside an allowed file. CHANGELOG.md
# is exempt: recording what was removed requires naming it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fails=0
# forbid ID REGEX [PATHSPEC...] — fail if REGEX matches any tracked file in PATHSPEC.
forbid() {
  local id=$1 re=$2
  shift 2
  local hits
  # git grep exits 1 when nothing matches, which is the passing case here.
  hits="$(git grep -nIE -e "${re}" -- "${@:-.}" ':!tests/check-repo-hygiene.sh' ':!CHANGELOG.md' || true)"
  if [[ -n "${hits}" ]]; then
    echo "[FAIL] ${id}: /${re}/"
    sed 's/^/         /' <<<"${hits}"
    fails=$((fails + 1))
  else
    echo "[PASS] ${id}: no /${re}/"
  fi
}

forbid "FR-J2 one term (bastion)"         '[Jj]ump ?(box|host)'
forbid "Node names are mw01-mw03"          '\bcp0[1-3]\b|\bCP0[1-3]_'
forbid "FR-J2 renamed lab files"          '03-worksheet|04-jumpbox'
forbid "FR-J7 no .local domain"           'ocp-v\.local'
forbid "FR-A2 no workers outside appendix" '\bwk0[12]' ':!docs/labs/appendix-a-adding-workers.md'
forbid "FR-E8 no PXE outside appendix"    'pxelinux|tftp' ':!docs/labs/appendix-b-network-boot.md'
forbid "FR-C1 no :5000/:443 registry"     'registry[^ ]*:(5000|443)\b|:5000\b'
forbid "FR-C2 no registry:2 fallback"     'registry:2\b'
forbid "FR-I4 no curl -k"                 'curl (-[a-zA-Z]*k|--insecure)'
forbid "FR-E3 no plaintext passwords"     '--plaintext|changeme' 'kickstart/' 'manifests/' 'install-config/' 'scripts/' 'network/' '.env.example'
forbid "FR-F2 no chronyc -h remote"       'chronyc -h ["$0-9]'
forbid "FR-J6 no README placeholder"      '<insert ' README.md
forbid "FR-H11 no running: true"          'running: true'
forbid "FR-G5 no host-passthrough gate"   'withHostPassthroughCPU: true'
forbid "NFR-8 no :latest in deliverables" ':latest\b' 'mirror/' 'manifests/' 'install-config/' 'kickstart/'
forbid "NFR-7 no site values in scripts"  '10\.10\.[0-9]|lab\.example\.com|\bens[0-9]+f[0-9]|\beno[0-9]\b' 'scripts/*.sh' 'scripts/lib/*.sh'
forbid "R1 no vSphere sample values in inputs" '00:50:56|\bens192\b' '.env.example' 'install-config/' 'kickstart/' 'manifests/' 'mirror/' 'network/'

echo "check-repo-hygiene: ${fails} rule(s) failed"
[[ ${fails} -eq 0 ]]
