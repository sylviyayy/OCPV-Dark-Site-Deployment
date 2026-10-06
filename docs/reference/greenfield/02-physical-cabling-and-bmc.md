# Physical Cabling and BMC

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../../labs/README.md); where this page and a lab disagree, the lab wins.

## Diagram placeholder

> **Add image:** `docs/diagrams/01-physical-topology.png`  
> See [diagrams/README.md](../../diagrams/README.md) for required elements.

Until the image exists, use your specialist rack diagram here: nodes ↔ dual switches ↔ SAN, plus bastion and BMC (dashed).

---

## WHERE: data center floor / rack rear

This chapter is about **physical ports and cables** — not IP addresses (those are in the next chapter).

---

## Server network cabling (per node)

**WHAT:** Each cluster node connects **four data ports** to **two switches** for HA.

```
Node rear (one LACP port-channel per node, spanning the MLAG/vPC pair):
  OCP-port1   ──────► Switch A  ┐
  OCP-port2   ──────► Switch B  │ Po<node>
  Slot-port1  ──────► Switch A  │ (802.3ad, 4 members)
  Slot-port2  ──────► Switch B  ┘
  XCC port    ──────► Management switch only (NOT the data port-channel)
```

**WHY:**

- One NIC or switch failure does not isolate the node.
- Bond `bond0` in OS spans these four ports (configured in next doc).

**FAILS IF:**

- All four ports land on one switch → no switch HA.
- BMC shares a data VLAN without segmentation → security and install risk.

---

## Storage cabling

**WHERE:** HBA ports or onboard iSCSI NICs on each node → SAN or storage VLAN.

**WHAT:** Dual paths (HBA1 and HBA2) to redundant SAN controllers or fabrics.

**WHY:** Multipath; single cable pull should not kill storage I/O.

**FAILS IF:** Only one path cabled → no redundancy; install may succeed but production is unsafe.

---

## Bastion / kickstart server

**WHERE:** One physical RHEL server on the install VLAN (not a KVM VM in Track A).

**WHAT:** Connect one NIC to the same install VLAN as cluster nodes.

**WHY:** Runs `openshift-install`, hosts temporary DNS/NTP, may hold USB-delivered mirror tarballs.

---

## BMC — out-of-band management

**WHERE:** Each node’s BMC (Lenovo XCC, Dell iDRAC, HPE iLO).

**WHAT:**

1. Set static BMC IP on management VLAN.
2. Verify virtual media / remote console works.
3. Document credentials in vault (not in git).

**WHY:** Agent-based install boots from `agent.x86_64.iso` mounted as **virtual CD** — no PXE required.

| Step | WHERE | Action |
|---|---|---|
| Generate ISO | Bastion | `openshift-install agent create image` |
| Mount ISO | Node N BMC | Virtual media → `agent.x86_64.iso` |
| Boot once | BMC boot menu | One-time boot from virtual CD |
| Repeat | Each node | Same ISO on all nodes |

**FAILS IF:** ISO not mounted → node boots old OS; agent never discovers cluster.

---

## RAID (local OS disk) — before first boot

**WHERE:** Server RAID controller (BIOS/UEFI or XCC storage config).

**WHAT:** RAID1 on two SSDs for RHCOS; present one virtual disk and record its `/dev/disk/by-path/…` link.

**WHY:** That stable path is `CPn_ROOT_DEVICE`, rendered into `rootDeviceHints.deviceName`; `/dev/sdX` letters can shift when virtual media is attached.

**FAILS IF:** Install targets USB key or wrong VD → node breaks on reboot.

---

## Physical checklist

- [ ] Field register signed ([Lab 03](../../labs/03-checklist.md))
- [ ] All node data cables labeled and match worksheet
- [ ] BMC reachable on every node
- [ ] Virtual media test successful on one node
- [ ] Bastion on install VLAN
- [ ] SAN paths cabled (dual path), only if SAN is in scope

**Next →** [03-network-and-storage-design.md](03-network-and-storage-design.md) (network + storage diagram)
