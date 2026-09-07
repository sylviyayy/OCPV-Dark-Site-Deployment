# Diagram Guide

Where to place diagrams in this repository, what each should show, and the **order** they are read.

---

## Principle: infrastructure before platform

```
Diagram 1 (physical)  →  Diagram 2 (network + storage)  →  Diagram 3 (OCP-V platform)
     cables/BMC              bonds/VLANs/LUNs                  cluster/VIPs/DNS VMs
```

**Do not** skip to Diagram 3 (OpenShift topology) until Diagram 2 is signed off by network and storage teams.

---

## Diagram inventory

| ID | Filename (suggested) | Embed in doc | Owner |
|---|---|---|---|
| **1** | `docs/diagrams/01-physical-topology.png` | [02-physical-cabling-and-bmc.md](greenfield/02-physical-cabling-and-bmc.md) | Hardware / rack team |
| **2** | `docs/diagrams/02-network-and-storage.png` | [03-network-and-storage-design.md](greenfield/03-network-and-storage-design.md) | Network + SAN teams |
| **3** | `docs/diagrams/03-ocpv-platform-topology.png` | [04-platform-topology-and-requirements.md](greenfield/04-platform-topology-and-requirements.md) | OpenShift architect |

Use PNG or SVG. Keep source files (draw.io, Visio) in `docs/diagrams/source/` if desired (optional, gitignored if large).

---

## Diagram 1 — Physical topology

**Place:** Top of `greenfield/02-physical-cabling-and-bmc.md`

**Must show:**

- 3–5 server nodes (front or rear port view)
- 2 switches (Switch A, Switch B)
- SAN or storage controllers
- Bastion / kickstart server
- BMC connections (dashed — out-of-band, separate from data plane)
- Cable labels: `NIC1-p1 → SwA Po1`, `NIC1-p2 → SwB Po1`, etc.

**Matches:** Your specialist’s hand-drawn rack diagram (nodes ↔ switches ↔ SAN).

---

## Diagram 2 — Network and storage (draw this before OCP-V platform)

**Place:** Top of `greenfield/03-network-and-storage-design.md`

**Must show:**

- Bond `bond0` (802.3ad) per node across two NICs / two switches
- Port-channel `Po1` on each switch
- VLAN IDs (or “flat L2” for lab)
- API VIP and Ingress VIP (floating — not on a single node)
- iSCSI: dual paths (HBA1/HBA2 or dual subnet) to SAN
- LUN masking concept (which IQN sees which LUN)
- Bastion and registry IPs on install VLAN
- **Exclude** OpenShift pod CIDRs and OVN — those belong in Diagram 3

**Why before platform:** `agent-config.yaml` nmstate and `rootDeviceHints` depend on bonds and LUNs defined here.

---

## Diagram 3 — OCP-V platform topology

**Place:** Top of `greenfield/04-platform-topology-and-requirements.md`

**Must show:**

- Cluster nodes (roles: CP / worker)
- Bastion (MVP DNS/NTP during install)
- Mirror registry
- API / Ingress VIPs
- Production DNS VM + NTP VM on OCP-V (post-install)
- Optional: guest VM network (Multus / flat L2 for infra VMs)
- Software flow arrow: `mirror → agent ISO → cluster → CNV → DNS/NTP VMs`

**Exclude:** Switch port numbers and fibre channel zoning — those stay in Diagram 2.

---

## How to add a diagram to a doc

```markdown
![Physical topology](diagrams/01-physical-topology.png)

*Figure 1 — Physical cabling. See [worksheet](01-information-gathering-worksheet.md) for MAC/IP fields.*
```

Path is relative from `docs/` when viewing on GitHub.

---

## Placeholder until diagrams exist

Until you commit images, each greenfield doc includes a **Diagram placeholder** box listing required elements. Replace the box with the image when ready.
