# 12 — Integrating the Mirror Registry and OperatorHub

> **Grade:** production-grade. This lab is the single owner of the oc-mirror cluster resources.

## Goal

Point OperatorHub only at the mirrored catalogs, switch off what reaches for the internet, and
give the cluster every mirror mapping oc-mirror produced.

## Steps

### 12.1 Disable the default catalog sources

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The four default CatalogSources point at `registry.redhat.io`; in a dark site their pods
sit in `ImagePullBackOff` forever and bury real errors in Lab 13.

**EDIT** — `OperatorHub/cluster` → `spec.disableAllDefaultSources`: unset → `true`.

**DO** — `oc patch OperatorHub cluster --type merge -p '{"spec":{"disableAllDefaultSources":true}}'`

**VERIFY** — `oc get catalogsource -n openshift-marketplace` → `No resources found` (until 12.3).

**FAILS IF** — `redhat-operators` still listed after a minute ← the patch did not apply; re-run it.

### 12.2 Remove the Cluster Samples Operator's content

**WHERE** — Bastion, `installer`

**WHY** — Its image streams import from `registry.redhat.io`; in a dark site they fail on every
retry, and the operator can report itself Degraded. VM workloads do not use them. On a disconnected
install it may already have set itself to `Removed`; setting it explicitly makes the state a decision,
not an accident.

**EDIT** — `configs.samples.operator.openshift.io/cluster` → `spec.managementState`: `Managed` → `Removed`.

**DO** — `oc patch configs.samples.operator.openshift.io cluster --type merge -p '{"spec":{"managementState":"Removed"}}'`

**VERIFY** — `oc get configs.samples.operator.openshift.io cluster -o jsonpath='{.status.managementState}{"\n"}'` → `Removed`.

**FAILS IF** — Still `Managed` after a minute ← the patch did not apply; re-run it.

### 12.3 Apply the oc-mirror cluster resources

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Disk-to-mirror (Lab 06 step 6.8) wrote these into `${CLUSTER_RESOURCES_DIR}`:

| File | Effect |
|---|---|
| `idms-oc-mirror.yaml`, `itms-oc-mirror.yaml` (when present) | operator image pulls by digest and by tag go to the mirror |
| `cs-redhat-operator-index-….yaml` (+ `cs-certified-operator-index-…` with `ontap`) | the mirrored catalogs OLM installs from |
| signature files | release signatures for verified updates |

The install already carries the release mappings (Lab 08). The Machine Config Operator rolls the new
mirror configuration to every node; wait for it before installing operators.
*Consumed by:* script 06, which reads the CatalogSource name from these files rather than guessing it.
*If skipped:* script 06 waits for a catalog that does not exist, then exits 1.

**EDIT** — None.

**DO**

```bash
set -a && source .env && set +a
oc apply -f "${CLUSTER_RESOURCES_DIR}/"
oc wait mcp --all --for=condition=Updated --timeout=30m
```

**VERIFY**

```bash
CS="$(./scripts/lib/render.py catalog-source)"; echo "${CS}"           # expect: cs-redhat-operator-index-v4-22 (verify on 4.22)
oc get catalogsource "${CS}" -n openshift-marketplace \
  -o jsonpath='{.status.connectionState.lastObservedState}{"\n"}'      # expect: READY (within ~2 min)
oc get packagemanifest kubevirt-hyperconverged -o jsonpath='{.status.catalogSource}{"\n"}'   # expect: <CS>
```

**FAILS IF** — CatalogSource pod in `ImagePullBackOff` ← index not mirrored, or IDMS/ITMS not applied
(`oc get imagedigestmirrorset,imagetagmirrorset`).

## Next

→ [13 — Installing OpenShift Virtualization](13-openshift-virtualization.md)
