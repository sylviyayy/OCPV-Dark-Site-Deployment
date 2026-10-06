# 08 — Generating Install and Agent Configuration

> **Grade:** production-grade. Generation is complete and reproducible from `.env` plus the
> templates; nothing is hand-edited.

## Goal

Render `install-config.yaml` and `agent-config.yaml` into `${INSTALL_DIR}` (outside the repo),
then build the Agent ISO from them.

## What gets rendered, and from where

| File → key | Source |
|---|---|
| install-config → `compute[0].replicas: 0`, `controlPlane.replicas: 3` | template (compact, FR-A2) |
| install-config → `imageDigestSources` | `${CLUSTER_RESOURCES_DIR}/idms-oc-mirror.yaml` (FR-D1) |
| install-config → `pullSecret` | `${AUTH_FILE}` — pull secret **plus** the mirror registry entry (FR-D2) |
| install-config → `additionalTrustBundle` | `${REGISTRY_CA_FILE}`, every PEM line indented (FR-D3) |
| agent-config → `hosts[n]` | C1–C4: hostname, 4 MACs, `bond0` 802.3ad, `rootDeviceHints` (FR-D4, FR-D5) |
| agent-config → `additionalNTPSources` | `TIME_SOURCE`, or `BASTION_IP` when orphan (FR-D6) |
| agent-config → `metadata.name` | `CLUSTER_NAME` (FR-D8) |

## Steps

### 8.1 Render the installer inputs

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — These two files are the contract between your rack and the installer. `render.py` builds
them as data — a host list, four bond ports per host, a PEM bundle — because text substitution
cannot emit a variable-length list, and the old template had no tokens at all, so the sample MACs
reached every ISO. Consumed by: `openshift-install agent create image` (8.2).
If skipped: 8.2 has no inputs.

**EDIT** — No edits in this step. If a value is wrong, fix `.env` and re-run; never edit the rendered files (rule E2).

**DO**

```bash
./scripts/03-generate-install-config.sh
```

**VERIFY**

```bash
set -a && source .env && set +a
grep -c macAddress "${INSTALL_DIR}/agent-config.yaml"                     # expect: 12
grep -c 00:50:56 "${INSTALL_DIR}/agent-config.yaml"                       # expect: 0
grep -c 'replicas: 0' "${INSTALL_DIR}/install-config.yaml"                # expect: 1
grep -cE 'source: quay.io/openshift-release-dev/(ocp-release|ocp-v4.0-art-dev)$' "${INSTALL_DIR}/install-config.yaml"   # expect: 2
python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('parse-ok')" \
  "${INSTALL_DIR}/install-config.yaml" "${INSTALL_DIR}/agent-config.yaml"   # expect: parse-ok
```

**FAILS IF** — "AUTH_FILE has no auths entry for registry…" ← Lab 06 step 6.8 did not run;
"does not map quay.io/openshift-release-dev/ocp-release" ← the release was not mirrored.

### 8.2 Create the Agent ISO

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `openshift-install agent create image` embeds the rendered configuration into the ISO's
Ignition and **consumes** both input files. Script 05a keeps them as `*.orig` first, and first
proves that neither VIP answers ping (another host owning a VIP breaks the install silently).
It pulls the release payload from the mirror over TLS from this bastion, which is why Lab 06
step 6.7 trusted the CA. Consumed by: XCC virtual media in Lab 10. If skipped: there is nothing to boot.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/05a-create-agent-iso.sh
```

**VERIFY** (AT-06)

```bash
ls "${INSTALL_DIR}/agent.x86_64.iso"                                 # expect: the path
ls "${INSTALL_DIR}"/*.yaml.orig | wc -l                              # expect: 2
git -C ~/OCPV-Dark-Site-Deployment status --porcelain | wc -l        # expect: 0 (nothing new in the repo)
```

**FAILS IF** — `x509: certificate signed by unknown authority` ← the registry CA is not trusted on the bastion (Lab 06 step 6.7);
"API_VIP answers ping before install" ← another host owns the VIP.

## Next

→ [09 — Certificates, Encryption, and etcd](09-certificates-etcd.md)
