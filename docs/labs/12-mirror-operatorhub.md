# 12 — Integrating the Mirror Registry and OperatorHub

> **Grade:** production-grade. This lab is the single owner of the oc-mirror cluster resources (FR-D9).

## Goal

Make OperatorHub use only the mirrored catalog, and teach the cluster every mirror mapping
oc-mirror produced (release, operators, signatures).

## Steps

### 12.1 Disable the default catalog sources

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The default CatalogSources point at `registry.redhat.io`; in a dark site their pods sit
in `ImagePullBackOff` and add noise to every operator lookup (FR-G2).
Consumed by: OperatorHub and OLM. If skipped: four failing catalogs mask real errors in Lab 13.

**EDIT** — `OperatorHub/cluster` → `spec.disableAllDefaultSources` from: unset → to: `true`.

**DO**

```bash
oc patch OperatorHub cluster --type merge -p '{"spec":{"disableAllDefaultSources":true}}'
```

**VERIFY**

```bash
oc get operatorhub cluster -o jsonpath='{.spec.disableAllDefaultSources}{"\n"}'   # expect: true
```

**FAILS IF** — `redhat-operators` still listed after a minute ← the patch went to another object; re-run it.

### 12.2 Apply the oc-mirror cluster resources

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — oc-mirror v2 wrote `ImageDigestMirrorSet`, `ImageTagMirrorSet`, the `CatalogSource` for
the mirrored `redhat-operator-index`, and release signatures into `${CLUSTER_RESOURCES_DIR}`
during disk-to-mirror (FR-B5). The install already carries the release mappings
(`imageDigestSources`); this adds the operator mappings and the catalog.
Consumed by: OLM in Lab 13 (script 06 reads the CatalogSource name from these files, FR-G1).
If skipped: script 06 waits for a catalog that does not exist.

**EDIT** — No edits in this step.

**DO**

```bash
set -a && source .env && set +a
oc apply -f "${CLUSTER_RESOURCES_DIR}/"
```

**VERIFY**

```bash
CS="$(./scripts/lib/render.py catalog-source)"; echo "${CS}"                      # expect: cs-redhat-operator-index-v4-22 (verify on 4.22)
oc get catalogsource -n openshift-marketplace -o name                              # expect: only catalogsource/<CS>
oc get catalogsource "${CS}" -n openshift-marketplace \
  -o jsonpath='{.status.connectionState.lastObservedState}{"\n"}'                 # expect: READY (within ~2 minutes)
oc get packagemanifest kubevirt-hyperconverged -o jsonpath='{.status.catalogSource}{"\n"}'   # expect: <CS>
```

**FAILS IF** — The CatalogSource pod is in `ImagePullBackOff` ← the operator index was not mirrored,
or IDMS/ITMS were not applied; check `oc get imagedigestmirrorset,imagetagmirrorset`.

## Next

→ [13 — Installing OpenShift Virtualization](13-openshift-virtualization.md)
