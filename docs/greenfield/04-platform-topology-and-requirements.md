# Platform Topology and Requirements (OpenShift Virtualization)

> **Prerequisite:** [03-network-and-storage-design.md](03-network-and-storage-design.md) signed off.  
> This chapter defines the **logical OpenShift + OCP-V platform** on top of working network/storage.

## Diagram placeholder

> **Add image:** `docs/diagrams/03-ocpv-platform-topology.png`  
> See [diagrams/README.md](../diagrams/README.md).

---

## Logical components

| Component | IP (example) | Role |
|---|---|---|
| Bastion | `10.10.0.5` | Installer, temp DNS/NTP, optional staging NIC |
| Mirror registry | `10.10.0.10` | oc-mirror target, cluster image pulls |
| API VIP | `10.10.0.100` | Kubernetes API |
| Ingress VIP | `10.10.0.101` | Routes, console |
| cp01–cp03 | `10.10.1.11–13` | Control plane |
| wk01–wk02 | `10.10.2.21–22` | Workers (host OCP-V / KVM) |
| DNS VM | `10.10.0.50` | Production DNS (post-install) |
| NTP VM | `10.10.0.51` | Production NTP (post-install) |

---

## OpenShift cluster requirements

| Requirement | Detail |
|---|---|
| Version | 4.22.x, `stable-4.22` |
| Installer | Agent-based |
| `rendezvousIP` | One control-plane IP (bootstrap assist node) |
| Pull secret | Cluster install only — not mirror-registry creds |
| Mirror integration | IDMS/ITMS from oc-mirror v2 `cluster-resources/` |
| Platform | `baremetal` with API/Ingress VIPs |

Software flow: [00-disconnected-install-task-flow.md](../00-disconnected-install-task-flow.md)

---

## OpenShift Virtualization requirements

| Requirement | Detail |
|---|---|
| Operator | `kubevirt-hyperconverged`, channel `stable` |
| Catalog | Mirrored `redhat-operator-index:v4.22` |
| Workers | `/dev/kvm` available (BIOS virt on) |
| Storage | CSI for VM disks — `lvms-operator` or partner SAN CSI for CoE |
| Networking | Default OVN for pods; Multus NAD for infra VMs on flat L2 |

Install: `scripts/06-deploy-cnv.sh`  
Reference ImageSet: `mirror/imageset-ocpv-coe.yaml`

---

## Node count guidance

| Topology | Nodes | Use case |
|---|---|---|
| Standard | 3 CP + 2 WK | Default CoE / demo |
| Compact | 3 combined | Minimum bare metal |
| SNO | 1 | Software test only |

---

## DNS/NTP on the platform (VMware-exit, row 1)

When DNS today serves only the vSphere estate, production DNS moves here after install:

| Phase | Service location |
|---|---|
| Install | Bastion (dnsmasq/chrony) — [05-bootstrap-services.md](05-bootstrap-services.md) |
| Production | VMs on OCP-V — [06-production-network-services.md](../06-production-network-services.md) |

---

## What fails if platform layer is rushed

| Skipped prerequisite | Platform symptom |
|---|---|
| Network diagram not done | Wrong nmstate → nodes never join |
| Storage not masked | PVCs pending, VM create fails |
| Mirror not loaded | Mass `ImagePullBackOff` |
| No temp DNS | Registry hostname unresolved |
| Workers without KVM | OCP-V CSV installs but VMs cannot start |

---

## Next steps (software)

1. [05-bootstrap-services.md](05-bootstrap-services.md)
2. [03-kickstart-procedure.md](../03-kickstart-procedure.md)
3. [04-offline-installer-guide.md](../04-offline-installer-guide.md)
