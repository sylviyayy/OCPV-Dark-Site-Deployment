# Platform Topology and Requirements (OpenShift Virtualization)

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../../labs/README.md); where this page and a lab disagree, the lab wins.

> **Prerequisite:** [03-network-and-storage-design.md](03-network-and-storage-design.md) signed off.
> This chapter describes the logical OpenShift + OCP-V platform on top of working network and storage.

## Diagram placeholder

> **Add image:** `docs/diagrams/03-ocpv-platform-topology.png`
> See [diagrams/README.md](../../diagrams/README.md). Until then, the Mermaid diagram in the
> [README](../../../README.md#cluster-details) shows the logical topology.

## Logical components (values from `.env.example`)

| Component | IP (example) | Role |
|---|---|---|
| Bastion | `10.10.0.5` | Installer; DNS, NTP and DVD repo for the life of the site |
| Mirror registry | `10.10.0.10:8443` | oc-mirror target, cluster image pulls |
| API VIP | `10.10.0.100` | Kubernetes API |
| Ingress VIP | `10.10.0.101` | Routes, console |
| `mw01`–`mw03` | `10.10.1.11`–`13` | Schedulable control-plane nodes (compact) |
| DNS VMs `dns-a`, `dns-b` | `10.10.0.50`, `10.10.0.52` | Production DNS (post-install), anti-affine |
| NTP VM `ntp` | `10.10.0.51` | Production NTP (post-install) |

## OpenShift cluster requirements

| Requirement | Detail |
|---|---|
| Version | 4.22.z, `stable-4.22` |
| Installer | Agent-based, compact: control plane 3, compute 0 |
| `rendezvousIP` | One control-plane IP |
| Pull secret | The **merged** auth file: Red Hat pull secret plus the mirror registry entry |
| Mirror integration | `imageDigestSources` at install; IDMS/ITMS/CatalogSource from oc-mirror v2 in Lab 12 |
| Platform | `baremetal` with API/Ingress VIPs |

## OpenShift Virtualization requirements

| Requirement | Detail |
|---|---|
| Operators | `kubevirt-hyperconverged` (stable), `kubernetes-nmstate-operator` (stable) |
| Catalog | Mirrored `redhat-operator-index:v4.22`; name read from oc-mirror output |
| Nodes | `/dev/kvm` on all three (AMD SVM on) |
| Storage | Default StorageClass: `ontap-nas` via Trident on the Lenovo DM array; hostpath provisioner until attached (lab-grade); LVMS for a DS array (ADR-05) |
| Networking | OVN pod network; OVN-K localnet `vmnet` on `br-ex` for service VMs (ADR-06) |

## Node count guidance

| Topology | Nodes | Use |
|---|---|---|
| **Compact** | 3 schedulable control-plane nodes | **This tutorial** |
| Compact + workers | 3 + N | Day-2 growth: [Appendix A](../../labs/appendix-a-adding-workers.md) |
| SNO | 1 | Software test only; out of scope |

## What fails if the platform layer is rushed

| Skipped prerequisite | Platform symptom |
|---|---|
| Network design not done | wrong nmstate → nodes never join |
| No default StorageClass | DataVolumes `Pending`; VMs never start |
| Mirror not loaded | mass `ImagePullBackOff` |
| No bastion DNS | registry hostname unresolved |
| SVM off | OpenShift Virtualization installs, VMs cannot start |

## Next steps

1. [05-bootstrap-services.md](05-bootstrap-services.md)
2. [Lab 04 — Setting up the Bastion](../../labs/04-bastion.md)
