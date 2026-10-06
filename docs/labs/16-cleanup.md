# 16 — Cleaning Up

> **Grade:** operational. On bare metal, "cleanup" means re-imaging, not deleting cloud VMs.

## Goal

Reset for a re-run, or tear down, without leaving credentials behind.

## Steps

### 16.1 Soft reset: new ISO for the same rack

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Everything the installer wrote is in `${INSTALL_DIR}`, and every input is re-rendered from
`.env`, so a reset is one directory. Script 03 refuses to overwrite a directory that holds an installed
cluster's kubeconfig; removing it (or `--force`) is the deliberate act.

**EDIT** — `.env` only if the rack changed (then re-run `./scripts/lib/validate-env.sh`).

**DO**

```bash
set -a && source .env && set +a
cp "${INSTALL_DIR}/auth/kubeconfig" ~/kubeconfig.previous && chmod 600 ~/kubeconfig.previous   # if still needed
rm -rf "${INSTALL_DIR}"
```

**VERIFY** — `test -e "${INSTALL_DIR}" || echo gone` → `gone`. Then Labs 08 → 10.

**FAILS IF** — You removed the directory of a cluster you still run ← its kubeconfig is gone with it.

### 16.2 Hard reset: re-image the nodes

**WHERE** — XCC of each node

**WHY** — A fresh RAID1 virtual disk guarantees no stale RHCOS partitions or etcd data survive into
the re-install.

**EDIT** — None.

**DO** — Re-initialise the RAID1 virtual disk (Lab 05 step 5.1), then boot the new ISO (Lab 10).

**VERIFY** — Lab 10 step 10.2 prints `PASS`.

**FAILS IF** — Installer reports the target disk in use ← virtual disk not re-initialised.

### 16.3 Registry and credentials (retiring the mirror)

**WHERE** — Registry host (or bastion), `installer` with `sudo`

**WHY** — Frees the registry's storage and removes the only secrets the run created outside `INSTALL_DIR`.

**EDIT** — None.

**DO**

```bash
sudo "${MIRROR_DIR}/clients/mirror-registry/mirror-registry" uninstall --quayRoot /opt/quay-install
shred -u "${AUTH_FILE}"
```

**VERIFY** — `curl -s -o /dev/null -w '%{http_code}\n' "https://${MIRROR_REGISTRY}/v2/"` → `000`.

**FAILS IF** — Still `200`/`401` ← uninstall targeted a different `--quayRoot`.

The bastion's DNS and NTP stay running unless the whole site is retired (ADR-07).

## Done

Return to the [README labs list](../../README.md#labs).
