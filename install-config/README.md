# install-config/ — templates only

This folder holds **skeletons**, never generated files. `scripts/03-generate-install-config.sh`
loads them as data, fills every value from `.env`, and writes the results to
`${INSTALL_DIR}` — a directory **outside** the git working tree (ADR-08), because
`openshift-install` writes `auth/kubeconfig`, `auth/kubeadmin-password` and
`.openshift_install_state.json` (which embeds the pull secret) next to its inputs.

| File | Rendered to | Rendered by |
|---|---|---|
| `install-config.yaml.template` | `${INSTALL_DIR}/install-config.yaml` | `scripts/lib/render.py install-config` |
| `agent-config.yaml.template` | `${INSTALL_DIR}/agent-config.yaml` | `scripts/lib/render.py agent-config` |

Never hand-edit a rendered file (rule E2): change `.env` or the skeleton and re-run script 03.

## How the mirror reaches the installer

oc-mirror v2 writes its cluster resources to
`${CLUSTER_RESOURCES_DIR}` (= `${MIRROR_ARCHIVE_DIR}/working-dir/cluster-resources/`) during
disk-to-mirror (Lab 06). Two consumers read them:

| Consumer | What it takes | When |
|---|---|---|
| `render.py install-config` | `idms-oc-mirror.yaml` → `imageDigestSources` | Lab 08, before the Agent ISO exists |
| Lab 12 | the whole folder (`ImageDigestMirrorSet`, `ImageTagMirrorSet`, `CatalogSource`, signatures) | after install |

> `ImageContentSourcePolicy` (ICSP) is superseded by IDMS/ITMS on OpenShift 4.22.

## Three facts the Agent ISO needs (all rendered, none hand-typed)

1. **`additionalTrustBundle`** — the mirror registry's root CA from `${REGISTRY_CA_FILE}`,
   written as a YAML literal block so every PEM line is indented (FR-D3).
2. **`imageDigestSources`** — copied from oc-mirror's `idms-oc-mirror.yaml`, never hard-coded (FR-D1).
   Think of a postal forwarding order: the label still says `quay.io`, the parcel goes to your registry.
3. **`pullSecret`** — the **merged** `${AUTH_FILE}`: the Red Hat pull secret **plus** the mirror
   registry entry. Nodes authenticate to the mirror with whatever `pullSecret` holds, so the
   mirror-registry credentials **must** be in it; without them every pull returns 401 (FR-D2).
