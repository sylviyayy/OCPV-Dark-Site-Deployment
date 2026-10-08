# 05 — Provisioning Compute Resources

## Goal

Cable, RAID, BMC, and role-assign the three Lenovo servers so they are ready for the
offline OVE agent media (`agent.ove.x86_64`, OpenShift **4.21.27**).

## WHERE

Datacenter rack + Lenovo XCC (BMC) for each server. The same **lean team** owns switch Po
and LUN masking (no separate network/storage orgs in this workflow).

## WHY

This is the Hard Way “provision compute” lab. On bare metal it means **hardware and
cabling**, not `virsh define`. Wrong NIC→switch mapping breaks LACP before OpenShift starts.

## Reference bill of materials

### Servers

| Role (suggested) | Model | CPU | RAM | Disks | GPU | Networking hardware |
|---|---|---|---|---|---|---|
| `mw01` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | 4-port 10GBase-T (OCP) + 2-port 10GBase-T (Slot 1) = **6 ports** |
| `mw02` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | same (**6 ports**) |
| `mw03` | ThinkSystem **SR675 V3** | 2× EPYC 9334 32C | 768 GB | 2× 960 GB SSD | **8× L40S** | 4-port 10GBase-T (OCP) + 4-port 10GBase-T (Slot 21) = **8 ports** |

### NIC layout (as installed)

**SR665 V3 (each):**

| Adapter | Slot | Ports |
|---|---|---|
| 4-port 10GBase-T | **OCP slot** | 4× 10GbE |
| 2-port 10GBase-T | **Slot 1** | 2× 10GbE |

**SR675 V3:**

| Adapter | Slot | Ports |
|---|---|---|
| 4-port 10GBase-T | **OCP slot** | 4× 10GbE |
| 4-port 10GBase-T | **Slot 21** | 4× 10GbE |

### Recommended bonding for HA (minimum practice)

Use **two switches** with LACP port-channels. Put bond members on **both** switches.

Example pattern for machine network `bond0` (adjust to your worksheet):

| Bond member | SR665 | SR675 | Switch side |
|---|---|---|---|
| Slave 1 | OCP port 1 | OCP port 1 | Switch A Po member |
| Slave 2 | OCP port 2 | OCP port 2 | Switch B Po member |
| Slave 3 | Slot1 port 1 | Slot21 port 1 | Switch A Po member |
| Slave 4 | Slot1 port 2 | Slot21 port 2 | Switch B Po member |

Spare ports (OCP 3–4, Slot21 3–4, etc.): BMC/management, storage, or future workload —
**record every MAC in the worksheet** even if uncabled. Do not leave mystery cables.

**WHY 2 switches:** One switch failure must not isolate a node.  
**FAILS IF** all bond members land on one switch → no switch HA.

## DO — per server (XCC / UEFI)

1. **RAID1** on the two 960 GB SSDs for RHCOS; note the virtual disk name (often `/dev/sda`)  
2. Enable **virtualization** (AMD-V / SVM) — required for OCP-V / KVM on RHCOS  
3. On SR675: confirm GPUs visible in XCC (driver/operator work comes after cluster install)  
4. Set **BMC static IP** on management network; test virtual media with any small ISO first  
5. Record **MAC addresses of every data port** (6 or 8), not only bond members (Lab 03 worksheet)  
6. Cable to switches per worksheet (MLAG / Po IDs)  
7. If using SAN: dual paths + LUN masking only to these three IQNs/WWNs  

Physical detail: [greenfield/02-physical-cabling-and-bmc.md](../greenfield/02-physical-cabling-and-bmc.md)

## Compact cluster topology

With exactly three servers, run a **compact** cluster: each node is control plane **and**
schedulable for workloads. Put GPU-heavy VMs on `mw03` (SR675) using node labels/taints later.

Update `.env` for three nodes (ignore WK01/WK02). For compact installs, control plane
replicas = 3 and worker replicas = 0 (follow Red Hat compact guidance for **4.21.27**).

## VERIFY

- [ ] All three servers power on; XCC reachable  
- [ ] RAID1 VD healthy  
- [ ] Virtual media test: mount any ISO once on one node  
- [ ] Cable labels match worksheet Po / MLAG  
- [ ] MACs recorded for bond members  

## Next

→ [06 — Mirroring Images for a Disconnected Install](06-mirroring-images.md)
