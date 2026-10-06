# 08 — Generating Install and Agent Configuration

> **Grade:** production-grade. Both files are rendered from `.env`; nothing is hand-edited.

## Goal

Render `install-config.yaml` and `agent-config.yaml` into `${INSTALL_DIR}` (outside the repo) and
build the Agent ISO from them.

## What gets rendered, and from where

| File → key | Source | Why it matters |
|---|---|---|
| install-config → `controlPlane.replicas: 3`, `compute[0].replicas: 0` | template | compact: masters schedule workloads |
| install-config → `imageDigestSources` | `${CLUSTER_RESOURCES_DIR}/idms-oc-mirror.yaml` | release pulls go to the mirror |
| install-config → `pullSecret` | `${AUTH_FILE}` minus `cloud.openshift.com` | mirror credentials; no Telemetry to a host it cannot reach |
| install-config → `additionalTrustBundle` | `${REGISTRY_CA_FILE}` | nodes trust the mirror's TLS |
| agent-config → `hosts[n]` | C1–C4 | hostname, 4 MACs, `bond0` 802.3ad, static IP, `rootDeviceHints` |
| agent-config → `additionalNTPSources` | `TIME_SOURCE`, or `BASTION_IP` when orphan | time before first boot completes |

## Steps

### 8.1 Render the installer inputs

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — These files are the contract between the rack and the installer. `render.py` builds them
as data, not text substitution, because a host list with four bond ports each has variable length.
*Consumed by:* 8.2. *If skipped:* 8.2 has no inputs.

**EDIT** — None. A wrong value is fixed in `.env` and re-rendered, never in the output.

**DO** — `./scripts/03-generate-install-config.sh`

**VERIFY**

```bash
set -a && source .env && set +a
grep -c macAddress "${INSTALL_DIR}/agent-config.yaml"              # expect: 12
grep -c 'replicas: 0' "${INSTALL_DIR}/install-config.yaml"         # expect: 1
grep -c cloud.openshift.com "${INSTALL_DIR}/install-config.yaml"   # expect: 0
```

**FAILS IF** — "AUTH_FILE has no auths entry for registry…" ← Lab 06 step 6.8 not run;
"does not map …/ocp-release" ← the release was not mirrored.

### 8.2 Create the Agent ISO — T-0, the 24-hour clock starts

> **[WINDOW A]** The ISO embeds certificates that expire 24 hours after this command; Red Hat
> recommends booting the nodes within **12 hours**. Build it on site, only when you can boot all
> three nodes straight away (Lab 10). Never start T-0 at the end of a shift.

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `openshift-install agent create image` validates each host's network with `nmstatectl`,
pulls the release payload from the mirror (TLS trusted in Lab 06 step 6.7), embeds the configuration,
and **deletes** both inputs; script 05a keeps them as `*.orig` for audit. It first proves neither VIP
answers ping: a VIP owned by another host breaks the install with no clear error.
*Consumed by:* XCC virtual media in Lab 10.

**EDIT** — None.

**DO** — `./scripts/05a-create-agent-iso.sh`

**VERIFY** (AT-06)

```bash
ls "${INSTALL_DIR}/agent.x86_64.iso"                              # expect: the path
ls "${INSTALL_DIR}"/*.yaml.orig | wc -l                           # expect: 2
git -C ~/OCPV-Dark-Site-Deployment status --porcelain | wc -l     # expect: 0
```

If Window A lapses: restore the two `*.orig` files to their names in `${INSTALL_DIR}`, delete
`agent.x86_64.iso`, `auth/` and `.openshift_install_state.json`, and re-run 05a. Never mix an ISO
and an `auth/kubeconfig` from different runs.

**FAILS IF** — `x509: certificate signed by unknown authority` ← CA not trusted (Lab 06 step 6.7);
`answers ping before install` ← another host owns that VIP; `nmstatectl: command not found` ← `nmstate` RPM missing.

## Next

→ [09 — Certificates, Encryption, and etcd](09-certificates-etcd.md)
