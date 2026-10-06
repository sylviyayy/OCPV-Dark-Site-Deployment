# 01 — Prerequisites and Assumptions

> **Grade:** planning. Nothing here is lab- or production-grade yet; this lab decides which
> one the rest of the run can honestly claim.

## Goal

Lock scope before touching hardware: one supported OS per machine role, the platform
assumptions the labs depend on, and a prepared low-side staging host.

## Assumptions

Every row is **falsifiable**: it names a command whose output proves or disproves it.
A range such as "RHEL 9/10, Fedora or CentOS Stream" is not an assumption, because nothing you
run can falsify it, so nothing protects you from the combination that breaks.

### Operating system per machine role

| Machine role | Pinned OS | Why this OS | Tolerated (learning only) | Falsification check |
|---|---|---|---|---|
| Connected staging host (low side) | RHEL 9.x, latest minor, x86_64 | Red Hat publishes RHEL 9 builds of `oc`, `oc-mirror` and `openshift-install`; FIPS mode needs them | Fedora Workstation | `grep '^VERSION_ID="9\.' /etc/os-release` |
| Bastion (dark-site services host) | RHEL 9.x, installed from the RHEL 9 DVD by kickstart | dnsmasq, chrony, podman and nmstate all ship on the DVD's BaseOS/AppStream, so no network repo is needed | None for partner delivery | Same, plus `rpm -q dnsmasq chrony podman nmstate` |
| Mirror registry host | RHEL 9.x; may be the bastion in a lab | One OS to patch; mirror registry for Red Hat OpenShift runs on RHEL with Podman | Co-located on the bastion | `podman --version` |
| Cluster nodes | RHCOS matching `OCP_VERSION`, laid down by the Agent ISO | The installer owns this OS; it is never kickstarted or `dnf update`d | None | `oc get nodes -o wide` → `OS-IMAGE` column |
| Guest VMs (DNS, NTP) | RHEL 9 KVM guest image, pinned by digest | cloud-init capable; same major as the bastion, so the bastion's DVD repo serves its packages | — | `cat /etc/redhat-release` inside the VM |
| Admin workstation | Any OS with a browser and an SSH client | Only reaches XCC consoles and SSH | — | — |

RHEL 10 for the staging host or bastion is **untested**, not supported, until the 4.22 client
and mirror-registry documentation list it (verify on 4.22).

### Platform assumptions

| Assumption | Value | Falsification check |
|---|---|---|
| Topology | 3-node compact: control plane schedulable, zero dedicated workers | rendered `install-config.yaml` → `compute[0].replicas: 0` |
| Connectivity | No route from the machine network to the internet, at any time | `curl -m 5 https://quay.io` from the bastion fails |
| DHCP | None on the machine network; static nmstate only | No answer to `nmap --script broadcast-dhcp-discover` |
| Boot | Nodes: XCC virtual media + Agent ISO. Helpers: USB or virtual media with the kickstart embedded. No network boot. | — |
| Firmware | UEFI mode; AMD SVM enabled (IOMMU too if GPU passthrough comes later) | `/dev/kvm` exists on all three nodes (Lab 13) |
| Switching | Two switches with MLAG or vPC; one LACP 802.3ad port-channel per node | `/proc/net/bonding/bond0` lists 4 members, all `MII Status: up` (Lab 10) |
| Disks | 2× 960 GB SSD per node in RAID1 for RHCOS; no spare data disk | Drives the storage decision (ADR-05) |
| Time | A reference clock (`TIME_SOURCE` = IP) or explicitly lab-grade orphan time | `chronyc tracking` → `Reference ID` |
| VM storage | Node-local, ReadWriteOnce, no live migration | `oc get sc` |
| Entitlement | Valid pull secret; OpenShift and OpenShift Virtualization subscriptions; guest RHEL entitlement confirmed | — |
| Transfer media | Capacity ≥ 2× the mirror archive; checksums verified on the high side | `sha256sum -c SHA256SUMS` (Lab 06) |

### The air gap is between machines, not between moments

Most regulated dark sites (financial services, government) forbid a device that has touched
the internet from joining the enclave. Bytes cross through approved removable media with
checksums; devices do not. Think of a **customs checkpoint**: the cargo is inspected and
passes, the truck stays outside. So this tutorial uses **two machines**: a connected RHEL 9
**staging host** (low side) that never joins the machine network, and a permanent RHEL 9
**bastion** (high side) that never touches the internet (ADR-02).

### Out of scope for v2.0

A fully unattended installer; production storage (ODF or SAN CSI) beyond a documented
decision; enterprise DNS/AD integration (brownfield, see the
[appendix](../reference/greenfield/appendix-brownfield-contrast.md)); NVIDIA GPU Operator
enablement; disconnected updates via OpenShift Update Service; MTV migration.

## Steps

### 1.1 Confirm the staging host OS

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~`

**WHY** — The clients and the kickstart tooling (`mkksiso`) used later are RHEL 9 builds, so
this pins the one OS they are tested on. Consumed by: Labs 04 and 06.
If skipped: a client fails to start or `mkksiso` is missing at Lab 04 step 4.2.

**EDIT** — No edits in this step.

**DO**

```bash
cat /etc/os-release
```

**VERIFY**

```bash
grep -q '^VERSION_ID="9\.' /etc/os-release && echo PASS || echo FAIL
# expect: PASS
```

**FAILS IF** — `FAIL` ← the host runs another OS; use a RHEL 9 VM or laptop for the low side.

### 1.2 Prepare the staging host

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~`

**WHY** — Scripts 01 and `render-kickstart.sh` run as your user and write into `/opt/ocp-mirror`,
so the whole directory must be yours, not only the pull secret inside it (FR-B9). The pull
secret authenticates oc-mirror to Red Hat registries; the SSH key is how you reach the bastion
and the nodes. Consumed by: Lab 03 validation (fields F1–F3), Lab 04, Lab 06.
If skipped: `Permission denied` on the first `mkdir` in Lab 06, or `validate-env` rejects F1/F2 in Lab 03.

**EDIT** — No edits in this step.

**DO**

```bash
sudo dnf install -y git vim-enhanced jq curl podman skopeo lorax pykickstart python3-pyyaml openssl
sudo mkdir -p /opt/ocp-mirror
sudo chown -R "$USER:$USER" /opt/ocp-mirror
# Download the pull secret from https://console.redhat.com/openshift/install/pull-secret, then:
install -m 600 ~/Downloads/pull-secret.txt /opt/ocp-mirror/pull-secret.json
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git ~/OCPV-Dark-Site-Deployment
```

**VERIFY**

```bash
test -O /opt/ocp-mirror && echo owned || echo NOT-OWNED                 # expect: owned
jq -e '.auths | length > 0' /opt/ocp-mirror/pull-secret.json            # expect: true
test -f ~/.ssh/id_ed25519.pub && echo key-ok                             # expect: key-ok
```

**FAILS IF** — `jq: parse error` ← the pull secret was saved as HTML or truncated; download it again.

### 1.3 Gather what Lab 02–05 assume you have

**WHERE** — Admin workstation, any OS

**WHY** — Each item is a dependency the labs cannot create for you.
Consumed by: Lab 04 (DVD, media), Lab 05 (XCC access), Lab 06 (media capacity).
If skipped: the run stops at the first lab that needs the missing item.

**EDIT** — No edits in this step.

**DO** — Confirm you hold: the RHEL 9.x DVD ISO (`rhel-9.x-x86_64-dvd.iso`); approved removable
media of at least 2× the expected archive (often 150–300 GB, formatted exFAT, ext4 or XFS — FAT32's
4 GiB file limit breaks `mirror_*.tar`); XCC credentials and network access for all three servers;
subscriptions for OpenShift, OpenShift Virtualization and the guest RHEL images.

**VERIFY** — Every item above is ticked on the sign-off sheet in [Lab 03](03-checklist.md).

**FAILS IF** — Media too small or FAT32 ← the archive cannot be copied in Lab 06 step 6.3.

## Next

→ [02 — Architecture Overview and Network Design](02-architecture-network-design.md)
