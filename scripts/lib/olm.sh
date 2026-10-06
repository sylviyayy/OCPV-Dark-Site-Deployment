#!/usr/bin/env bash
# OLM helpers shared by scripts 06 and 06c. Sourced after common.sh; never executed on its own.
#
# Polls send stderr to /dev/null: while an object is still being created `oc get` reports
# NotFound on every poll, and each timeout path prints the real diagnostics instead.

# wait_catalog INDEX — print the CatalogSource name oc-mirror gave INDEX once it is READY.
# oc-mirror v2 names it after the catalog image and tag (for example
# cs-redhat-operator-index-v4-22), so the name is read from its output, never guessed (FR-G1).
wait_catalog() {
  local cs
  cs="$(render catalog-source "$1")"
  catalog_ready() {
    [[ "$(oc get catalogsource "${cs}" -n openshift-marketplace \
          -o jsonpath='{.status.connectionState.lastObservedState}' 2>/dev/null)" == "READY" ]]
  }
  if ! wait_until 600 15 "CatalogSource ${cs} READY" catalog_ready >&2; then
    oc get catalogsource -n openshift-marketplace >&2
    log_error "Apply ${CLUSTER_RESOURCES_DIR} first (Lab 12)."
    exit 1
  fi
  echo "${cs}"
}

# install_operator NAMESPACE PACKAGE CHANNEL SOURCE [MODE] — OperatorGroup + Subscription, then
# wait for the subscribed CSV to reach Succeeded or exit 1 with diagnostics (FR-G4).
#   MODE OwnNamespace (default): the OperatorGroup targets NAMESPACE only.
#   MODE AllNamespaces: a cluster-wide OperatorGroup (empty spec). In openshift-operators none is
#   created: the cluster already has one there, and a second makes OLM refuse every
#   Subscription in the namespace (TooManyOperatorGroups).
install_operator() {
  local ns=$1 pkg=$2 channel=$3 source=$4 mode=${5:-OwnNamespace} og_spec
  if [[ "${mode}" == "OwnNamespace" ]]; then
    og_spec="spec:
  targetNamespaces:
    - ${ns}"
  else
    og_spec="spec: {}"
  fi
  if ! oc get packagemanifest "${pkg}" -n openshift-marketplace &>/dev/null; then
    log_error "${pkg} is not in any mirrored catalog: add it to mirror/imageset-profiles.yaml and re-mirror (Lab 06)"
    exit 1
  fi
  oc create namespace "${ns}" --dry-run=client -o yaml | oc apply -f -
  # One OperatorGroup per namespace: reuse whatever is there (an earlier run, the cluster's own
  # global-operators), because a second one blocks every Subscription in the namespace.
  local existing
  existing="$(oc get operatorgroup -n "${ns}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)"
  if [[ -n "${existing}" && "${existing}" != "${ns}" ]]; then
    log_info "${ns}: reusing OperatorGroup ${existing}"
  elif [[ "${ns}" != "openshift-operators" ]]; then
    oc apply -f - <<EOF_OG
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ${ns}
  namespace: ${ns}
${og_spec}
EOF_OG
  fi
  oc apply -f - <<EOF_SUB
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${pkg}
  namespace: ${ns}
spec:
  channel: ${channel}
  name: ${pkg}
  source: ${source}
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF_SUB
  csv_succeeded() {
    local csv
    csv="$(oc get subscription "${pkg}" -n "${ns}" -o jsonpath='{.status.installedCSV}' 2>/dev/null)"
    [[ -n "${csv}" && "$(oc get csv "${csv}" -n "${ns}" -o jsonpath='{.status.phase}' 2>/dev/null)" == "Succeeded" ]]
  }
  if ! wait_until 900 15 "${pkg} CSV Succeeded in ${ns}" csv_succeeded; then
    oc get operatorgroup,subscription,installplan,csv -n "${ns}"
    oc get subscription "${pkg}" -n "${ns}" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
    exit 1
  fi
}
