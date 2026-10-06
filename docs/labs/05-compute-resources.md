# 05 — Provisioning Compute Resources

> **Grade:** production-grade hardware pattern (dual switches, LACP, RAID1 OS disks). Storage for
> VMs stays lab-grade until data drives are added (ADR-05).

## Goal

Cable, configure firmware and RAID, and confirm the node identity fields (C3, C4) on the
three Lenovo servers, so the Agent ISO in Lab 10 finds exactly what `.env` describes.

## Reference bill of materials

| Role | Model | CPU | RAM | Disks | GPU | Networking |
|---|---|---|---|---|---|---|
| `mw01` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | 4-port 10GBase-T (OCP slot) + 2-port 10GBase-T (Slot 1) |
| `mw02` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | same |
| `mw03` | ThinkSystem **SR675 V3** | 2× EPYC 9334 32C | 768 GB | 2× 960 GB SSD | **8× L40S** | 4-port 10GBase-T (OCP slot) + 4-port 10GBase-T (Slot 21) |

### Bond members: one LACP port-channel per node, split across both switches

| `bond0` member | SR665 V3 | SR675 V3 | Switch |
|---|---|---|---|
| 1 | OCP port 1 | OCP port 1 | A |
| 2 | OCP port 2 | OCP port 2 | B |
| 3 | Slot 1 port 1 | Slot 21 port 1 | A |
| 4 | Slot 1 port 2 | Slot 21 port 2 | B |

Both switches present the four members as **one** port-channel through MLAG or vPC, so LACP
negotiates a single 802.3ad bundle. Spare ports stay unplugged or are documented in the checklist.

### Compact topology

Exactly three servers run a **compact** cluster: every node is a control-plane node and
schedulable for workloads. `install-config.yaml` sets compute replicas **0** (FR-A2); no worker
hosts exist. Put GPU-heavy VMs on `mw03` with node labels later. Adding dedicated workers is in
[Appendix A](appendix-a-adding-workers.md).

## Steps

### 5.1 RAID1 virtual disk for RHCOS

**WHERE** — Each server's XCC → Storage configuration (or UEFI setup)

**WHY** — RHCOS installs onto the device named by `rootDeviceHints`; one RAID1 virtual disk over
both SSDs survives a drive failure. Consumed by: `MWn_ROOT_DEVICE` (C4) → agent-config.
If skipped: RHCOS lands on one bare SSD, or on the wrong device.

**EDIT** — No edits in this step.

**DO** — Create one RAID1 virtual disk over the two 960 GB SSDs; initialise it.

**VERIFY** — XCC shows the virtual disk **Optimal**, size ≈ 894 GiB.

**FAILS IF** — Two separate disks are presented ← RAID not created; the root hint may pick either.

### 5.2 UEFI and virtualization

**WHERE** — Each server's XCC → UEFI settings

**WHY** — OpenShift Virtualization runs VMs with KVM, which needs AMD SVM; the Agent ISO is UEFI.
Consumed by: Lab 13 (`/dev/kvm` check). If skipped: the OpenShift Virtualization operator installs, but every VM fails to start.

**EDIT** — No edits in this step.

**DO** — Boot mode UEFI; Processors → SVM Mode **Enabled**; (IOMMU **Enabled** if GPU passthrough comes later).

**VERIFY** — Settings page shows UEFI and SVM Enabled after a save-and-reboot.

**FAILS IF** — `06-deploy-cnv.sh` exits with "/dev/kvm missing" ← SVM still off.

### 5.3 XCC address and virtual media

**WHERE** — Each server's XCC, from the admin workstation

**WHY** — Lab 10 boots the Agent ISO through XCC virtual media; an XCC you cannot reach is a node you cannot install.
Consumed by: `MWn_BMC_IP` (C5). If skipped: Lab 10 stops at its first step.

**EDIT** — `.env` → `MW01_BMC_IP` … `MW03_BMC_IP` if they differ from what you set in Lab 03.

**DO** — Set each XCC's static address; mount the RHEL 9 DVD ISO as virtual media once (used in 5.4).

**VERIFY**

```bash
for ip in "${MW01_BMC_IP}" "${MW02_BMC_IP}" "${MW03_BMC_IP}"; do
  timeout 3 bash -c "</dev/tcp/${ip}/443" && echo "reachable ${ip}" || echo "UNREACHABLE ${ip}"
done
# expect: reachable <ip> three times (a TCP connect to 443; no TLS trust involved)
```

**FAILS IF** — `UNREACHABLE` for an address ← the admin workstation cannot route to the BMC network.

### 5.4 Confirm NIC names, MACs and the root device on the hardware

**WHERE** — Each server, booted from the RHEL 9 DVD (XCC virtual media) → *Troubleshooting* →
*Rescue a Red Hat Enterprise Linux system* → *3) Skip to shell*

**WHY** — RHCOS 4.22 is RHEL 9-based, so the rescue shell names interfaces the way RHCOS will;
the Agent ISO matches each server by these MACs and binds `bond0` to these names. The
`/dev/disk/by-path` link is stable across boots, unlike `/dev/sdX`, which virtual media can shift.
Consumed by: agent-config → `hosts[n].interfaces[]`, bond0 ports, `rootDeviceHints` (C3, C4).
If skipped: a server matches no `hosts[]` entry and the install waits for 3 hosts forever (Lab 10).

**EDIT** — `.env` → `MWn_NICS` and `MWn_ROOT_DEVICE` for this node
from: the values you read from the XCC inventory in Lab 03
to:   the live values below, if they differ.

**DO**

```bash
ip -br link                         # names and MACs: pick the 4 cabled bond members
lsblk -d -o NAME,SIZE,MODEL         # find the ~894 GiB RAID1 virtual disk, e.g. sda
ls -l /dev/disk/by-path/ | grep -w sda   # replace sda with that NAME; copy the by-path link
```

**VERIFY** — Back on the staging host after editing `.env`:

```bash
./scripts/lib/validate-env.sh      # expect: validate-env: PASS
```

**FAILS IF** — The four names differ between SR665 V3 and SR675 V3 ← expected (Slot 1 vs Slot 21);
that is why C3 is per node and never assumed.

### 5.5 Cable and configure the port-channels

**WHERE** — Rack, then Switch A and Switch B (network team)

**WHY** — `bond0` runs LACP (802.3ad). A switch port that does not speak LACP is, depending on
switch defaults, suspended (no network) or left individual (no redundancy).
Consumed by: `bond0` in agent-config (FR-D4). If skipped: nodes boot the ISO and never reach the rendezvous node.

**EDIT** — No edits in this step.

**DO** — Cable per the bond-member table. Configure one port-channel per node across the MLAG/vPC
pair, LACP mode active, MTU equal to `MTU` (B4), untagged on the machine network. Example syntax:
[network/sample-switch-config/lacp-mlag-switch.conf.example](../../network/sample-switch-config/lacp-mlag-switch.conf.example).

**VERIFY** — After Lab 10 boots the nodes, each port-channel shows four bundled members on the
switches, and Lab 10 step 10.3 shows four `MII Status: up` members per node.

**FAILS IF** — All four members land on one switch ← no switch redundancy; the install still succeeds, which is why this is checked by hand.

## Next

→ [06 — Mirroring Images for a Disconnected Install](06-mirroring-images.md)
