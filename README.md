# OpenShift Virtualization The Explicit Way

This tutorial walks you through setting up **OpenShift Virtualization** on bare metal
in a **disconnected (dark site)** environment the explicit way. This guide is not for
someone looking for a fully automated black-box installer they never read. It is
optimized for **learning**, which means taking the long route so you understand each
task required to bootstrap the cluster, the mirror registry, and platform DNS/NTP.

> The results of this tutorial should not be viewed as production ready without your
> own validation against Red Hat documentation and your site standards — but don't let
> that stop you from learning.

Scripts under `scripts/` are helpers. Every lab still tells you **where** you are,
**what** to edit (with `vim`), and **why** the step exists.

## Copyright

MIT License — see [LICENSE](LICENSE).

Lab structure inspired by
[Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

## Target Audience

Someone who wants to understand how a **greenfield, air-gapped** OpenShift
Virtualization deployment fits together: cabling, switches, bastion, mirror registry,
Agent-based install, and where DNS/NTP live before and after the cluster exists.

You should be comfortable with a terminal, `vim`, and either a Fedora/RHEL laptop or
access to server BMCs. You do **not** need prior OpenShift experience.

## Cluster Details

This tutorial guides you through bootstrapping an OpenShift **4.22** cluster suitable
for a Lenovo CoE / partner lab, using the **Agent-based Installer** and **oc-mirror v2**.

### Reference hardware (this CoE rack)

| Qty | Model | CPU | Memory | Local disks | Accelerators | NICs |
|---|---|---|---|---|---|---|
| 2 | **ThinkSystem SR665 V3** | 2× AMD EPYC 9334 (32C) | 256 GB | 2× 960 GB SSD | — | 1× 4-port 10GBase-T (OCP slot) + 1× 2-port 10GBase-T (Slot 1) |
| 1 | **ThinkSystem SR675 V3** | 2× AMD EPYC 9334 (32C) | 768 GB | 2× 960 GB SSD | **8× NVIDIA L40S** | 1× 4-port 10GBase-T (OCP slot) + 1× 4-port 10GBase-T (Slot 21) |

**Suggested roles for a 3-node compact cluster** (control plane + workers colocated):

| Hostname (example) | Hardware | Role |
|---|---|---|
| `cp01` | SR665 V3 | Control plane + worker |
| `cp02` | SR665 V3 | Control plane + worker |
| `cp03` | SR675 V3 | Control plane + worker (GPU / heavy VM workloads) |

Plus a **jumpbox** (bastion): Fedora laptop, RHEL 10 KVM VM, or a small physical RHEL host on the install VLAN — used for mirroring, `openshift-install`, and temporary DNS/NTP.

### Software / component versions

| Component | Version / note |
|---|---|
| OpenShift Container Platform | **4.22** (`stable-4.22`, pin exact z-stream in `.env`) |
| OpenShift Virtualization | `kubevirt-hyperconverged` channel `stable` (from mirrored catalog) |
| Installer | Agent-based Installer (`openshift-install agent`) |
| Image mirroring | oc-mirror plugin **v2** |
| Mirror registry | mirror registry for Red Hat OpenShift (or lab registry) |
| Jumpbox OS | **RHEL 9/10**, **Fedora**, or CentOS Stream equivalent for learning |
| Cluster node OS | RHCOS (installed by the Agent ISO — you do not Kickstart RHCOS by hand) |
| Container runtime | **CRI-O** (OpenShift default; not containerd) |
| Cluster network | **OVN-Kubernetes** |
| etcd | Bundled with the OpenShift control plane (not installed manually) |

> Unlike Kubernetes The Hard Way, you do **not** hand-install etcd, kube-apiserver, or
> containerd. The Agent-based Installer and RHCOS do that. Labs still explain *what*
> those pieces are so you know what you are booting.

## Labs

This tutorial assumes **three** AMD64 Lenovo servers (above) plus a jumpbox, on the
same L2/L3 install network. Adjust hostnames and IPs in the worksheet for your site.

* [Prerequisites and Assumptions](docs/labs/01-prerequisites-assumptions.md)
* [Architecture Overview and Network Design](docs/labs/02-architecture-network-design.md)
* [Site Worksheet (mandatory)](docs/labs/03-worksheet.md)
* [Setting up the Jumpbox](docs/labs/04-jumpbox.md)
* [Provisioning Compute Resources](docs/labs/05-compute-resources.md)
* [Mirroring Images for a Disconnected Install](docs/labs/06-mirroring-images.md)
* [Bootstrapping MVP DNS and NTP](docs/labs/07-mvp-dns-ntp.md)
* [Generating Install and Agent Configuration](docs/labs/08-install-agent-config.md)
* [Certificates, Encryption, and etcd (what OpenShift creates for you)](docs/labs/09-certificates-etcd.md)
* [Bootstrapping the Cluster with the Agent-based Installer](docs/labs/10-bootstrap-cluster.md)
* [Configuring `oc` for Remote Access](docs/labs/11-oc-remote-access.md)
* [Integrating the Mirror Registry and OperatorHub](docs/labs/12-mirror-operatorhub.md)
* [Installing OpenShift Virtualization](docs/labs/13-openshift-virtualization.md)
* [Production DNS and NTP on OCP-V](docs/labs/14-production-dns-ntp.md)
* [Smoke Test](docs/labs/15-smoke-test.md)
* [Cleaning Up](docs/labs/16-cleanup.md)

### Partner appendices (optional)

* [Does this repo apply to my customer?](docs/greenfield/appendix-brownfield-contrast.md)
* [Optional KVM practice lab](docs/greenfield/appendix-optional-kvm-lab.md)
* [Diagram placement guide](docs/diagrams/README.md)
* [Greenfield partner reading order](docs/GREENFIELD-README.md)

## Conventions

```text
WHERE:    which machine you type on
WHY:      why this step exists
DO:       exact commands (use vim, not vi)
VERIFY:   how you know it worked
FAILS IF: what breaks if you skip or get it wrong
```

**Boot methods:** RHEL USB / KVM ISO for the jumpbox and registry helper; **BMC virtual CD**
for OpenShift nodes. **PXE is not used** on the primary path.
