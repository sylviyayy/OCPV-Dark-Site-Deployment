# 05 — Provisioning Compute Resources

> **Grade:** production hardware pattern (two switches, LACP, RAID1 OS disks). VM storage is
> production-grade once the DM array is attached; until then it is node-local and lab-grade.

## Goal

Cable, configure firmware and RAID, and confirm node identity (C3, C4) on the three servers, so
the Agent ISO in Lab 10 finds exactly what `.env` describes. Connect the storage array.

## Bill of materials

| Host | Model | CPU | RAM | Disks | GPU | Networking |
|---|---|---|---|---|---|---|
| `mw01` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | 4-port 10GBase-T (OCP) + 2-port 10GBase-T (Slot 1) |
| `mw02` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | same |
| `mw03` | ThinkSystem **SR675 V3** | 2× EPYC 9334 32C | 768 GB | 2× 960 GB SSD | **8× L40S** | 4-port 10GBase-T (OCP) + 4-port 10GBase-T (Slot 21) |
| array | ThinkSystem **DM** series (model TBC; DG works the same way) | — | — | — | — | host ports to Switch A and B |

Compact topology: every node is a **master + worker** (hence `mw`), `install-config.yaml` sets
compute replicas 0. Put GPU-heavy VMs on `mw03` with node labels later; dedicated workers are
[Appendix A](appendix-a-adding-workers.md).

### Bond members: one LACP port-channel per node across both switches

| `bond0` member | SR665 V3 | SR675 V3 | Switch |
|---|---|---|---|
| 1 | OCP port 1 | OCP port 1 | A |
| 2 | OCP port 2 | OCP port 2 | B |
| 3 | Slot 1 port 1 | Slot 21 port 1 | A |
| 4 | Slot 1 port 2 | Slot 21 port 2 | B |

The MLAG/vPC pair presents the four ports as **one** port-channel, so LACP forms one 802.3ad bundle
and survives the loss of a NIC or a switch.

## Steps

### 5.1 RAID1 virtual disk for RHCOS

**WHERE** — Each server's XCC → Storage

**WHY** — RHCOS installs onto the device named by `rootDeviceHints`; one RAID1 virtual disk over
both SSDs survives a drive failure. *Consumed by:* C4. *If skipped:* RHCOS lands on one bare SSD.

**EDIT** — None.

**DO** — Create one RAID1 virtual disk over the two 960 GB SSDs; initialise it.

**VERIFY** — XCC shows the virtual disk **Optimal**, ≈ 894 GiB.

**FAILS IF** — Two disks presented ← RAID not created; the root hint may pick either.

### 5.2 UEFI and virtualization

**WHERE** — Each server's XCC → UEFI settings

**WHY** — VMs run on KVM, which needs AMD SVM; the Agent ISO boots in UEFI mode.
*If skipped:* OpenShift Virtualization installs but no VM starts (Lab 13 stops on `/dev/kvm`).

**EDIT** — None.

**DO** — Boot mode **UEFI**; Processors → SVM Mode **Enabled**.

**VERIFY** — Both settings shown after save and reboot.

**FAILS IF** — Script 06 exits "/dev/kvm missing" ← SVM still off.

### 5.3 XCC address and virtual media

**WHERE** — Each XCC, from the admin workstation

**WHY** — Lab 10 boots the Agent ISO through XCC virtual media; an unreachable XCC, or one without
the remote-presence licence, is a node you cannot install. *Consumed by:* C5.

**EDIT** — `.env` → `MW01_BMC_IP` … `MW03_BMC_IP` if they changed.

**DO** — Set each XCC's static address; open the remote console once and mount the RHEL 9 DVD (used in 5.4).

**VERIFY**

```bash
for ip in "${MW01_BMC_IP}" "${MW02_BMC_IP}" "${MW03_BMC_IP}"; do
  timeout 3 bash -c "</dev/tcp/${ip}/443" && echo "reachable ${ip}" || echo "UNREACHABLE ${ip}"
done     # expect: reachable ×3
```

**FAILS IF** — `UNREACHABLE` ← no route to the BMC network. Media menu greyed out ← XCC licence tier.

### 5.4 Confirm NIC names, MACs and the root device

**WHERE** — Each server booted from the RHEL 9 DVD (XCC virtual media) → *Troubleshooting* →
*Rescue a Red Hat Enterprise Linux system* → *3) Skip to shell*

**WHY** — RHCOS 4.22 is RHEL 9-based, so the rescue shell names interfaces as RHCOS will. The Agent
ISO matches each server by these MACs and builds `bond0` from these names; `/dev/disk/by-path` is
stable across boots, unlike `/dev/sdX`, which virtual media can shift. *Consumed by:* C3, C4.
*If skipped:* a server matches no host entry and the install waits forever (Lab 10).

**EDIT** — `.env` → `MWn_NICS`, `MWn_ROOT_DEVICE` — from the XCC-inventory values to the live values, if different.

**DO**

```bash
ip -br link                              # names + MACs: pick the 4 cabled bond members
lsblk -d -o NAME,SIZE,MODEL              # find the ~894 GiB RAID1 virtual disk, e.g. sda
ls -l /dev/disk/by-path/ | grep -w sda   # replace sda with that NAME; copy its by-path link
```

**VERIFY** — Back on the staging host: `./scripts/lib/validate-env.sh` → `PASS`.

**FAILS IF** — Names differ between SR665 V3 and SR675 V3 ← expected (Slot 1 vs Slot 21); that is why C3 is per node.

### 5.5 Cable the nodes and configure the port-channels

**WHERE** — Rack; Switch A and Switch B (network team)

**WHY** — `bond0` runs LACP. A switch port that does not speak LACP is suspended (no network) or
left individual (no redundancy), depending on switch defaults. *Consumed by:* `bond0` in agent-config.

**EDIT** — None.

**DO** — Cable per the bond table. One port-channel per node across the vPC pair, LACP **active**,
MTU = `MTU` (B4), machine network untagged. Example:
[lacp-mlag-switch.conf.example](../../network/sample-switch-config/lacp-mlag-switch.conf.example).

**VERIFY** — After Lab 10 boots the nodes: each port-channel shows four bundled members, and script
05b reports four `MII Status: up` members per node.

**FAILS IF** — All four members on one switch ← no switch redundancy; the install still succeeds, so check by hand.

### 5.6 Connect the storage array (when it arrives)

**WHERE** — Rack and switches (storage + network teams)

**WHY** — The DM array serves VM disks over NFS from an SVM data LIF; every node must reach that LIF
with the bandwidth and redundancy of the node bonds. *Consumed by:* group G, Lab 13 step 13.2.
*If skipped:* VMs stay on node-local hostpath storage (lab-grade).

**EDIT** — `.env` → G1–G4 and `STORAGE_BACKEND=ontap` once the storage team has created the SVM.

**DO** — Cable the array's host ports to both switches (at least one per controller per switch).
Have the storage team create an SVM with NFS enabled, a management LIF and an NFS data LIF on the
machine network (or a routed storage VLAN), and an SVM account with the `vsadmin` role.

**VERIFY** — From the bastion: `ping -c1 "${ONTAP_DATA_IP}"` → one reply; `./scripts/lib/validate-env.sh` → `PASS`.

**FAILS IF** — `[WARN] G2 … outside MACHINE_NETWORK_CIDR` ← nodes need a route or a storage VLAN interface to reach the LIF.

**If the array turns out to be a DS series:** it is block-only (iSCSI/FC/SAS) with no OpenShift CSI
driver. Present one LUN per node and set `STORAGE_BACKEND=lvms`; VMs then use ReadWriteOnce
volumes and cannot live-migrate (ADR-05).

## Next

→ [06 — Mirroring Images for a Disconnected Install](06-mirroring-images.md)
