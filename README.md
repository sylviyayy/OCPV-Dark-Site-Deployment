# OCP-V Dark Site Deployment

Greenfield, bare-metal reference for deploying **OpenShift Virtualization (OCP-V)** in a **disconnected** (air-gapped) environment — written for hardware partners, system integrators, and CoE teams.

**New here?** Start with **[docs/GREENFIELD-README.md](docs/GREENFIELD-README.md)** (reading order, diagram placement, deployment tracks).

This repository covers the full lifecycle:

1. **Flat L2 network** — single network, no VLANs (yet)
2. **Sample network configuration** — IP plan, switch config, and VM networking
3. **Kickstart procedure** — bootstrap from an empty network with no DNS/NTP
4. **Offline installer workflow** — mirror registry, disconnected install, and CNV deployment
5. **MVP network services** — minimal DNS/NTP on a bastion to survive bootstrap
6. **Production network services** — DNS and NTP VMs hosted on OCP-V itself

## Scenario Assumptions

| Assumption | Detail |
|---|---|
| Network | Single flat L2 segment, no VLAN tagging |
| Internet | None during install; all artifacts mirrored locally |
| DNS | Not available until you stand up MVP services |
| NTP | Not available until you stand up MVP services |
| Installer | Disconnected (agent-based or IPI with local mirror) |
| Target | OpenShift **4.22** with OpenShift Virtualization (Agent-based Installer, oc-mirror v2) |

## Repository Layout

```
.
├── docs/                    # Step-by-step guides (read in order)
├── network/                 # IP plan, switch samples, DNS zone templates
├── kickstart/               # RHEL kickstart for bastion and mirror hosts
├── install-config/          # OpenShift install-config templates
├── scripts/                 # Automation scripts (numbered execution order)
├── manifests/
│   ├── mvp/                 # Lightweight DNS/NTP on bastion (pre-OCP)
│   └── production/          # Full DNS/NTP VMs on OCP-V (post-install)
└── .env.example             # Site-specific variables (copy to .env)
```

## Quick Start

### Phase 0 — Prepare on a connected staging machine

```bash
# Clone this repo
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment

# Copy and edit site variables
cp .env.example .env
vi .env

# Download OCP release + operator catalogs (requires internet + Red Hat subscription)
./scripts/01-mirror-preparation.sh --mirror-to-disk
```

### Phase 1 — Bootstrap the dark site (empty network)

Follow [docs/03-kickstart-procedure.md](docs/03-kickstart-procedure.md) to:

1. PXE/kickstart the **bastion host** (RHEL 9)
2. PXE/kickstart the **mirror registry host**
3. Copy mirrored artifacts from staging to the dark site (USB / portable NAS)

### Phase 2 — MVP network services (no DNS/NTP exists yet)

```bash
# On the bastion, after kickstart completes
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

This starts **dnsmasq** (DNS + DHCP optional) and **chronyd** (NTP server) so OpenShift nodes can resolve names and sync time during install.

See [docs/05-mvp-network-services.md](docs/05-mvp-network-services.md).

### Phase 3 — Install OpenShift (disconnected)

```bash
./scripts/03-generate-install-config.sh
./scripts/05-install-ocp-disconnected.sh
./scripts/06-deploy-cnv.sh
```

See [docs/04-offline-installer-guide.md](docs/04-offline-installer-guide.md).

### Phase 4 — Production DNS/NTP VMs on OCP-V

```bash
./scripts/07-deploy-dns-vm.sh
./scripts/08-deploy-ntp-vm.sh
```

See [docs/06-production-network-services.md](docs/06-production-network-services.md).

## Documentation Index

### Greenfield (start here)

| Doc | Description |
|---|---|
| [Greenfield guide](docs/GREENFIELD-README.md) | Reading order, tracks, **where diagrams go** |
| [Deployment tracks](docs/DEPLOYMENT-TRACKS.md) | Bare metal (A) vs optional KVM lab (B) |
| [Diagram guide](docs/diagrams/README.md) | Network + storage diagram **before** platform topology |
| [Assumptions](docs/greenfield/00-assumptions-and-scope.md) | Scope, minimums, HA baseline |
| [Worksheet](docs/greenfield/01-information-gathering-worksheet.md) | Mandatory gate before cabling |
| [Physical / BMC](docs/greenfield/02-physical-cabling-and-bmc.md) | Cables, RAID, virtual CD |
| [Network + storage](docs/greenfield/03-network-and-storage-design.md) | Bonds, Po, LUN masking (**Diagram 2**) |
| [Platform / OCP-V](docs/greenfield/04-platform-topology-and-requirements.md) | Cluster topology (**Diagram 3**) |

### Software install runbooks

| # | Document | Description |
|---|---|---|
| 0 | [Disconnected Task Flow](docs/00-disconnected-install-task-flow.md) | Red Hat 4.22 task checklist |
| 1 | [Architecture Overview](docs/01-architecture-overview.md) | High-level design and phase diagram |
| 2 | [Network Design](docs/02-network-design.md) | Flat L2, IP plan, VM networking |
| 3 | [Kickstart Procedure](docs/03-kickstart-procedure.md) | Bootstrap from empty network |
| 4 | [Offline Installer Guide](docs/04-offline-installer-guide.md) | Mirror registry + disconnected install |
| 5 | [MVP Network Services](docs/05-mvp-network-services.md) | Bastion DNS/NTP for bootstrap |
| 6 | [Production Network Services](docs/06-production-network-services.md) | DNS/NTP VMs on OCP-V |
| 7 | [Post-Install Validation](docs/07-post-install-validation.md) | Health checks and smoke tests |

## Prerequisites

- **Staging machine** (internet access): RHEL 9 or Fedora, `oc`, `podman`, `skopeo`, `jq`
- **Dark site hardware**: 3+ bare-metal or VM hosts for OCP, 1 bastion, 1 mirror registry
- **Storage**: Sufficient disk for OCP release mirror (~60–80 GB) and RHCOS images
- **OpenShift subscription**: Pull secret from [Red Hat OpenShift Cluster Manager](https://console.redhat.com/openshift/install/pull-secret)

## Customization

All site-specific values live in `.env`. Key variables:

| Variable | Example | Purpose |
|---|---|---|
| `CLUSTER_NAME` | `ocpv-lab` | OpenShift cluster name |
| `BASE_DOMAIN` | `ocp-v.local` | Base DNS domain |
| `NETWORK_CIDR` | `10.10.0.0/16` | Flat L2 network |
| `BASTION_IP` | `10.10.0.5` | Bastion / MVP DNS/NTP |
| `MIRROR_REGISTRY` | `10.10.0.10:5000` | Local container registry |
| `OCP_VERSION` | `4.22.2` | Target OpenShift z-stream (pin from Red Hat mirror) |
| `OCP_CHANNEL` | `stable-4.22` | Release channel for oc-mirror ImageSet |

## Support

This is a reference implementation. Validate against your Red Hat subscription entitlements and the [OpenShift disconnected install documentation](https://docs.openshift.com/container-platform/latest/installing/disconnected_install/index.html).

## Contributing

- [CHANGELOG.md](CHANGELOG.md) — all notable changes ([Keep a Changelog](https://keepachangelog.com/) format)
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to update the changelog and open PRs
- [docs/RELEASE.md](docs/RELEASE.md) — version tagging and release checklist

Every change that affects users should add bullets under `[Unreleased]` in `CHANGELOG.md`.

## License

MIT — see [LICENSE](LICENSE).
