# 15 — Smoke Test

> **Grade:** the honest summary of the run. With `TIME_SOURCE=orphan` or `STORAGE_BACKEND=hpp`
> the result is a healthy **lab-grade** cluster, not a production one.

## Goal

Prove the finished state end to end: a healthy air-gapped OpenShift Virtualization cluster
running its own DNS and NTP VMs, no secrets in the repo, and a site that survives a cold start.

## Steps

### 15.1 Run the post-install checks

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Each check returns one status and compares a value, so a broken cluster cannot pass:
nodes Ready, operators Available and not Degraded, only mirrored catalogs, both DNS VMs answering
A and PTR records from `.env`, the NTP VM and the bastion serving time, TLS-verified registry,
`HyperConverged` Available, default StorageClass, both NNCPs Available, MachineConfigPool updated
(FR-I1, FR-I3). Consumed by: your sign-off. If skipped: "it seems to work" is the evidence.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/00-prerequisites-check.sh --post-install
```

**VERIFY** — Last line: `Results: N passed, 0 failed` (exit 0). To see it fail honestly (AT-11):
stop kubelet on one node and re-run; it exits 1 naming `API answers and all nodes Ready`.

**FAILS IF** — Any `[FAIL]` line ← the line names the broken check; fix it before handing over.

### 15.2 Prove no secret sits in the working tree

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `INSTALL_DIR` and `MIRROR_DIR` are outside the repo (ADR-08), so a full run should leave
no secret-bearing file inside it, ignored or not (AT-13). Consumed by: anyone who later runs `git add .`.
If skipped: a kubeconfig or pull secret can be published by one careless push.

**EDIT** — No edits in this step.

**DO**

```bash
git status --ignored --porcelain
```

**VERIFY** — The only line is `!! .env` (site values, no passwords). Expect no `auth/`,
`kubeconfig`, `pull-secret.json`, `auth.json`, `*.iso` or rendered `*.cfg`.

**FAILS IF** — Any other `!!` line ← a path in `.env` points into the repo; move it out and re-run.

### 15.3 Cold-start drill (optional, recommended before handover)

**WHERE** — Bastion console and the three XCCs

**WHY** — Proves ADR-07: the bastion alone can bring DNS and time back so the cluster and then its
own DNS/NTP VMs recover with no manual intervention (AT-12). Consumed by: the site's recovery runbook.
If skipped: the first real power loss is the test.

**EDIT** — No edits in this step.

**DO** — Shut the three nodes down from their XCCs and power off the bastion. Power on the bastion
first, wait for `systemctl is-active dnsmasq chronyd` → `active active`, then power on the three nodes.

**VERIFY** — Within 30 minutes: `./scripts/00-prerequisites-check.sh --post-install` → `0 failed`.

**FAILS IF** — Operators stay Unavailable with name-resolution errors ← the bastion was not up first, or its services were disabled (Lab 14 step 14.3).

## Next

→ [16 — Cleaning Up](16-cleanup.md)
