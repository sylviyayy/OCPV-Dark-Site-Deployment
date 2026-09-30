# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
