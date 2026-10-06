# 15 — Smoke Test

> **Grade:** the honest summary of the run. `TIME_SOURCE=orphan` or `STORAGE_BACKEND=hpp` means a
> healthy **lab-grade** cluster, not a production one.

## Goal

Prove the finished state end to end: a healthy air-gapped OpenShift Virtualization cluster running
its own DNS and NTP VMs, no secrets in the repo, and a site that survives a cold start.

## Steps

### 15.1 Run the post-install checks

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Each check compares a value, so a broken cluster cannot pass: nodes Ready; operators
Available and not Degraded; only mirrored catalogs; samples operator Removed; both DNS VMs answer A
and PTR from `.env`; NTP VM and bastion serve time; registry TLS verified; `HyperConverged` Available;
the default StorageClass is the one `STORAGE_BACKEND` implies; both NNCPs Available; `mcp/master` Updated.

**EDIT** — None.

**DO** — `./scripts/00-prerequisites-check.sh --post-install`

**VERIFY** — Last line `Results: N passed, 0 failed`. To see it fail honestly (AT-11): power off one
node and re-run; it exits 1 at `API answers and all nodes Ready`.

**FAILS IF** — Any `[FAIL]` line ← it names the broken check; fix before handover.

### 15.2 Prove no secret sits in the working tree

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `INSTALL_DIR` and `MIRROR_DIR` are outside the repo (ADR-08), so a full run leaves no
secret-bearing file inside it, ignored or not (AT-13). One careless `git add .` must not publish a kubeconfig.

**EDIT** — None.

**DO / VERIFY** — `git status --ignored --porcelain` → only `!! .env` (site values, no passwords).

**FAILS IF** — Any other line ← a path in `.env` points into the repo; move it out.

### 15.3 Cold-start drill (recommended before handover)

**WHERE** — Bastion console and the three XCCs

**WHY** — Proves ADR-07: the bastion alone brings back DNS and time, so the cluster and then its own
DNS/NTP VMs recover without intervention (AT-12). Otherwise the first real power loss is the test.

**EDIT** — None.

**DO** — Shut the three nodes down from their XCCs; power off the bastion. Power on the bastion first,
wait for `systemctl is-active dnsmasq chronyd` → `active` ×2, then power on the nodes.

**VERIFY** — Within 30 minutes: `./scripts/00-prerequisites-check.sh --post-install` → `0 failed`.

**FAILS IF** — Operators stay Unavailable with name-resolution errors ← bastion not up first, or its
services disabled (Lab 14 step 14.3).

## Next

→ [16 — Cleaning Up](16-cleanup.md)
