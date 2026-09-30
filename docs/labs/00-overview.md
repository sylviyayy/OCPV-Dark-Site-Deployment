# 00 — Overview and Mental Model

## Goal

Understand the whole story before typing anything.

## WHY this lab exists

OpenShift installs fail most often because people jump to `openshift-install`
without knowing *which machine does what*. This lab names every role.

## The cast of machines

| Role | What it is | Example IP | Needs internet? |
|---|---|---|---|
| **Staging** | Fedora laptop or RHEL 10 KVM VM | any | **Yes** (for download/mirror) |
| **Bastion** | RHEL helper on the install VLAN | `10.10.0.5` | No (after USB arrives) |
| **Registry** | Local image registry | `10.10.0.10` | No |
| **Control plane ×3** | OpenShift masters | `10.10.1.11–13` | No |
| **Workers ×2** | OpenShift + OCP-V hypervisors | `10.10.2.21–22` | No |

In a tiny lab you may put bastion + registry on **one** RHEL VM. On a Lenovo rack they are often two boxes.

## The story in one paragraph

1. On a machine **with internet**, download OpenShift images into a tarball (mirror).  
2. Carry that tarball into the dark site on USB.  
3. Install two helper RHEL machines with **USB + Kickstart** (bastion + registry).  
4. Start temporary DNS/NTP on the bastion (nothing else provides names or time yet).  
5. Build an **Agent discovery ISO** and boot every OpenShift node from it via **BMC** (not PXE).  
6. Install OpenShift Virtualization.  
7. Move DNS/NTP onto VMs running *on* the cluster; turn off bastion DNS/NTP.

## Why temporary DNS/NTP?

A greenfield site has no Infoblox / VMware DNS. OpenShift still needs:

- **DNS** — so nodes can resolve `api.<cluster>.<domain>` and the registry hostname  
- **NTP** — so etcd members agree on time (clock skew kills the control plane)

Bastion services are a **bootstrap bridge**, not the final design.

## What we deliberately do not use

| Method | Why not here |
|---|---|
| **PXE** | Needs DHCP/TFTP first — chicken-and-egg on an empty network |
| **External load balancer** | Agent-based bare metal uses API/Ingress VIPs instead |
| **Bootstrap VM (old IPI style)** | Agent-based installer embeds bootstrap in the ISO |
| **Internet during cluster install** | Images come from the local registry only |

## Next

→ [01 — Prerequisites](01-prerequisites.md)
