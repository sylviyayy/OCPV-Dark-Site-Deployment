# Assumptions and Scope

> **Non-normative reference (ADR-01).** The single assumptions table — one pinned OS per machine
> role and the platform assumptions, each with a falsification check — is in
> [Lab 01 — Prerequisites and Assumptions](../../labs/01-prerequisites-assumptions.md).
> This page keeps only the scope narrative for partner conversations.

## Deployment type

Greenfield **cluster** (new rack, new network, new DNS), air-gapped, bare metal, OpenShift 4.22
(`stable-4.22`), Agent-based Installer, oc-mirror v2 with IDMS/ITMS, OpenShift Virtualization on a
**three-node compact** cluster (schedulable control-plane nodes, no dedicated workers).

## Out of scope

- VMware workload migration (MTV) or coexistence
- Existing enterprise DNS/AD integration (brownfield)
- Disconnected updates via OpenShift Update Service
- Production storage (ODF or SAN CSI) beyond a documented decision
- NVIDIA GPU Operator enablement
- A fully unattended installer
- KVM as the production platform (see the [optional KVM appendix](appendix-optional-kvm-lab.md), unsupported)

## The greenfield story (why this repo exists)

Qualify the customer first: [appendix — does this repo apply?](appendix-brownfield-contrast.md).
When DNS today serves only the vSphere estate, there is no DNS until you build it:

1. **Install phase:** DNS and NTP on the bastion (Lab 07).
2. **Steady state:** two DNS VMs and one NTP VM **on OpenShift Virtualization** (Lab 14), with the
   bastion kept as the secondary source for cold starts.

## What fails if the assumptions are violated

| Violation | What happens |
|---|---|
| Single switch | a switch failure isolates every node; document as lab-only |
| No bastion DNS/NTP | image pulls and etcd health fail |
| Bastion decommissioned after Lab 14 | a site-wide power loss cannot recover without manual DNS |
| Virtualized nodes (nested virtualization) | OpenShift Virtualization performance unusable; unsupported for a CoE |
| Mixed OpenShift versions in the mirror | operators stuck `Pending` |

## Next step

→ [Lab 03 — Site Checklist](../../labs/03-checklist.md) before any cabling.
