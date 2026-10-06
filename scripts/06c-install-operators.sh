#!/usr/bin/env bash
# Install the operators of one or more ImageSet profiles (Lab 13 step 13.3).
#
#   ./scripts/06c-install-operators.sh poc          MTV, Authorino, KMM, Pipelines, Service Mesh 3, Serverless
#   ./scripts/06c-install-operators.sh poc,odf      ... plus Local Storage and OpenShift Data Foundation
#
# mirror/imageset-profiles.yaml is the single list: the same entries were mirrored in Lab 06
# (--profile), so an operator cannot be installed here unless it crossed the air gap.
# Each entry names its namespace and install mode; dependency entries (no namespace) are
# installed by OLM itself. Operators are subscribed only; their instances (ForkliftController,
# KnativeServing, Istio, StorageCluster, ...) are workload decisions, made after this step.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=scripts/lib/olm.sh
source "${SCRIPT_DIR}/lib/olm.sh"

PROFILES="${1:-}"
if [[ -z "${PROFILES}" || "${PROFILES}" == -* ]]; then
  log_error "usage: $0 PROFILE[,PROFILE]   (profiles: mirror/imageset-profiles.yaml, e.g. poc or poc,odf)"
  exit 2
fi

load_env
validate_env
refuse_root
require_cmd oc python3
use_kubeconfig

entries="$(render operators "${PROFILES}")"
if [[ -z "${entries}" ]]; then
  log_error "profile(s) ${PROFILES} list no installable operator (entries need namespace and mode)"
  exit 1
fi

declare -A sources=()   # catalog index -> CatalogSource name
while read -r pkg channel ns mode index; do
  [[ -n "${sources[${index}]:-}" ]] || sources[${index}]="$(wait_catalog "${index}")"
  log_info "Installing ${pkg} (channel ${channel}) into ${ns} as ${mode}"
  install_operator "${ns}" "${pkg}" "${channel}" "${sources[${index}]}" "${mode}"
done <<<"${entries}"

log_info "PASS: every operator in profile(s) ${PROFILES} reports Succeeded:"
awk '{print "  " $1 " (" $3 ")"}' <<<"${entries}"
log_info "Next: create each operator's instance as the workload needs it (Lab 13 step 13.3 table)."
