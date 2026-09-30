# 05 — Provisioning Compute Resources

## Goal

Cable, RAID, BMC, and role-assign the three Lenovo servers so they are ready for the
Agent discovery ISO.

## WHERE

Datacenter rack + Lenovo XCC (BMC) for each server. Network/SAN teams for Po and LUNs.

## WHY

This is the Hard Way “provision compute” lab. On bare metal it means **hardware and
cabling**, not `virsh define`. Wrong NIC→switch mapping breaks LACP before OpenShift starts.

## Reference bill of materials

### Servers

| Role (suggested) | Model | CPU | RAM | Disks | GPU | Networking hardware |
|---|---|---|---|---|---|---|
| `cp01` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | 4-port 10GBase-T (OCP) + 2-port 10GBase-T (Slot 1) |
| `cp02` | ThinkSystem **SR665 V3** | 2× EPYC 9334 32C | 256 GB | 2× 960 GB SSD | — | same |
| `cp03` | ThinkSystem **SR675 V3** | 2× EPYC 9334 32C | 768 GB | 2× 960 GB SSD | **8× L40S** | 4-port 10GBase-T (OCP) + 4-port 10GBase-T (Slot 21) |

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

Spare ports: BMC/management, storage VLAN, or future workload networks — **document in the worksheet**; do not leave mystery cables.

**WHY 2 switches:** One switch failure must not isolate a node.  
**FAILS IF** all bond members land on one switch → no switch HA.

## DO — per server (XCC / UEFI)

1. **RAID1** on the two 960 GB SSDs for RHCOS; note the virtual disk name (often `/dev/sda`)  
2. Enable **virtualization** (AMD-V / SVM) — required for OCP-V / KVM on RHCOS  
3. On SR675: confirm GPUs visible in XCC (driver/operator work comes after cluster install)  
4. Set **BMC static IP** on management network; test virtual media  
5. Record **MAC addresses** of every port you will use in `bond0` (Lab 03)  
6. Cable to switches per worksheet (MLAG / Po IDs)  
7. If using SAN: dual paths + LUN masking only to these three IQNs/WWNs  

Physical detail: [greenfield/02-physical-cabling-and-bmc.md](../greenfield/02-physical-cabling-and-bmc.md)

## Compact cluster topology

With exactly three servers, run a **compact** cluster: each node is control plane **and**
schedulable for workloads. Put GPU-heavy VMs on `cp03` (SR675) using node labels/taints later.

Update `.env` for three nodes (remove or ignore WK01/WK02 if unused, or map workers onto the same three hosts in `agent-config` with `master` role and appropriate replicas). For Agent compact installs, set control plane replicas to 3 and worker replicas to 0 (or follow Red Hat compact cluster guidance for your exact 4.22 z-stream).

## VERIFY

- [ ] All three servers power on; XCC reachable  
- [ ] RAID1 VD healthy  
- [ ] Virtual media test: mount any ISO once on one node  
- [ ] Cable labels match worksheet Po / MLAG  
- [ ] MACs recorded for bond members  

## Next

→ [06 — Mirroring Images for a Disconnected Install](06-mirroring-images.md)
