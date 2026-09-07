# Information Gathering Worksheet

> **STOP:** Do not cable, switch-configure, or generate an agent ISO until every required field below is filled.

Copy this file or export `network/site-inventory.csv` (create from template) for each deployment.

---

## Site metadata

| Field | Value |
|---|---|
| Customer / site name | |
| Partner engineer | |
| Target track | A / B / C |
| OCP version | 4.22.x |
| Cluster name | |
| Base domain | |

---

## Per-server inventory

Duplicate one block per node.

### Node: _______________

| Field | Value | Used in |
|---|---|---|
| Role | master / worker | agent-config |
| Hostname | | DNS, agent-config |
| Serial / asset tag | | Support |
| BMC IP | | Virtual CD |
| BMC type | XCC / iDRAC / iLO | Appendix |
| BMC username | (vault ref) | |
| NIC1 port1 MAC | | agent-config |
| NIC1 port2 MAC | | bond slave |
| NIC2 port1 MAC | | bond slave |
| NIC2 port2 MAC | | bond slave |
| Bond name | bond0 | nmstate |
| Bond mode | 802.3ad | switch Po |
| Node IP / prefix | | nmstate |
| Gateway | | nmstate |
| DNS (install) | bastion IP | nmstate |
| OS disk device | /dev/sda | rootDeviceHints |
| iSCSI IQN | | LUN masking |
| Assigned LUN IDs | | SAN |

---

## Network team worksheet

| Field | Value |
|---|---|
| Machine network VLAN | or “flat L2” |
| BMC VLAN | |
| Storage VLAN (iSCSI) | |
| Switch A port-channel ID | |
| Switch B port-channel ID | |
| API VIP | |
| Ingress VIP | |
| Bastion IP | |
| Registry IP | |
| DNS VM IP (post-install) | |
| NTP VM IP (post-install) | |
| MTU | |

---

## SAN team worksheet

| Field | Value |
|---|---|
| Protocol | iSCSI / FC |
| Target portal(s) | |
| LUN name / ID (OCP data) | |
| Size | |
| Masking group (node IQNs) | |
| CHAP (if used) | (vault ref) |

---

## Cluster install

| Field | Value |
|---|---|
| rendezvousIP | (= one control-plane IP) |
| Pull secret path | (never commit) |
| SSH public key path | |
| Mirror registry hostname | |
| Mirror registry CA path | |

---

## Sign-off

| Role | Name | Date | Signature |
|---|---|---|---|
| Hardware / rack | | | |
| Network | | | |
| Storage | | | |
| OpenShift lead | | | |

**All signed → proceed to** [02-physical-cabling-and-bmc.md](02-physical-cabling-and-bmc.md)
