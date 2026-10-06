# Bootstrap Services (DNS and NTP)

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [Lab 07](../../labs/07-mvp-dns-ntp.md) and [Lab 14](../../labs/14-production-dns-ntp.md);
> where this page and a lab disagree, the lab wins.

## The greenfield DNS problem

**Brownfield:** DNS may live in AD, Infoblox or on VMware.
**This repo:** DNS served only the vSphere estate, so you **rebuild** it on the new platform.
Qualify which case applies: [appendix — does this repo apply?](appendix-brownfield-contrast.md)

| Stage | WHERE | WHAT | WHEN |
|---|---|---|---|
| **Bootstrap** | Bastion | dnsmasq + chronyd (`TIME_SOURCE` or lab-grade orphan) | from Lab 07, **for the life of the site** |
| **Production** | OCP-V VMs `dns-a`, `dns-b`, `ntp` | BIND + chrony | from Lab 14 |

## Stage 1 — bastion

**WHY:** nodes must resolve `api.<cluster>.<domain>` and `registry.<domain>`, and etcd needs agreed time.
**FAILS IF:** skipped → the Agent install hangs at image pull or etcd health.
Background: [05-mvp-network-services.md](../05-mvp-network-services.md).

The [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab/tree/main/agent-based-install/disconnected-install-on-kvm-host)
guide uses BIND on the bastion; this repo uses dnsmasq on the bastion and BIND on the DNS VMs.

## Stage 2 — production on OCP-V

**WHY:** customer-owned DNS/NTP on the new platform — where VMware DNS "goes" in a VMware-exit greenfield story.
Background: [06-production-network-services.md](../06-production-network-services.md).

## Cut-over

1. Deploy both DNS VMs and the NTP VM; verify answers and time.
2. Set node resolvers through NMState (DNS VMs first, bastion last); roll out node chrony.
3. **Keep** dnsmasq and chronyd on the bastion as the secondary (ADR-07).

**FAILS IF:** the bastion services are stopped → after a site-wide power loss the nodes need DNS
and time before the VMs that serve them can start.
