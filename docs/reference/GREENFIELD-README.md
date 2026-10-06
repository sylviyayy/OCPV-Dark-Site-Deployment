# Greenfield Deployment Guide

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../labs/README.md); where this page and a lab disagree, the lab wins.

**Start here** if you are a hardware partner, system integrator, or customer building a
**new bare-metal OpenShift Virtualization cluster** — new install, nothing inherited into this
build. The customer may be exiting VMware; that does not exclude them.

The greenfield chapters explain *where to cable, what to configure on switches and SAN, and what
information you must collect* before generating an Agent ISO. The labs then build it.

---

## Who this is for

<table width="100%">
  <thead>
    <tr>
      <th width="50%"> Audience </th>
      <th width="50%"> Goal </th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><b> Lenovo / hardware partners </b></td>
      <td> Repeatable CoE and customer rack delivery </td>
    </tr>
    <tr>
      <td><b> System integrators </b></td>
      <td> Exact edits, deterministic outputs, a checklist to sign </td>
    </tr>
    <tr>
      <td><b> OpenShift newcomers </b></td>
      <td> Understand the end-to-end OpenShift deployment process, the <b><u> where </u></b> and <b><u> why </u></b>, not just commands </td>
    </tr>
  </tbody>
</table>

**Qualify your customer first:** [Does this repo apply?](greenfield/appendix-brownfield-contrast.md)
**Scope:** [assumptions and scope](greenfield/00-assumptions-and-scope.md)

---

## Deployment tracks

| Track | Description | KVM? |
|---|---|---|
| **[A — Bare metal](DEPLOYMENT-TRACKS.md#track-a---greenfield-bare-metal-primary)** | Compact three-node greenfield (default; what the labs build) | No |
| **[B — Partner practice lab](DEPLOYMENT-TRACKS.md#track-b---optional-kvm-practice-lab)** | Learn the software flow before the rack arrives (unsupported) | Optional |
| **[C — Single node](DEPLOYMENT-TRACKS.md#track-c---single-node-bare-metal)** | Software testing only; out of scope | No |

---

## Reading order

### Part 1 — Decide and document (before touching hardware)

| Step | Document |
|---|---|
| 1 | [Lab 01 — Prerequisites and Assumptions](../labs/01-prerequisites-assumptions.md) |
| 2 | [Lab 02 — Architecture](../labs/02-architecture-network-design.md) and [decisions](../DECISIONS.md) |
| 3 | [Lab 03 — Site Checklist](../labs/03-checklist.md) (+ [supplementary worksheet](greenfield/01-information-gathering-worksheet.md)) |

> **Gate:** do not proceed until `validate-env.sh` passes and every owner has signed.

### Part 2 — Physical infrastructure (before OpenShift)

| Step | Document | Diagram |
|---|---|---|
| 4 | [Physical cabling and BMC](greenfield/02-physical-cabling-and-bmc.md) | **Diagram 1** — physical topology |
| 5 | **[Network and storage design](greenfield/03-network-and-storage-design.md)** | **Diagram 2** — network + storage |
| 6 | [Bootstrap services (DNS/NTP)](greenfield/05-bootstrap-services.md) | — |

Network and storage come before platform topology because OpenShift and OCP-V assume working L2/L3
paths, bonded NICs and DNS/NTP **before** you define VIPs, node counts or StorageClasses; a wrong
port-channel cannot be fixed in `install-config.yaml`. Diagram guide: [diagrams/README.md](../diagrams/README.md).

### Part 3 — Platform (after network + storage)

| Step | Document |
|---|---|
| 7 | [Platform topology and requirements](greenfield/04-platform-topology-and-requirements.md) |
| 8 | [Architecture overview](01-architecture-overview.md) · [Network design](02-network-design.md) |

### Part 4 — Build it

| Step | Document |
|---|---|
| 9 | **[Labs 01–16](../labs/README.md)** |
| 10 | Background: [task flow](00-disconnected-install-task-flow.md) · [kickstart](03-kickstart-procedure.md) · [installer](04-offline-installer-guide.md) · [MVP services](05-mvp-network-services.md) · [production services](06-production-network-services.md) · [validation](07-post-install-validation.md) |

---

## Diagrams you should create

| # | Name | Place after doc | Shows |
|---|---|---|---|
| 1 | Physical topology | `greenfield/02-physical-cabling-and-bmc.md` | Nodes, switches, XCC, cable labels |
| 2 | **Network + storage** | `greenfield/03-network-and-storage-design.md` | Bonds, port-channels, VLANs, VIPs |
| 3 | OCP-V platform | `greenfield/04-platform-topology-and-requirements.md` | Bastion, registry, nodes, DNS/NTP VMs |

---

## Quick reference: scripts in lab order

```bash
cp .env.example .env && vim .env && ./scripts/lib/validate-env.sh   # Lab 03 (labs/detail/configure-site-env.md)
./scripts/render-kickstart.sh bastion                               # Lab 04, staging host
./scripts/01-mirror-preparation.sh --mirror-to-disk                 # Lab 06, staging host
sudo ./scripts/04b-serve-dvd-repo.sh                                # Lab 06, bastion
sudo ./scripts/04-mirror-ocp-images.sh install-registry             # Lab 06, registry host
./scripts/04-mirror-ocp-images.sh load                              # Lab 06, bastion
sudo ./scripts/02-bootstrap-dns-ntp.sh                              # Lab 07
./scripts/03-generate-install-config.sh                             # Lab 08
./scripts/05a-create-agent-iso.sh                                   # Lab 08
./scripts/05b-wait-install.sh                                       # Lab 10
./scripts/06-deploy-cnv.sh && ./scripts/06b-configure-storage.sh    # Lab 13
./scripts/07-deploy-dns-vm.sh && ./scripts/08-deploy-ntp-vm.sh      # Lab 14
./scripts/00-prerequisites-check.sh --post-install                  # Lab 15
```

Tutorial entry: [../../README.md](../../README.md)
