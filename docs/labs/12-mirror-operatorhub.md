# 12 — Integrating the Mirror Registry and OperatorHub

## Goal

Apply oc-mirror v2 cluster resources (IDMS/ITMS + CatalogSource) so operators install offline.

## WHERE

Jumpbox with `KUBECONFIG`.

```bash
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
oc apply -f install-config/cluster-resources/ \
  || oc apply -f "${OC_MIRROR_WORKDIR}/cluster-resources/"
```

## WHY

Without this, OperatorHub tries public registries and fails in a dark site.

## VERIFY

```bash
oc get imagedigestmirrorset,imagetagmirrorset,catalogsource -A
oc get packagemanifests | head
```

## Next

→ [13 — Installing OpenShift Virtualization](13-openshift-virtualization.md)

