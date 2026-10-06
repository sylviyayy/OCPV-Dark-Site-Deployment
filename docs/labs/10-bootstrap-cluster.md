# 10 — Bootstrapping the Cluster with the Agent-based Installer

> **Grade:** production-grade install method. Agent ISO through BMC virtual media; no network
> boot, no kickstart on RHCOS.

## Goal

Boot the three servers from the Agent ISO, wait for the install to finish, and prove the result:
three Ready nodes, four-member bonds, RHCOS on the RAID1 disk, time from the bastion.

## Steps

### 10.1 Boot every node from the Agent ISO

**WHERE** — XCC of `mw01`, `mw02`, `mw03` (`MW01_BMC_IP` …), from the admin workstation; the ISO is `${INSTALL_DIR}/agent.x86_64.iso` on the bastion

**WHY** — The ISO carries each host's identity; a booting server finds its `hosts[]` entry by MAC,
applies its bond and static IP, and joins the rendezvous node (`RENDEZVOUS_IP`), which runs the
temporary control plane. Consumed by: the Agent installer. If skipped: there are no hosts to install.

**EDIT** — No edits in this step.

**DO** — Copy the ISO to the admin workstation (`scp installer@<BASTION_IP>:<INSTALL_DIR>/agent.x86_64.iso .`),
then on each XCC: Remote Console → Media → mount `agent.x86_64.iso` → one-time boot from virtual CD →
power cycle. Boot the node whose IP is `RENDEZVOUS_IP` first, then the other two.

**VERIFY** — Each console shows the agent TUI, then a login prompt naming the node's hostname.

**FAILS IF** — The console shows the agent TUI asking for network configuration ← no `hosts[]`
entry matched this server's MACs; fix C3 in `.env`, re-run Lab 08, re-boot.

### 10.2 Wait for install-complete

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `openshift-install agent wait-for` follows bootstrap and then install progress, and writes
`${INSTALL_DIR}/auth/kubeconfig`. Script 05b then asserts the outcome rather than trusting an exit code:
three Ready nodes and, on each, `bond0` with four members all up (AT-07). It does **not** apply the
mirror cluster-resources; Lab 12 owns that (FR-D9). Consumed by: Labs 11–16.
If skipped: you have no kubeconfig and no proof.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/05b-wait-install.sh
```

**VERIFY** — Last line: `PASS: install complete; 3 nodes Ready; every bond0 has 4 members up`.

**FAILS IF** — "waiting for hosts" never advances ← a MAC typo or a non-bond NIC in C3;
bootstrap hangs at image pull ← the registry name does not resolve from the nodes (Lab 07) or the
mirror is incomplete (Lab 06 step 6.8).

### 10.3 Prove root disk and time source on a node

**WHERE** — Bastion, RHEL 9.x, as `installer`

**WHY** — `rootDeviceHints` must have put RHCOS on the RAID1 virtual disk, and
`additionalNTPSources` must have pointed chrony at your time source; neither failure stops the
install, so both are checked here (FR-D5, FR-D6). Consumed by: etcd health; disk survivability.
If skipped: a node on a single SSD or a free-running clock goes unnoticed until it fails.

**EDIT** — No edits in this step.

**DO**

```bash
set -a && source .env && set +a
export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
oc debug "node/${MW01_HOSTNAME}" --quiet -- chroot /host sh -c \
  "readlink -f ${MW01_ROOT_DEVICE}; findmnt -no SOURCE /sysroot; chronyc -n sources"
```

**VERIFY**

```text
expect: the device from readlink is the parent of the /sysroot source (for example /dev/sda and /dev/sda4)
expect: a line starting with ^* naming TIME_SOURCE (or BASTION_IP when orphan)
```

Repeat for `MW02_HOSTNAME` and `MW03_HOSTNAME`.

**FAILS IF** — No `^*` line ← the node cannot reach UDP 123 on the time source; skew will break etcd.

## Next

→ [11 — Configuring `oc` for Remote Access](11-oc-remote-access.md)
