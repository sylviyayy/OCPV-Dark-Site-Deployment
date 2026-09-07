# Physical Cabling and BMC

## Diagram placeholder

> **Add image:** `docs/diagrams/01-physical-topology.png`  
> See [diagrams/README.md](../diagrams/README.md) for required elements.

Until the image exists, use your specialist rack diagram here: nodes ↔ dual switches ↔ SAN, plus bastion and BMC (dashed).

---

## WHERE: data center floor / rack rear

This chapter is about **physical ports and cables** — not IP addresses (those are in the next chapter).

---

## Server network cabling (per node)

**WHAT:** Each cluster node connects **four data ports** to **two switches** for HA.

```
Node rear:
  NIC1-port1 ──────► Switch A (member of Po1)
  NIC1-port2 ──────► Switch B (member of Po1)
  NIC2-port1 ──────► Switch A (member of Po2)
  NIC2-port2 ──────► Switch B (member of Po2)
  BMC-port   ──────► Management switch only (NOT data Po)
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

**WHAT:** RAID1 on two SSDs for RHCOS; present single virtual disk (e.g. `/dev/sda`).

**WHY:** Matches `rootDeviceHints.deviceName` in agent-config.

**FAILS IF:** Install targets USB key or wrong VD → node breaks on reboot.

---

## Physical checklist

- [ ] Worksheet complete ([01-information-gathering-worksheet.md](01-information-gathering-worksheet.md))
- [ ] All node data cables labeled and match worksheet
- [ ] BMC reachable on every node
- [ ] Virtual media test successful on one node
- [ ] Bastion on install VLAN
- [ ] SAN paths cabled (dual path)

**Next →** [03-network-and-storage-design.md](03-network-and-storage-design.md) (network + storage diagram)
