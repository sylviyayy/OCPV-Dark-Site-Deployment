# 01 — Prerequisites and Assumptions

> **Grade:** planning. This lab decides what the rest of the run can honestly claim.

## Goal

Fix one OS per machine role, state the platform assumptions as checks you can run, and prepare
the low-side staging host.

## Assumptions

Each row names a command that can prove it wrong. "RHEL 9/10, Fedora or CentOS" is a range, not an
assumption: nothing can falsify it, so nothing protects you from the combination that breaks.

### Operating system per machine role

| Machine role | Pinned OS | Why | Tolerated (learning only) | Check |
|---|---|---|---|---|
| Staging host (low side) | RHEL 9.x, latest minor | Red Hat ships RHEL 9 builds of `oc`, `oc-mirror`, `openshift-install` | Fedora | `grep '^VERSION_ID="9\.' /etc/os-release` |
| Bastion (high side) | RHEL 9.x from the DVD by kickstart | Every package it needs is on the DVD; no network repo exists | — | same, plus `rpm -q dnsmasq chrony podman nmstate` |
| Registry host | RHEL 9.x; may be the bastion | One OS to patch; mirror-registry runs on RHEL + Podman | co-located on the bastion | `podman --version` |
| Nodes `mw01`–`mw03` | RHCOS matching `OCP_VERSION` | Laid down by the Agent ISO; never kickstarted or `dnf update`d | — | `oc get nodes -o wide` → `OS-IMAGE` |
| DNS/NTP VMs | RHEL 9 guest image, pinned by digest | cloud-init capable; same major as the bastion DVD that serves its packages | — | `cat /etc/redhat-release` in the VM |
| Admin workstation | any, with a browser and SSH | Reaches XCC consoles and the bastion only | — | — |

RHEL 10 stays **untested** until the 4.22 client and mirror-registry documentation list it.

### Platform

| Assumption | Value | Check |
|---|---|---|
| Topology | 3-node compact: `mw` = master + worker, compute replicas 0 | rendered `install-config.yaml` → `compute[0].replicas: 0` |
| Air gap | No route from the machine network to the internet, ever | `curl -m 5 https://quay.io` from the bastion fails |
| DHCP | None on the machine network; static nmstate only | — |
| Boot | Nodes: XCC virtual media + Agent ISO. Helpers: `mkksiso` DVD. No network boot. | — |
| BMC licence | XCC Advanced (or higher) on each server: remote console and virtual media need it | XCC → License shows the tier (verify your XCC2 tier) |
| Firmware | UEFI; AMD SVM enabled | `/dev/kvm` on all nodes (Lab 13) |
| Switching | Two switches, MLAG/vPC, one LACP port-channel per node | 4 members `MII Status: up` (Lab 10) |
| Node disks | 2× 960 GB SSD per node, RAID1, OS only | — |
| VM storage | Lenovo ThinkSystem **DM** array (NetApp ONTAP; DG works the same way) — model and specs TBC. Until it is attached: node-local hostpath provisioner | `oc get sc` |
| Bastion disk | ≥ 2.5× the mirror archive + 20 GB (archive, oc-mirror cache, DVD); add 1× archive if the registry runs on it | `df -h /` |
| Time | A reference clock (`TIME_SOURCE` = IP) or lab-grade orphan time | `chronyc tracking` |
| Entitlement | Pull secret; OpenShift + OpenShift Virtualization + guest RHEL subscriptions | — |

**The air gap is between machines, not moments.** Regulated sites forbid a device that touched the
internet from joining the enclave: like a customs checkpoint, the cargo crosses, the truck stays
outside. So there are two machines: a staging host that never joins the machine network, and a
bastion that never touches the internet (ADR-02).

**Out of scope for v2.0:** an unattended installer; enterprise DNS/AD integration; GPU Operator;
disconnected updates (OSUS); VMware migration (MTV).

## Steps

### 1.1 Confirm the staging host OS

**WHERE** — Staging host (low side), RHEL 9.x, your user, cwd `~`

**WHY** — Pins the OS the clients and `mkksiso` are built for. *If skipped:* a client or `mkksiso` fails in Lab 04 or 06.

**EDIT** — None.

**DO / VERIFY**

```bash
grep -q '^VERSION_ID="9\.' /etc/os-release && echo PASS || echo FAIL     # expect: PASS
```

**FAILS IF** — `FAIL` ← not RHEL 9; use a RHEL 9 VM or laptop for the low side.

### 1.2 Prepare the staging host

**WHERE** — Staging host (low side), RHEL 9.x, your user, cwd `~`

**WHY** — Installs the tools Labs 03–06 call, and gives your user the **whole** `/opt/ocp-mirror`
tree (scripts write there as you, not root). The pull secret authenticates oc-mirror to Red Hat;
the SSH key is how you reach the bastion and nodes. *Consumed by:* `validate-env` (F1–F3), Labs 04, 06.
*If skipped:* `Permission denied` in Lab 06, or `[FAIL] F1`/`F2` in Lab 03.

**EDIT** — None.

**DO**

```bash
sudo dnf install -y git vim-enhanced jq curl podman skopeo lorax pykickstart python3-pyyaml openssl
sudo mkdir -p /opt/ocp-mirror && sudo chown -R "$USER:$USER" /opt/ocp-mirror
install -m 600 ~/Downloads/pull-secret.txt /opt/ocp-mirror/pull-secret.json   # from console.redhat.com
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git ~/OCPV-Dark-Site-Deployment
```

**VERIFY**

```bash
test -O /opt/ocp-mirror && echo owned                          # expect: owned
jq -e '.auths | length > 0' /opt/ocp-mirror/pull-secret.json   # expect: true
```

**FAILS IF** — `jq: parse error` ← the pull secret was saved as HTML or truncated.

### 1.3 Gather what the labs cannot create

**WHERE** — Admin workstation

**WHY** — Each item is an external dependency. *If skipped:* the run stops at the first lab that needs it.

**EDIT** — None.

**DO** — Confirm you have: the RHEL 9.x DVD ISO; approved transfer media ≥ 2× the archive
(150–300 GB typical) formatted exFAT, ext4 or XFS (FAT32 cannot hold files > 4 GiB); XCC access
**and an XCC Advanced licence** on all three servers; subscriptions; and, for the storage array,
the storage team's contact for the SVM details in Lab 03 group G.

**VERIFY** — Every item is ticked on the Lab 03 sign-off.

**FAILS IF** — XCC remote console greyed out ← XCC Standard licence; upgrade before Lab 10.

## Next

→ [02 — Architecture Overview and Network Design](02-architecture-network-design.md)
