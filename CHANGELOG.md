# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

> **v2.0.0 (breaking).** `.env` schema v2 (`ENV_SCHEMA_VERSION=2`; v1 files are refused),
> install directory moved outside the repo (`INSTALL_DIR`), script 05 split into 05a/05b.
> Each bullet below names the PRD v2.0 requirement it implements (NFR-9).

### Added
- **FR-A1** — `scripts/lib/render.py` renders `install-config.yaml` and `agent-config.yaml` into `${INSTALL_DIR}` as data structures (host list, bond ports, PEM bundle); templates are YAML skeletons
- **FR-A3** — `scripts/lib/validate-env.sh` enforces the field-register Rule column before every script; `.env.example` is rejected with one message per offending key
- **FR-D1** — `imageDigestSources` rendered into `install-config.yaml` from oc-mirror's `idms-oc-mirror.yaml`
- **FR-D4** — per-node `bond0` (802.3ad, four members, `MTU`) in `agent-config.yaml` from `CPn_NICS`
- **FR-D6** — `additionalNTPSources` in `agent-config.yaml` (`TIME_SOURCE`, or the bastion when orphan)
- **FR-D7** — `scripts/05a-create-agent-iso.sh` (Lab 08, keeps `*.orig` inputs) and `scripts/05b-wait-install.sh` (Lab 10, asserts 3 Ready nodes and 4 bond members up)
- Hard Way–style repository front door in `README.md` with hyperlinked labs
- Lenovo CoE compute lab: 2× SR665 V3 + 1× SR675 V3 (L40S), NIC slot layout, compact 3-node roles
- Labs 01–16 remapped (jumpbox, compute, mirror, agent bootstrap, `oc` access, cleanup)
- Beginner lab series `docs/labs/` (Hard Way–style): USB/KVM path, `vim`, per-field `.env` guide, rationale every step
- Greenfield partner documentation (`docs/GREENFIELD-README.md`, `docs/greenfield/*`)
- Deployment tracks (bare metal primary, optional KVM lab appendix)
- Diagram placement guide — network + storage **before** OCP-V platform topology
- CoE ImageSet profile `mirror/imageset-ocpv-coe.yaml`
- Reference to [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab) for optional KVM practice only

### Changed
- **FR-A2** — compact topology end to end: `compute.replicas: 0`; worker hosts `wk01`/`wk02` removed from templates, scripts, IP plan, kickstarts and zone data
- **FR-A4** — `load_env` no longer falls back to `.env.example`, exports values with `set -a`, and refuses a v1 `.env`
- **FR-D2** — `pullSecret` is the merged `${AUTH_FILE}` (Red Hat pull secret plus mirror-registry entry); `install-config/README.md` (was `mirror-config.yaml.template`) reverses the old "not the mirror-registry credentials" note
- **FR-D5** — `rootDeviceHints.deviceName` comes from `CPn_ROOT_DEVICE` (`/dev/disk/by-path/…`), never `/dev/sda`
- **FR-D8** — `agent-config.yaml` `metadata.name` follows `CLUSTER_NAME`
- **FR-D9** — scripts 05a/05b no longer apply oc-mirror cluster-resources; Lab 12 is the single owner
- `.env.example` rewritten to the v2 field register (§1 order, IDs A1–F4, derived block validated); `NETWORK_CIDR` → `MACHINE_NETWORK_CIDR`, `DNS_VM_IP` → `DNS_VM_IPS`, `OC_MIRROR_WORKDIR` → derived `MIRROR_ARCHIVE_DIR`
- Prefer RHEL USB / KVM ISO attach over PXE for bastion/registry; document PXE as optional only
- Quick start examples use `vim` and point at explicit `.env` field list
- Rewrote brownfield appendix as customer qualification decision aid; fixed false MTV mirror claim
- Resolved GREENFIELD-README contradiction on VMware-exit DNS (function rebuild vs "does not apply")
- Replaced deprecated `oc adm release mirror` / ICSP workflow with **oc-mirror plugin v2** and IDMS/ITMS
- Aligned install flow with official Red Hat Agent-based Installer disconnected documentation
- Default mirror registry port changed to **443** (mirror registry for Red Hat OpenShift)
- Added `docs/00-disconnected-install-task-flow.md` with full enterprise task checklist
- Added `mirror/imageset-config.yaml.template` (`mirror.openshift.io/v2alpha1`)
- Updated CNV deployment to use mirrored `kubevirt-hyperconverged` from `redhat-operator-index:v4.22`
- Changelog policy, release workflow, and PR template for consistent change tracking

### Removed
- `scripts/05-install-ocp-disconnected.sh` (split into 05a/05b, FR-D7)
- `.env` keys `NETWORK_INTERFACE`, `NETWORK_NETMASK`, `CPn_MAC`, `WK01_*`, `WK02_*`, `DNS_SERVER`, `NTP_SERVER`, `OPERATOR_CATALOG`, `CNV_*`, `SSH_USER`, `INSTALL_USER`

### Fixed
- `scripts/lib/common.sh` resolved `REPO_ROOT` to `scripts/` (it read `BASH_SOURCE[0]` of itself), so every script exited 1 at `load_env` before doing any work (audit finding beyond the PRD)
- **FR-D3** — `additionalTrustBundle` is emitted as a literal block with every PEM line indented; the old `str.replace` produced YAML that failed to parse

### Security
- **FR-K1** — `.gitignore` covers rendered install files, `*.orig`, rendered kickstarts and `auth.json`; the inert `/opt/ocp-mirror/` line is gone
- **FR-K2** — `MIRROR_REGISTRY_PASSWORD` removed from `.env.example`; scripts prompt with `read -rs`

## [1.0.0] - 2026-09-07

### Added
- Complete dark site OCP-V deployment reference
- Architecture and network design documentation (`docs/01`–`07`)
- Kickstart procedures for bastion and mirror registry hosts
- Offline installer guide (agent-based, disconnected)
- MVP DNS/NTP bootstrap on bastion (dnsmasq + chronyd orphan mode)
- Production DNS VM (BIND9) and NTP VM (chrony) on OCP-V
- Numbered automation scripts (`scripts/00`–`08`)
- Install-config and agent-config templates
- Flat L2 switch configuration sample
- IP addressing plan and DNS zone templates
- Post-install validation checklist

[Unreleased]: https://github.com/sylviyayy/OCPV-Dark-Site-Deployment/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sylviyayy/OCPV-Dark-Site-Deployment/releases/tag/v1.0.0
