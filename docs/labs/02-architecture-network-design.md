# 02 — Architecture Overview and Network Design

## Goal

Understand the roles of jumpbox, registry, the three Lenovo nodes, VIPs, and the
two-stage DNS/NTP story before you fill the worksheet.

## WHERE

Documentation only — no cluster commands yet.

## WHY

OpenShift cannot fix wrong Port-Channels or missing DNS with YAML. Diagram and IP
plan come before Agent config.

## Mental model

```text
[Jumpbox + optional registry]     temp DNS/NTP, mirror, openshift-install
        |
   install VLAN / flat L2
        |
[cp01 SR665] [cp02 SR665] [cp03 SR675+L40S]
        |
   API VIP + Ingress VIP
        |
(after OCP-V) DNS VM + NTP VM on the cluster
```

## Read these (in order)

1. [Architecture overview](../01-architecture-overview.md)  
2. [Network design / IP plan](../02-network-design.md)  
3. [Network and storage design (greenfield)](../greenfield/03-network-and-storage-design.md)  
4. [Diagram placement](../diagrams/README.md) — draw **network + storage before** platform topology  

## Key design choices for this tutorial

| Topic | Choice | Why |
|---|---|---|
| Installer | Agent-based | No DHCP, no external LB, no bootstrap VM |
| Cluster size | 3-node compact | Matches 3 physical servers |
| Jumpbox boot | USB / KVM ISO | No PXE on empty network |
| Node boot | BMC virtual CD + Agent ISO | Same reason |
| DNS install phase | Jumpbox dnsmasq | Nothing else exists yet |
| DNS steady state | VM on OCP-V | Customer-owned platform services |

## VERIFY

You can explain in one minute:

- what the jumpbox does vs what `cp01`–`cp03` do  
- why API/Ingress VIPs are not a physical server  
- why bastion DNS is temporary  

## Next

→ [03 — Site Worksheet](03-worksheet.md)
