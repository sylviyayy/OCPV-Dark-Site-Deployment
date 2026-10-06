# OpenShift Virtualization In an Air-gapped Environment - Greenfield Deployment

This tutorial walks you through setting up a compact **OpenShift Virtualization** cluster on 3 bare metal nodes in a **disconnected (dark site)** environment. It assumes no prior DNS or NTP server, and no existing Operating System nor network set up on all 3 nodes.

This guide is not for someone looking for a fully automated black-box installer they never read. It is optimized for **learning** so you understand each task required to bootstrap the cluster, the mirror registry, and platform DNS/NTP.

> The results of this tutorial should not be viewed as production ready.
> Always validate against relevant Red Hat documentation and your site standards. 
> Have fun learning!

Scripts under `scripts/` are helpers. Every lab still tells you **where** you are,
**what** to edit (with `vim`), and **why** the step exists.

## Target Audience

Someone who wants to understand how a **greenfield, air-gapped** OpenShift Virtualization deployment fits together: cabling, switches, bastion, mirror registry, Agent-based install, and where DNS/NTP live before and after the cluster exists.

You should be comfortable with a terminal, commands like `vi` or `vim`, and have either a Fedora/RHEL laptop or access to server BMCs. 
You do **not** need prior OpenShift experience.

## Cluster Details

This tutorial guides you through bootstrapping an OpenShift **4.22** cluster on Lenovo hardware, using the **Agent-based Installer** and **oc-mirror v2**.

**Compact Bare Metal Cluster with Network Topology:**
<insert architecture diagram>

**OpenShift Virtualization Node Roles:**
<img width="1148" height="536" alt="image" src="https://github.com/user-attachments/assets/4feb2c86-dd5c-438f-b42c-e8da36d69d9f" />

**There are several ways to configure an OpenShift cluster for different environment demands, but for this particular lab we will be focusing on a compact cluster setup.**

<img width="816" height="520" alt="image" src="https://github.com/user-attachments/assets/46010051-4786-4a10-9039-21620c2fc69d" />

A minimum of 3 nodes is needed by the OpenShift control plane component [etcd](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/etcd/index#etcd-overview) to maintain [quorum](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html-single/etcd/index#etcd-performance).

### Reference Hardware

| Qty | Model | CPU | Memory | Local disks | Accelerators | NICs 
|---|---|---|---|---|---|---|
| 2 | **ThinkSystem SR665 V3** | 2× AMD EPYC 9334 (32C) | 256 GB | 2× 960 GB SSD | — | 1× 4-port 10GBase-T (OCP slot) + 1× 2-port 10GBase-T (Slot 1) |
| 1 | **ThinkSystem SR675 V3** | 2× AMD EPYC 9334 (32C) | 768 GB | 2× 960 GB SSD | **8× NVIDIA L40S** | 1× 4-port 10GBase-T (OCP slot) + 1× 4-port 10GBase-T (Slot 21) |

**Suggested roles for a 3-node compact cluster** (control plane + workers colocated):

| Hostname (example) | Hardware | Role |
|---|---|---|
| `mw01` | SR665 V3 | Master + worker |
| `mw02` | SR665 V3 | Master + worker |
| `mw03` | SR675 V3 | Master + worker (GPU / heavy VM workloads) |

Plus a **bastion**: Fedora laptop, RHEL 10 KVM VM, or a small physical RHEL host on the install VLAN — used for mirroring, `openshift-install`, and temporary DNS/NTP.

### Software / Component Versions

| Component | Version / Note |
|---|---|
| OpenShift Container Platform | **4.22** (`stable-4.22`, pin exact z-stream in `.env`) |
| OpenShift Virtualization | `kubevirt-hyperconverged` channel `stable` (from mirrored catalog) |
| Installer | Agent-based Installer (`openshift-install agent`) |
| Image mirroring | oc-mirror plugin **v2** |
| Mirror registry | mirror registry for Red Hat OpenShift (or lab registry) |
| Bastion OS | **RHEL 9/10**, **Fedora**, or CentOS Stream equivalent for learning |
| Cluster node OS | RHCOS (installed by the Agent ISO — you do not Kickstart RHCOS by hand) |
| Container runtime | **CRI-O** (OpenShift default; not containerd) |
| Cluster network | **OVN-Kubernetes** |
| etcd | Bundled with the OpenShift control plane (not installed manually) |

## Before You Go to the Dark Site

The USB drive is your only supply line. The agent ISO is the only artifact on a 24-hour clock, so you build it on site.

* [USB Transfer Kit](docs/USB-TRANSFER-KIT.md): which Hybrid Cloud Console downloads you need (and which you don't), why, and what else goes on the drive (RHEL DVD, and the mirror archive carrying RHCOS and the Virtualization operators).
* [Bastion Lifecycle](docs/BASTION-LIFECYCLE.md): USB → bastion as temporary DNS/NTP → install → permanent DNS/NTP with the bastion as secondary → bastion disconnected. Also shows exactly where the 24-hour windows start and end.

## Labs

This tutorial assumes **three** AMD64 Lenovo servers (above) plus a bastion, on the
same L2/L3 install network. Adjust hostnames and IPs in the checklist for your site.

* [Prerequisites and Assumptions](docs/labs/01-prerequisites-assumptions.md)
* [Architecture Overview and Network Design](docs/labs/02-architecture-network-design.md)
* [Site Checklist](docs/labs/03-checklist.md)
* [Setting up the Bastion](docs/labs/04-bastion.md)
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

**Boot methods:** RHEL USB / KVM ISO for the bastion and registry helper; **BMC virtual CD**
for OpenShift nodes. **PXE is not used** on the primary path.
