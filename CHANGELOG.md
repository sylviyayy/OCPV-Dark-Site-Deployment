# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
