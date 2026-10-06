# Deployment Tracks

> **Non-normative reference (ADR-01).** Background kept from v1. The normative path is
> [the labs](../labs/README.md), which implement Track A; where this page and a lab disagree, the lab wins.

Choose one track before starting. **Track A** is the default for Lenovo greenfield delivery and
is what the labs build.

---

## Track A - Greenfield bare metal (primary)

**Use when:** customer rack, CoE, enterprise demo, production-aligned PoC.

| Layer | Technology |
|---|---|
| Cluster nodes | Three physical servers (Lenovo ThinkSystem), compact: schedulable control-plane nodes |
| Network | Two switches, MLAG/vPC, one LACP port-channel per node (`bond0`, four members) |
| Storage | Local RAID1 (OS); VM disks per ADR-05 (Lenovo DM via Trident; hostpath provisioner until attached; LVMS for DS) |
| Bastion | Physical RHEL 9 server (kickstart) — **not** a KVM VM |
| Staging | Separate connected RHEL 9 host on the low side; never joins the machine network |
| Installer | Red Hat Agent-based Installer + oc-mirror v2 |
| Virtualization | OpenShift Virtualization on the three nodes |

**Follow:** [the labs](../labs/README.md) in order.

**Avoid:** nested virtualization; single-switch wiring presented as HA; one laptop on both networks.

---

## Track B - Optional KVM practice lab

**Use when:** a partner engineer needs to practise `oc mirror` and the Agent ISO **before** hardware arrives.

| Layer | Technology |
|---|---|
| Hypervisor | RHEL or Fedora KVM host (learning only, unsupported) |
| Bastion | VM on KVM |
| Cluster | Compact VMs on KVM |

**Reference:** [appendix-optional-kvm-lab.md](greenfield/appendix-optional-kvm-lab.md)
**Upstream example:** [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab/tree/main/agent-based-install/disconnected-install-on-kvm-host)

**Do not** deliver Track B to a customer as the production architecture. After Track B, repeat
Track A on real hardware.

---

## Track C - Single-node bare metal

**Use when:** one server only, for software testing. Out of scope for v2.0; OpenShift Virtualization
on SNO is constrained and suits demos only.

---

## Track comparison

| | Track A | Track B | Track C |
|---|---|---|---|
| KVM | No | Yes | No |
| Nodes | 3 physical (compact) | 3 VMs | 1 physical |
| HA networking | 2 switches, LACP | libvirt bridges | none |
| Customer-ready | Yes (lab-grade storage until the DM array is attached, ADR-05) | No | No |
| Diagram set | 1 + 2 + 3 | Optional | 1 + 3 |
