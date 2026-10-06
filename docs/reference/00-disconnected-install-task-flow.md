# Disconnected Installation Task Flow (OpenShift 4.22)

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../labs/README.md); where this page and a lab disagree, the lab wins.

This page maps the Red Hat disconnected-installation workflow onto this repository's labs and
scripts. Sources:

- [Disconnected environments (OCP 4.22)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index)
- [Agent-based Installer — disconnected mirroring](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/understanding-disconnected-installation-mirroring)
- [Installing OpenShift Virtualization (OCP 4.22)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/installing)

> **Preferred stack (Red Hat 4.22):** oc-mirror plugin **v2** → Agent-based Installer →
> IDMS/ITMS cluster resources (not the deprecated ICSP).

## Task map

| Phase | Task | Lab | Script / artefact |
|---|---|---|---|
| 0 Decide | Field register signed; `.env` validated | 03 | `scripts/lib/validate-env.sh` |
| 1 Low side | Clients verified against `sha256sum.txt`; auth file; ImageSet pinned by digest | 06.1 | `scripts/01-mirror-preparation.sh` |
| 1 Low side | Mirror to disk | 06.2 | `scripts/01-mirror-preparation.sh --mirror-to-disk` |
| 1 Low side | Bastion and registry ISOs with embedded kickstarts | 04 | `scripts/render-kickstart.sh`, `mkksiso` |
| 2 Transfer | Approved media + `SHA256SUMS` | 06.3–06.4 | `sha256sum -c` |
| 3 High side | DVD repo; mirror registry (port 8443); CA trust; disk to mirror | 06.5–06.8 | `scripts/04b-serve-dvd-repo.sh`, `scripts/04-mirror-ocp-images.sh` |
| 3 High side | Bastion DNS and NTP | 07 | `scripts/02-bootstrap-dns-ntp.sh` |
| 4 Install | Render install/agent config; Agent ISO | 08 | `scripts/03-…`, `scripts/05a-create-agent-iso.sh` |
| 4 Install | Boot via XCC virtual media; wait | 10 | `scripts/05b-wait-install.sh` |
| 5 Platform | Disable default catalogs; apply cluster-resources | 12 | `oc patch OperatorHub`, `oc apply -f ${CLUSTER_RESOURCES_DIR}/` |
| 5 Platform | OpenShift Virtualization, NMState, default StorageClass | 13 | `scripts/06-deploy-cnv.sh`, `scripts/06b-configure-storage.sh` |
| 6 Services | Two DNS VMs, NTP VM, node cut-over (bastion stays secondary) | 14 | `scripts/07-…`, `scripts/08-…` |
| 7 Prove | Post-install checks, secrets check, cold-start drill | 15 | `scripts/00-prerequisites-check.sh --post-install` |

## Typical problems and mitigations

| Problem | Mitigation |
|---|---|
| Inconsistent artefact versions | One z-stream in `.env` A3 and the ImageSet; additional images pinned by digest |
| Wrong operator catalog | `redhat-operator-index:v<minor>` is derived from `OCP_VERSION` |
| Incorrect install/agent config | Generated from `.env`; `validate-env.sh` rejects sample MACs and devices |
| Registry TLS failures | Trust mirror-registry's own CA on the bastion; never `-k` |
| Pulls return 401 | `pullSecret` must be the merged auth file with the mirror registry entry |
| `oc adm release mirror` used | Deprecated in 4.22 — oc-mirror v2 only |

## Optional: aba (community accelerator)

[aba](https://github.com/sjbylo/aba) (described on
[Red Hat Developer](https://developers.redhat.com/articles/2025/10/14/simplify-openshift-installation-air-gapped-environments))
wraps the Agent-based Installer and oc-mirror to reduce manual steps. It is **not** a Red Hat
product; useful for customer POCs once the steps in these labs are understood.
