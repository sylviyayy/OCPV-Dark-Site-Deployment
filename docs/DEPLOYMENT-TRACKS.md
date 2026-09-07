# Deployment Tracks

Choose one track before starting. **Track A** is the default for Lenovo greenfield delivery.

---

## Track A — Greenfield bare metal (primary)

**Use when:** Customer rack, CoE, enterprise demo, production-aligned PoC.

| Layer | Technology |
|---|---|
| Cluster nodes | Physical servers (e.g. Lenovo ThinkSystem) |
| Network | Physical switches, bond + port-channel |
| Storage | Local RAID1 (OS) + SAN/iSCSI (data) |
| Bastion | Physical RHEL 9 server (kickstart) — **not** a KVM VM |
| Installer | Red Hat Agent-based Installer + oc-mirror v2 |
| Virtualization | OpenShift Virtualization on bare-metal workers |

**Follow:** [GREENFIELD-README.md](GREENFIELD-README.md) Parts 1–4 in order.

**Avoid:** Nested virtualization, single-switch “lab” wiring presented as HA.

---

## Track B — Optional KVM practice lab

**Use when:** Partner engineer needs to practice `oc mirror` and agent ISO **before** hardware arrives.

| Layer | Technology |
|---|---|
| Hypervisor | RHEL KVM host (lab only) |
| Bastion | VM on KVM |
| Cluster | SNO or compact VMs on KVM |

**Reference:** [appendix-optional-kvm-lab.md](greenfield/appendix-optional-kvm-lab.md)  
**Upstream example:** [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab/tree/main/agent-based-install/disconnected-install-on-kvm-host)

**Do not** deliver Track B to a customer as the production architecture.

After Track B success, repeat **Track A** on real hardware.

---

## Track C — Compact or SNO bare metal

**Use when:** Minimum hardware budget; still bare metal (no KVM).

| Topology | Nodes | OCP-V notes |
|---|---|---|
| **SNO** | 1 | OCP-V possible but constrained; CoE demos only |
| **Compact** | 3 (CP+worker combined) | Minimum for meaningful OCP-V lab |

Adjust `.env` and `agent-config.yaml` node count. Physical cabling and storage docs still apply.

---

## Track comparison

| | Track A | Track B | Track C |
|---|---|---|---|
| KVM | No | Yes | No |
| Min nodes | 5 (3 CP + 2 WK) | 1–3 VMs | 1–3 physical |
| HA networking | 2 switches, bonded | libvirt bridges | Same as A (scaled down) |
| Customer-ready | Yes | No | PoC only |
| Diagram set | 1 + 2 + 3 | Optional | 1 + 2 + 3 (simplified) |
