# Information Gathering Worksheet

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../../labs/README.md); where this page and a lab disagree, the lab wins.

The `.env` field register in [Lab 03](../../labs/03-checklist.md) is normative and is what the scripts
validate. Use this page for the facts around it that the register does not hold (serials, switch
port-channel IDs, BMC credentials references, SAN details) and for the owner sign-off.

---

## Site metadata

| Field | Value |
|---|---|
| Customer / site name | |
| Partner engineer | |
| Target track | A (bare metal compact) |
| OCP version | 4.22.x |
| Cluster name | |
| Base domain | |

---

## Per-server inventory

Duplicate one block per node.

### Node: _______________

| Field | Value | Used in |
|---|---|---|
| Role | control-plane node (compact) | agent-config |
| Hostname (C1) | | DNS, agent-config |
| Serial / asset tag | | Support |
| BMC IP | | Virtual CD |
| BMC type | XCC / iDRAC / iLO | Appendix |
| BMC username | (vault ref) | |
| Bond member 1 name=MAC | | `MWn_NICS` (C3) |
| Bond member 2 name=MAC | | `MWn_NICS` (C3) |
| Bond member 3 name=MAC | | `MWn_NICS` (C3) |
| Bond member 4 name=MAC | | `MWn_NICS` (C3) |
| Bond name | bond0 | nmstate |
| Bond mode | 802.3ad | switch Po |
| Node IP / prefix | | nmstate |
| Gateway | | nmstate |
| DNS (install) | bastion IP | nmstate |
| OS disk by-path | /dev/disk/by-path/… | `MWn_ROOT_DEVICE` (C4) |
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
| DNS VM IPs (two, post-install) | |
| NTP VM IP (post-install) | |
| Time source (reference clock IP or orphan) | |
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

**All signed → proceed to** [Lab 04](../../labs/04-bastion.md) · background: [02-physical-cabling-and-bmc.md](02-physical-cabling-and-bmc.md)
