# 16 — Cleaning Up

> **Grade:** operational. On bare metal "cleanup" means re-imaging, not deleting cloud VMs.

## Goal

Reset the lab for a re-run, or tear it down, without leaving credentials behind.

## Steps

### 16.1 Soft reset: rebuild the ISO for the same rack

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Everything the installer wrote lives in `${INSTALL_DIR}`, outside the repo, and every
input is re-rendered from `.env`, so a reset is one directory. Consumed by: a fresh Lab 08.
If skipped: `03-generate-install-config.sh` refuses to overwrite an installed cluster's directory.

**EDIT** — No edits in this step (edit `.env` here if the rack changed, then re-run Lab 03 step 3.3).

**DO**

```bash
set -a && source .env && set +a
rm -rf "${INSTALL_DIR}"
```

**VERIFY** — `test -e "${INSTALL_DIR}" || echo gone` → expect: `gone`. Then repeat Labs 08–10.

**FAILS IF** — You delete the directory of a cluster you still need ← its kubeconfig is gone; keep a copy first.

### 16.2 Hard reset: re-image the nodes

**WHERE** — XCC of each node

**WHY** — A new Agent ISO only installs onto disks the installer considers free; re-initialising
the RAID1 virtual disk guarantees it. Consumed by: Lab 10. If skipped: stale RHCOS partitions can confuse a re-install.

**EDIT** — No edits in this step.

**DO** — In each XCC, re-initialise the RAID1 virtual disk (Lab 05 step 5.1), then boot the new ISO (Lab 10).

**VERIFY** — Lab 10 step 10.2 prints `PASS`.

**FAILS IF** — The installer reports the target disk in use ← the virtual disk was not re-initialised.

### 16.3 Registry and credentials

**WHERE** — Registry host (or bastion), RHEL 9.x, as `installer` with `sudo`

**WHY** — Removing the registry frees its storage; the auth file and pull secret are the only
secrets the run created outside `INSTALL_DIR`. Consumed by: site hygiene.
If skipped: a stale registry password keeps working.

**EDIT** — No edits in this step.

**DO**

```bash
sudo "${MIRROR_DIR}/clients/mirror-registry/mirror-registry" uninstall --quayRoot /opt/quay-install
shred -u "${AUTH_FILE}"           # only when the mirror is retired
```

**VERIFY** — `curl -s -o /dev/null -w '%{http_code}\n' "https://${MIRROR_REGISTRY}/v2/"` → expect: `000`.

**FAILS IF** — Still `200`/`401` ← the uninstall targeted a different `--quayRoot`.

The bastion's DNS and NTP stay running unless the whole site is being retired (ADR-07).

## Done

Return to the [README labs list](../../README.md#labs).
