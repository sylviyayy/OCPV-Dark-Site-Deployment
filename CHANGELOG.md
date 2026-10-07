# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `docs/greenfield/01a-worksheet-checklist.md`: completion checklist for the information gathering worksheet. Three review passes (completeness, validity, cross-team consistency) per worksheet section, the inputs later labs need that the form has no row for, secrets hygiene, and a `.env` VERIFY snippet (rendezvous IP, sample/malformed/duplicate MACs and IPs, registry vs bastion, free VIPs). Linked from the worksheet sign-off, `docs/GREENFIELD-README.md`, `docs/greenfield/00-assumptions-and-scope.md` and Lab 03
- `docs/USB-TRANSFER-KIT.md`: bill of materials for the USB drive. Covers which Red Hat Hybrid Cloud Console downloads are required, optional or not needed (with reasons), why RHCOS and the Virtualization operators come from the mirror archive rather than the Downloads page, the RHEL Binary DVD's three roles, drive layout (XFS, two drives plus a backup) and the pre-departure checklist
- `docs/BASTION-LIFECYCLE.md`: end-to-end runbook for USB → bastion as temporary DNS/NTP → install → permanent DNS/NTP with the bastion as secondary (make-before-break) → bastion disconnect. Includes the two 24-hour windows (agent ISO shelf life, first certificate rotation), a go/no-go gate before T-0, the bastion evacuation checklist, a risk register and a defect register for this path
- "Before You Go to the Dark Site" section in `README.md`, and 24-hour window callouts in Labs 06, 08 and 10 and in `docs/00-disconnected-install-task-flow.md`
- `additionalNTPSources` (bastion) in `install-config/agent-config.yaml.template`, so nodes use the bastion's NTP during install
- `kubernetes-nmstate-operator` in `mirror/imageset-config.yaml.template` (host bridge for DNS/NTP VMs and the DNS cutover NNCP), plus a storage-operator decision note
- Hard Way–style repository front door in `README.md` with hyperlinked labs
- Lenovo CoE compute lab: 2× SR665 V3 + 1× SR675 V3 (L40S), NIC slot layout, compact 3-node roles
- Labs 01–16 remapped (bastion, compute, mirror, agent bootstrap, `oc` access, cleanup)
- Beginner lab series `docs/labs/` (Hard Way–style): USB/KVM path, `vim`, per-field `.env` guide, rationale every step
- Greenfield partner documentation (`docs/GREENFIELD-README.md`, `docs/greenfield/*`)
- Deployment tracks (bare metal primary, optional KVM lab appendix)
- Diagram placement guide — network + storage **before** OCP-V platform topology
- CoE ImageSet profile `mirror/imageset-ocpv-coe.yaml`
- Reference to [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab) for optional KVM practice only

### Changed
- Renamed all “jumpbox” wording to **bastion**; lab file `04-jumpbox.md` → `04-bastion.md`
- Expanded Lab 07 MVP DNS/NTP verification: `nslookup` against bastion for API + apps URLs, firewall lab vs prod notes
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
- `scripts/08-deploy-ntp-vm.sh` no longer applies DNS/NTP cutover MachineConfigs. Cutover is now the make-before-break procedure in `docs/BASTION-LIFECYCLE.md`, Phases 7–8
- Lab 14, `docs/05`, `docs/06` and `docs/greenfield/05-bootstrap-services.md` keep the bastion running as secondary until the drain is verified, instead of stopping it right after the VMs deploy
- Labs 03 and `detail/configure-site-env.md` require the mirror registry to be on a separate host when the bastion will be disconnected

### Fixed
- `kickstart/ks-bastion.cfg` no longer lists `openshift-clients`, which is not on the RHEL DVD and halted the Kickstart. The duplicate `nmstate` entry is also removed
- `docs/01-architecture-overview.md` no longer says the staging machine downloads RHCOS images. RHCOS ships inside the mirrored release payload
- `docs/03-kickstart-procedure.md` now specifies the RHEL Binary DVD (not the Boot ISO) and drops the non-existent `openshift-client` package
- Broken lab links (`03-worksheet.md` → `03-checklist.md`, `04-jumpbox.md` → `04-bastion.md`, `labs/04-bastion-and-registry-usb.md` → `labs/detail/bastion-and-registry-usb.md`) in `docs/labs/README.md`, `docs/labs/03-checklist.md`, `docs/labs/detail/configure-site-env.md` and `docs/03-kickstart-procedure.md`

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
