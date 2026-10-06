# 02 — Architecture Overview and Network Design

> **Grade:** design. Each decision below is recorded with its reasoning in [docs/DECISIONS.md](../DECISIONS.md).

## Goal

Know every machine, network and service — and why it sits where it does — before filling the
register in Lab 03.

## Mental model

```text
 LOW SIDE (internet)               │ HIGH SIDE: machine network, no route out
                                   │
 Staging host ─► approved media ───┼─► Bastion (permanent): dnsmasq · chrony · DVD repo · openshift-install
 oc-mirror, mkksiso  + SHA256SUMS  │   Mirror registry  registry.<domain>:8443 (may be the bastion)
                                   │        │
                                   │   Switch A ══ MLAG/vPC ══ Switch B  ── Lenovo DM array (NFS, ONTAP)
                                   │        │  one LACP port-channel per node
                                   │   mw01 SR665 V3 · mw02 SR665 V3 · mw03 SR675 V3 (8× L40S)
                                   │   master + worker on each · API and Ingress VIPs float between them
                                   │        │
                                   │   VMs on localnet (br-ex): dns-a · dns-b · ntp
 XCC network ─ admin workstation: virtual media for the Agent ISO
```

## Key decisions

| Topic | Choice | Mechanism behind it | ADR |
|---|---|---|---|
| Source of truth | `docs/labs/` normative; `docs/reference/` background | three trees disagreed; one must win | 01 |
| Air gap | staging host and bastion are different machines | devices that touched the internet may not enter | 02 |
| Registry | `registry.<domain>:8443`, never by IP | its certificate names the host; an IP fails TLS | 03 |
| Boot | Agent ISO via XCC; helpers from a `mkksiso` DVD | network boot needs DHCP/TFTP the site does not have | 04 |
| Node names | `mw01`–`mw03` (master + worker) | compact: each node is control plane **and** workload host | — |
| VM storage | Lenovo DM (ONTAP) via Trident NFS; hostpath provisioner until it is attached | RWX volumes let VMs live-migrate during node drains | 05 |
| VM network | OVN-K localnet on `br-ex` | reuses the LACP bond, no extra cabling | 06 |
| DNS/NTP | bastion first; then two DNS VMs + one NTP VM, **bastion stays secondary** | after a power loss nodes need DNS and time before VMs can start | 07 |
| Install dir | `INSTALL_DIR` outside the repo | the installer writes kubeconfig and the pull secret beside its inputs | 08 |

A cluster whose only resolver lives inside it has locked the spare key inside the car. The bastion
is the key in your pocket.

## Steps

### 2.1 Read the design and test yourself

**WHERE** — Admin workstation, reading only

**WHY** — Network and storage are prerequisites of the platform; a wrong port-channel or storage
path cannot be fixed in YAML. *Consumed by:* every value you choose in Lab 03.

**EDIT** — None.

**DO** — Read [docs/DECISIONS.md](../DECISIONS.md); background: [network and storage design](../reference/greenfield/03-network-and-storage-design.md).

**VERIFY** — Answer without notes (expected answers in brackets):

1. Which machine ever touches the internet? [only the staging host]
2. Which machine runs `openshift-install`? [the bastion]
3. What answers DNS for the nodes after Lab 14? [`dns-a`, `dns-b`, then the bastion]
4. Why can VMs on the hostpath provisioner not live-migrate, but VMs on the DM array can? [node-local ReadWriteOnce vs shared ReadWriteMany NFS]

**FAILS IF** — You cannot answer 3 or 4 ← re-read ADR-05 and ADR-07.

## Next

→ [03 — Site Checklist](03-checklist.md)
