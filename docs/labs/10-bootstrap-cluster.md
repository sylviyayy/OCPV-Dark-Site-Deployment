# 10 — Bootstrapping the Cluster with the Agent-based Installer

> **Grade:** production-grade install method: Agent ISO through BMC virtual media, no network boot.

## Goal

Boot the three servers from the Agent ISO, wait for the install, and prove the result: three Ready
nodes, four-member bonds, RHCOS on the RAID1 disk, time from your time source.

> **[WINDOW A]** Boot every node within 12 hours of building the ISO (hard limit 24).
> **[WINDOW B]** From the first boot, keep the cluster powered on and the bastion's DNS/NTP unchanged
> for 24 hours: the first certificate rotation runs 16–22 hours after install. If the cluster was
> powered off inside the window, approve the pending kubelet CSRs when it returns:
> `oc get csr -o name | xargs oc adm certificate approve`.

## Steps

### 10.1 Boot every node from the Agent ISO

**WHERE** — XCC of `mw01`–`mw03` (`MWn_BMC_IP`) from the admin workstation

**WHY** — Each booting server finds its `hosts[]` entry by MAC, applies its bond and static IP, and
registers with the **rendezvous node** (`RENDEZVOUS_IP`), which runs the temporary control plane and
installs the other two before itself. A **one-time** boot means the post-install reboot lands on the
RAID1 disk, not back in the ISO. *If skipped:* no hosts to install.

**EDIT** — None.

**DO** — `scp installer@<BASTION_IP>:<INSTALL_DIR>/agent.x86_64.iso .` to the workstation. On each
XCC: Remote Console → Media → mount the ISO → one-time boot from virtual CD → power cycle. Boot the
rendezvous node first (its console shows progress for all three); the others retry until it is up.

**VERIFY** — Each console shows the agent console, then a login prompt with the node's hostname.

**FAILS IF** — Agent console asks for network configuration ← no `hosts[]` MAC matched; fix C3, re-run Lab 08, re-boot.

### 10.2 Wait for install-complete

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `openshift-install agent wait-for` follows bootstrap then install (60–90 min) and writes
`${INSTALL_DIR}/auth/kubeconfig`. Script 05b then asserts the outcome instead of trusting an exit code:
3 Ready nodes, and on each `bond0` exactly 4 members, all `MII Status: up` (AT-07). A bond that
formed on fewer ports installs fine and loses redundancy silently — hence the explicit count.
*Consumed by:* Labs 11–16.

**EDIT** — None.

**DO** — `./scripts/05b-wait-install.sh`

**VERIFY** — Last line `PASS: install complete; 3 nodes Ready; every bond0 has 4 members up`.

**FAILS IF** — "waiting for hosts" never advances ← MAC typo or a non-bond NIC in C3;
bootstrap stalls on image pulls ← registry name not resolving (Lab 07) or mirror incomplete (Lab 06 step 6.8);
`bond0 has 2 members` ← port-channel or cabling (Lab 05 step 5.5).

### 10.3 Prove root disk and time source

**WHERE** — Bastion, `installer`

**WHY** — Neither a wrong root disk nor a free-running clock stops the install, so both are checked:
`rootDeviceHints` must have put RHCOS on the RAID1 virtual disk, and `additionalNTPSources` must have
pointed chrony at your source.

**EDIT** — None.

**DO**

```bash
set -a && source .env && set +a
export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
oc debug "node/${MW01_HOSTNAME}" --quiet -- chroot /host sh -c \
  "readlink -f ${MW01_ROOT_DEVICE}; findmnt -no SOURCE /sysroot; chronyc -n sources"
```

**VERIFY** — The `readlink` device is the parent of the `/sysroot` source (e.g. `/dev/sda`, `/dev/sda4`);
one `^*` line names `TIME_SOURCE` (or `BASTION_IP` when orphan). Repeat for `mw02`, `mw03`.

**FAILS IF** — No `^*` line ← node cannot reach UDP 123 on the source; skew will break etcd.

## Next

→ [11 — Configuring `oc` for Remote Access](11-oc-remote-access.md)
