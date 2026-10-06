# 02 — Architecture Overview and Network Design

> **Grade:** design. The decisions below fix which files exist and what they contain; each
> one is recorded with its reasoning in [docs/DECISIONS.md](../DECISIONS.md).

## Goal

Understand every machine, network and service in the build — and why it sits where it sits —
before filling the field register in Lab 03.

## Mental model

```text
 LOW SIDE (internet)                 │ HIGH SIDE: machine network MACHINE_NETWORK_CIDR (no route out)
                                     │
 Staging host (RHEL 9) ──► approved ─┼──► Bastion (RHEL 9, permanent)
 oc-mirror mirror-to-disk   media +  │      dnsmasq · chrony · httpd (DVD repo) · openshift-install
 mkksiso bastion ISO       SHA256SUMS│    Mirror registry  registry.BASE_DOMAIN:8443 (may be the bastion)
                                     │          │
                                     │    Switch A ══ MLAG/vPC ══ Switch B   (one LACP Po per node)
                                     │          │
                                     │    cp01 (SR665 V3)   cp02 (SR665 V3)   cp03 (SR675 V3, 8× L40S)
                                     │    bond0 = 4 ports · schedulable control-plane nodes · API/Ingress VIPs
                                     │          │
                                     │    VMs on localnet (br-ex): dns-a · dns-b · ntp
 XCC (BMC) network ── admin workstation: virtual media for the Agent ISO
```

## Key design choices

| Topic | Choice | Why (mechanism) | Decision |
|---|---|---|---|
| Source of truth | `docs/labs/` is normative; older pages live in `docs/reference/` | Three trees disagreed on OS, node count, registry port and bastion form | ADR-01 |
| Low side vs high side | Two machines; media + `SHA256SUMS` carry the archive | A device that touched the internet may not join the enclave | ADR-02 |
| Registry endpoint | mirror registry for Red Hat OpenShift at `MIRROR_REGISTRY_HOSTNAME:8443`, never by IP | Its certificate names the host; an IP fails TLS verification | ADR-03 |
| Boot | Nodes: Agent ISO via XCC virtual media. Helpers: `mkksiso` DVD via USB or virtual media | Network boot needs DHCP and TFTP/HTTP services a greenfield dark site does not have | ADR-04 |
| Installer | Agent-based, compact (3 schedulable control-plane nodes, `compute.replicas: 0`) | No DHCP, no external load balancer, no bootstrap VM | — |
| Node network | `bond0` 802.3ad over 4 ports split across both switches | One switch or NIC failure must not isolate a node | — |
| VM storage | Hostpath provisioner on each node's RAID1 disk; LVMS once data drives exist | RAID1 consumes both SSDs; LVMS needs an empty disk per node | ADR-05 |
| VM network | OVN-Kubernetes localnet on `br-ex` (NMState bridge mapping) | Reuses the bond, no extra cabling | ADR-06 |
| DNS/NTP | Bastion during install; two DNS VMs + one NTP VM afterwards, **bastion stays secondary** | After a site-wide power loss the nodes need DNS and time before VMs that serve them can start | ADR-07 |
| Install directory | `INSTALL_DIR` outside the git tree | The installer writes kubeconfig and the pull secret beside its inputs | ADR-08 |

**Why the bastion is never decommissioned.** A cluster whose only resolver lives inside it has
locked the spare key inside the car: on a cold start, nodes need `registry.<domain>` and time
before the DNS and NTP VMs can start. The bastion is the key in your pocket.

## Steps

### 2.1 Read the reference design

**WHERE** — Admin workstation, any OS, reading only

**WHY** — Network and storage are prerequisites of the platform: OpenShift cannot fix a wrong
port-channel or a missing DNS record with YAML. Consumed by: Lab 03 (every IP and name you
choose), Lab 05 (cabling). If skipped: field values that look valid but collide (for example a
VIP inside DHCP space that does not exist yet) surface as a stalled install in Lab 10.

**EDIT** — No edits in this step.

**DO** — Read, in order: [docs/DECISIONS.md](../DECISIONS.md), then the background pages
[network and storage design](../reference/greenfield/03-network-and-storage-design.md) and
[diagram guide](../diagrams/README.md) (both non-normative).

**VERIFY** — Answer without notes; the expected answers are in brackets.

1. Which machine runs `openshift-install`? [the bastion]
2. Which machine ever touches the internet? [only the staging host]
3. Where do API and Ingress VIPs live? [floating addresses held by the nodes; not a server]
4. What answers DNS for the nodes after Lab 14? [dns-a, dns-b, then the bastion]
5. Why can the DNS VMs not live-migrate? [node-local ReadWriteOnce disks]

**FAILS IF** — You cannot answer 4 or 5 ← re-read ADR-05 and ADR-07 before Lab 03.

## Next

→ [03 — Site Checklist](03-checklist.md)
