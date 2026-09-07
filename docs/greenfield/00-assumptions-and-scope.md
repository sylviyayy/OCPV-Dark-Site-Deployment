# Assumptions and Scope

## Deployment type

| Attribute | Value |
|---|---|
| **Field** | Greenfield (new rack, new network, new DNS story) |
| **Connectivity** | Disconnected (air-gapped) during install |
| **Platform** | Bare metal — **Track A** default |
| **OpenShift** | 4.22, channel `stable-4.22` |
| **Installer** | Agent-based Installer (Red Hat recommended for disconnected) |
| **Mirroring** | oc-mirror plugin v2, IDMS/ITMS |
| **Virtualization** | OpenShift Virtualization (`kubevirt-hyperconverged`) |

## Out of scope

- VMware migration or coexistence
- Existing enterprise DNS/AD integration (brownfield)
- OpenShift Update Service (OSUS) automation
- Multi-cluster fleet / ACM (optional mirror only)
- KVM hypervisor as production platform (see Track B appendix)

## Minimum hardware (Track A — HA-shaped CoE)

| Component | Minimum | Rationale |
|---|---|---|
| Control plane nodes | 3 | etcd quorum |
| Worker nodes | 2 | OCP-V workloads + KVM on workers |
| NICs per node | 2× dual-port (4 ports) | Bond across 2 switches |
| Switches | 2 | No single-switch HA |
| BMC per node | 1 dedicated port | Virtual CD for agent ISO |
| OS disks | 2× SSD, RAID1 per node | RHCOS rootfs survivability |
| SAN paths | 2 (multipath) | Storage I/O HA |
| Bastion | 1 physical server | Mirror + installer + temp DNS/NTP |
| Registry | 1 host (may co-locate with bastion in tiny labs) | Image pull during install |

## Software assumptions

- RHEL 9 on bastion/registry (kickstart)
- Red Hat subscription for pull secret and mirrored content
- Workers expose `/dev/kvm` (VT-x/AMD-V enabled in BIOS)
- No DHCP on install VLAN (static nmstate in `agent-config.yaml`)

## Greenfield DNS story (why this repo exists)

In brownfield, DNS often runs on VMware. In greenfield **there is no DNS until you build it**:

1. **Install phase:** temporary DNS/NTP on bastion
2. **Steady state:** DNS and NTP VMs **on OpenShift Virtualization**

See [05-bootstrap-services.md](05-bootstrap-services.md).

## What fails if assumptions are violated

| Violation | Failure mode |
|---|---|
| Single switch only | Switch failure = total outage (document as lab-only) |
| No temp DNS/NTP | Image pulls and etcd health fail |
| Wrong SAN masking | Wrong host sees LUN → data corruption risk |
| Nested virt only workers | OCP-V performance unusable / unsupported for CoE |
| Mixed OCP versions in mirror | Operators stuck in `Pending` |

## Next step

→ Complete [01-information-gathering-worksheet.md](01-information-gathering-worksheet.md) before any cabling.
