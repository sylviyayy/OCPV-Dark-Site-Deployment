# Greenfield Deployment Guide

**Start here** if you are a hardware partner, system integrator, or customer building a **new**
bare-metal OpenShift Virtualization environment from scratch (no VMware, no existing DNS).

This guide is separate from the **software install runbooks** (`03`–`07` in the parent folder).
Read the greenfield chapters **first** — they explain *where to cable, what to configure on switches
and SAN, and what information you must collect* before generating an agent ISO.

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
      <td> Idiot-proof checklist for greenfield OCP-V </td>
    </tr>
    <tr>
      <td><b> OpenShift newcomers </b></td>
      <td> Understand the end-to-end OpenShift deployment process, the <b><u> where </u></b> and <b><u> why </u></b>, not just commands </td>
    </tr>
  </tbody>
</table>

**Not in scope:** Brownfield VMware migration. See [appendix-brownfield-contrast.md](greenfield/appendix-brownfield-contrast.md).

---

## Deployment tracks

| Track | Description | KVM? |
|---|---|---|
| **[A — Bare metal](DEPLOYMENT-TRACKS.md#track-a-greenfield-bare-metal-primary)** | Production-shaped greenfield (default) | No |
| **[B — Partner practice lab](DEPLOYMENT-TRACKS.md#track-b-optional-kvm-practice-lab)** | Learn the software flow before the rack arrives | Optional |
| **[C — Compact / SNO bare metal](DEPLOYMENT-TRACKS.md#track-c-compact-or-sno-bare-metal)** | Minimum node count on physical servers | No |

Details: [DEPLOYMENT-TRACKS.md](DEPLOYMENT-TRACKS.md)

---

## Reading order (follow this sequence)

### Part 1 — Decide and document (before touching hardware)

| Step | Document | Diagram? |
|---|---|---|
| 1 | [Assumptions and scope](greenfield/00-assumptions-and-scope.md) | — |
| 2 | [Information gathering worksheet](greenfield/01-information-gathering-worksheet.md) | — |
| 3 | [Deployment tracks](DEPLOYMENT-TRACKS.md) | — |

> **Gate:** Do not proceed to Part 2 until the worksheet is 100% complete.

### Part 2 — Physical infrastructure (before OpenShift)

| Step | Document | Diagram? |
|---|---|---|
| 4 | [Physical cabling and BMC](greenfield/02-physical-cabling-and-bmc.md) | **Diagram 1** — Physical topology |
| 5 | **[Network and storage design](greenfield/03-network-and-storage-design.md)** | **Diagram 2** — Network + storage |
| 6 | [Bootstrap services (DNS/NTP)](greenfield/05-bootstrap-services.md) | — |

**Why network + storage come before platform topology:** OpenShift and OCP-V assume
working L2/L3 paths, bonded NICs, multipathed storage, and DNS/NTP **before** you define
cluster VIPs, node counts, or virtualization storage classes. Getting network/storage wrong
cannot be fixed by changing `install-config.yaml`.

Diagram placement guide: [diagrams/README.md](diagrams/README.md)

### Part 3 — OpenShift Virtualization platform (after network + storage)

| Step | Document | Diagram? |
|---|---|---|
| 7 | **[Platform topology and requirements](greenfield/04-platform-topology-and-requirements.md)** | **Diagram 3** — OCP-V logical topology |
| 8 | [Architecture overview](01-architecture-overview.md) | Uses Diagram 3 |
| 9 | [Network design (IP plan)](02-network-design.md) | Tables + templates |

### Part 4 — Disconnected install and OCP-V (software)

| Step | Document |
|---|---|
| 10 | [Disconnected task flow (Red Hat mapping)](00-disconnected-install-task-flow.md) |
| 11 | [Kickstart procedure](03-kickstart-procedure.md) |
| 12 | [Offline installer guide](04-offline-installer-guide.md) |
| 13 | [MVP network services](05-mvp-network-services.md) |
| 14 | [Production network services](06-production-network-services.md) |
| 15 | [Post-install validation](07-post-install-validation.md) |

Scripts: numbered `scripts/00`–`08` in repo root.

---

## Diagrams you should create

See [diagrams/README.md](diagrams/README.md) for filenames, content, and where each is embedded.

| # | Name | Place after doc | Shows |
|---|---|---|---|
| 1 | Physical topology | `02-physical-cabling-and-bmc.md` | Nodes, switches, BMC, cable labels |
| 2 | **Network + storage** | `03-network-and-storage-design.md` | Bonds, Po, VLANs, iSCSI, LUN masking |
| 3 | OCP-V platform | `04-platform-topology-and-requirements.md` | Bastion, registry, CP/workers, DNS/NTP VMs |

Your specialist’s hand-drawn rack diagram maps best to **Diagram 1 + 2** combined.

---

## Reference labs (optional)

- [KVM practice lab (eanylin/openshift-lab)](greenfield/appendix-optional-kvm-lab.md) — software-only rehearsal; not for customer delivery
- [Brownfield contrast](greenfield/appendix-brownfield-contrast.md) — why VMware DNS does not apply here

---

## Quick link to scripts

```bash
cp .env.example .env && vi .env
./scripts/01-mirror-preparation.sh --mirror-to-disk   # connected staging
./scripts/02-bootstrap-dns-ntp.sh                     # bastion (dark site)
./scripts/03-generate-install-config.sh
./scripts/05-install-ocp-disconnected.sh
./scripts/06-deploy-cnv.sh
```
