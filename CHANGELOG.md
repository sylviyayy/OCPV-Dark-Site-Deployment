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
- **FR-B6** — `mirror/imageset-profiles.yaml`: default set adds `kubernetes-nmstate-operator`, `lvms-operator` joins when `STORAGE_BACKEND=lvms`, and the former `imageset-ocpv-coe.yaml` is the selectable `coe` profile; the RHEL guest image is pinned by digest
- **FR-D1** — `imageDigestSources` rendered into `install-config.yaml` from oc-mirror's `idms-oc-mirror.yaml`
- **FR-D4** — per-node `bond0` (802.3ad, four members, `MTU`) in `agent-config.yaml` from `CPn_NICS`
- **FR-D6** — `additionalNTPSources` in `agent-config.yaml` (`TIME_SOURCE`, or the bastion when orphan)
- **FR-D7** — `scripts/05a-create-agent-iso.sh` (Lab 08, keeps `*.orig` inputs) and `scripts/05b-wait-install.sh` (Lab 10, asserts 3 Ready nodes and 4 bond members up)
- **FR-E4** — kickstarts become `kickstart/*.cfg.template`; `scripts/render-kickstart.sh` fills IPs, `BASTION_IFNAME`, domain and `/etc/hosts` from `.env`
- **FR-G3** — `scripts/06b-configure-storage.sh`: HostPathProvisioner CR plus default StorageClass `hostpath-csi` (or LVMS when `STORAGE_BACKEND=lvms`), proven by a 1 GiB DataVolume reaching `Succeeded`
- **FR-H2** — per-VM network-config v2 Secret gives each guest its static address, matched by a MAC pinned on the VM interface
- **FR-H3** — `scripts/04b-serve-dvd-repo.sh` loop-mounts the RHEL 9 DVD on the bastion and serves BaseOS/AppStream over HTTP (local dnf repos for the bastion, package source for the DNS/NTP VMs)
- **FR-H5** — `manifests/production/network/`: NNCP mapping localnet `vmnet` onto `br-ex` and a localnet NetworkAttachmentDefinition; script 06 installs Kubernetes NMState and its `NMState` instance, which the PRD's localnet design needs but no FR installed
- **FR-H6** — `dns-vm/nncp-dns-cutover.yaml.template` sets node resolvers (both DNS VMs, then the bastion) through NMState
- **FR-H8** — two DNS VMs (`dns-a`, `dns-b`) with required pod anti-affinity; all service VMs take time from `TIME_SOURCE` (or the bastion's orphan clock)
- **FR-H13** — BIND serves a reverse zone for `MACHINE_NETWORK_CIDR`; `recursion no` is documented
- **FR-I5** — `.github/workflows/lint.yml`: `shellcheck -S warning`, render-and-parse of every template from `tests/ci.env` (with `named-checkconf -z` on the rendered zones), relative-link and anchor check, field-register order check, placeholder/terminology/pinning searches, gitleaks secret scan
- **FR-J6** — interim Mermaid architecture diagram in `README.md` replaces the `<insert architecture diagram>` placeholder (parses with Mermaid 11)
- `docs/DECISIONS.md` records ADR-01 to ADR-08 and open questions Q1–Q6 with their recommended options (PRD Phase 0)
- Pre-defined field register: short form (groups A–C) at the top of `README.md`, full form in Lab 03; CI proves `.env.example`, README and Lab 03 match the register in `scripts/lib/render.py`
- Labs follow the step contract WHERE / WHY / EDIT / DO / VERIFY / FAILS IF, and each lab states whether its result is lab-grade or production-grade
- `docs/labs/appendix-a-adding-workers.md` and `docs/labs/appendix-b-network-boot.md`
- `scripts/lib/authfile.sh` builds `${AUTH_FILE}`; the registry entry is added on the high side with `podman login --password-stdin`, which also proves password, DNS and CA trust
- Hard Way–style repository front door in `README.md` with hyperlinked labs
- Lenovo CoE compute lab: 2× SR665 V3 + 1× SR675 V3 (L40S), NIC slot layout, compact 3-node roles
- Labs 01–16 remapped (bastion, compute, mirror, agent bootstrap, `oc` access, cleanup)
- Beginner lab series `docs/labs/` (Hard Way–style): `vim`, per-field `.env` guide, rationale every step
- Greenfield partner documentation (now `docs/reference/GREENFIELD-README.md`, `docs/reference/greenfield/*`)
- Deployment tracks (bare metal primary, optional KVM lab appendix)
- Diagram placement guide — network + storage **before** OCP-V platform topology
- Reference to [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab) for optional KVM practice only
- `.cursor/rules/prd-v2-execution.mdc`: execution rules for agents (requirement IDs in commits, verify-on-4.22 TODOs, local CI before commit)

### Changed
- **FR-A2** — compact topology end to end: `compute.replicas: 0`; worker hosts `wk01`/`wk02` removed from templates, scripts, IP plan, kickstarts and zone data
- **FR-A4** — `load_env` no longer falls back to `.env.example`, exports values with `set -a`, and refuses a v1 `.env`
- **FR-B2** — script 01 requires only `curl jq tar sha256sum skopeo python3` up front and checks `oc`/`oc-mirror` after downloading them
- **FR-B3** — every `oc mirror` call passes `--authfile ${AUTH_FILE}` (pull secret, plus the registry entry on the high side); the write-only `mirror-registry-creds.json` is gone
- **FR-B4** — mirror-to-disk uses `oc mirror -c <isc> file://${MIRROR_ARCHIVE_DIR} --v2`; `OC_MIRROR_WORKDIR` becomes the derived `MIRROR_ARCHIVE_DIR`
- **FR-B5** — disk-to-mirror uses `--from file://${MIRROR_ARCHIVE_DIR} docker://${MIRROR_REGISTRY}`; cluster-resources are read from `${MIRROR_ARCHIVE_DIR}/working-dir/cluster-resources/`
- **FR-B7** — Lab 06 and `docs/labs/detail/staging-mirror.md` copy the archive, clients, the exact ImageSet, the repo and the RHEL 9 DVD to media with a generated `SHA256SUMS` (verified on the high side) instead of gzipping the whole mirror directory
- **FR-B8** — Labs 04 and 06 describe two hosts (low-side staging host, high-side bastion); no lab places one host on both networks
- **FR-B9** — `/opt/ocp-mirror` is created with `chown -R "$USER:$USER"` (Lab 01, field-by-field guide)
- **FR-C1** — one registry endpoint `${MIRROR_REGISTRY_HOSTNAME}:${MIRROR_REGISTRY_PORT}` (default **8443**, the tool default) in `.env.example`, scripts, registry-host firewall and docs; no `:443`/`:5000` registry references remain
- **FR-C3** — the registry trust anchor is mirror-registry's own `quay-rootCA/rootCA.pem` copied to `${REGISTRY_CA_FILE}`; the `openssl s_client` leaf scrape and the kickstart's never-served self-signed certificate are gone
- **FR-C4** — Lab 06 trusts the registry CA on the bastion (`update-ca-trust`); every VERIFY and script checks TLS without `-k`
- **FR-C5** — `scripts/04 install-registry` refuses to start as non-root; `load` refuses root
- **FR-D2** — `pullSecret` is the merged `${AUTH_FILE}` (Red Hat pull secret plus mirror-registry entry); `install-config/README.md` (was `mirror-config.yaml.template`) reverses the old "not the mirror-registry credentials" note
- **FR-D5** — `rootDeviceHints.deviceName` comes from `CPn_ROOT_DEVICE` (`/dev/disk/by-path/…`), never `/dev/sda`
- **FR-D8** — `agent-config.yaml` `metadata.name` follows `CLUSTER_NAME`
- **FR-D9** — scripts 05a/05b no longer apply oc-mirror cluster-resources; Lab 12 is the single owner
- **FR-E2** — helper hosts boot a `mkksiso`-built RHEL 9 DVD with the kickstart embedded (USB or XCC virtual media, zero keystrokes) instead of `dd` plus a typed `inst.ks=hd:sdb1`
- **FR-E5** — bastion resolver is itself (`--nameserver=${BASTION_IP}`) and dnsmasq listens on `127.0.0.1,${BASTION_IP}`
- **FR-E6** — the bastion kickstart copies the repo from the install medium in `%post --nochroot` (added with `mkksiso --add`)
- **FR-E7** — kickstart `bootloader` drops `--location=mbr` and `crashkernel=auto`
- **FR-E8** — PXE stanzas removed from the primary docs; one appendix points sites that already run network boot at `openshift-install agent create pxe-files`
- **FR-F1** — dnsmasq uses `host-record` (A + PTR), `address=/apps.<cluster>.<domain>/` for the wildcard, no empty `no-dhcp-interface=`, no worker records
- **FR-F2** — NTP checks use the client-side probe `chronyd -Q "server <ip> iburst"` and assert the offset is under 1 s; `chronyc -h <remote>` removed
- **FR-F3** — Lab 07 carries a "lab-grade time" callout for `TIME_SOURCE=orphan` and points production at a reference clock
- **FR-G1** — script 06 reads the CatalogSource name from oc-mirror's `cs-*.yaml` and waits for it to report `READY`
- **FR-G2** — Lab 12 disables the default catalog sources (`OperatorHub` `disableAllDefaultSources: true`) before applying cluster-resources
- **FR-G4** — every wait loop in scripts 06/06b/07/08 exits 1 with diagnostics on timeout; missing `/dev/kvm` on any node fails the run
- **FR-G5** — `HyperConverged` spec is empty: no `withHostPassthroughCPU`, no `completionTimeoutPerGiB`
- **FR-H4** — scripts 07/08 render manifests through `render.py`; the `sed` token chain (which wrote `registry IN A 10.10.0.10:443_IP`) is gone
- **FR-H7** — DataVolumes use the `storage:` API, the default StorageClass, the registry CA (`certConfigMap`) and credentials (`secretRef`), and the digest-pinned guest image
- **FR-H9** — VMs set `evictionStrategy: None`; the chrony MachineConfig rolls out only after both DNS VMs answer
- **FR-H11** — `runStrategy: Always` replaces `running: true`; a dedicated `infrastructure-vm` PriorityClass replaces `system-node-critical`
- **FR-H12** — script 08 ends with "keep bastion dnsmasq/chronyd running as secondary" instead of disabling them
- **FR-I2** — every DNS check compares the answer with the `.env` value (`expect_dns`, `expect_ptr`); `dig … +short` alone passed on an empty answer
- **FR-I3** — `scripts/00-prerequisites-check.sh` modes `--staging`, `--bastion`, `--post-install`, each asserting the pinned OS first and requiring only tools present at that stage
- **FR-J2** — one term per concept: "bastion" everywhere; one node naming convention, `mw01`–`mw03` (master + worker, the compact role) for hostnames and `MW01_*`–`MW03_*` for `.env` keys, replacing the PRD's `cp01`–`cp03`; links to `03-checklist.md` and `04-bastion.md`
- **FR-J3** — `docs/01`–`07`, `GREENFIELD-README.md`, `DEPLOYMENT-TRACKS.md` and `docs/greenfield/*` moved to `docs/reference/` under a non-normative banner (ADR-01); procedural pages condensed to background and pointers
- **FR-J4** — one assumptions table: Lab 01 holds the pinned OS per machine role and the platform assumptions with falsification checks; `greenfield/00-assumptions-and-scope.md` points to it
- **FR-J5** — Lab 09: etcd encryption at rest is opt-in (`apiserver.spec.encryption.type`); Lab 05: compute replicas 0
- **FR-J7** — default domain `lab.example.com` (and `<name>.internal` guidance) everywhere; `.local` is reserved for mDNS
- **FR-K3** — `.github/PULL_REQUEST_TEMPLATE.md` and `CONTRIBUTING.md`: "Tested on RHEL 9.x per the Lab 01 OS table", checkboxes for WHY/EDIT on every changed step and green CI
- Script 04 split into `install-registry` (root, registry host) and `load` (installer user, bastion); `--mirror-to-registry` removed from script 01 (the low side never touches the registry, ADR-02)
- Bastion chrony follows `TIME_SOURCE` (reference clock, or labelled lab-grade orphan)
- `network/sample-switch-config/lacp-mlag-switch.conf.example` (was `flat-l2-switch.conf.example`) shows one LACP port-channel per node across a vPC pair, matching `bond0`; `network/ip-addressing-plan.csv` matches `.env.example`
- `.env.example` rewritten to the v2 field register (§1 order, IDs A1–F4, derived block validated); `NETWORK_CIDR` → `MACHINE_NETWORK_CIDR`, `DNS_VM_IP` → `DNS_VM_IPS`, `OC_MIRROR_WORKDIR` → derived `MIRROR_ARCHIVE_DIR`
- Quick start examples use `vim` and point at explicit `.env` field list
- Rewrote brownfield appendix as customer qualification decision aid; fixed false MTV mirror claim
- Resolved GREENFIELD-README contradiction on VMware-exit DNS (function rebuild vs "does not apply")
- Replaced deprecated `oc adm release mirror` / ICSP workflow with **oc-mirror plugin v2** and IDMS/ITMS
- Aligned install flow with official Red Hat Agent-based Installer disconnected documentation
- Added the disconnected task flow (now `docs/reference/00-disconnected-install-task-flow.md`)
- Added `mirror/imageset-config.yaml.template` (`mirror.openshift.io/v2alpha1`)
- Updated CNV deployment to use mirrored `kubevirt-hyperconverged` from `redhat-operator-index:v4.22`
- Changelog policy, release workflow, and PR template for consistent change tracking

### Removed
- **FR-C2** — the podman `registry:2` fallback in script 04 (its image lives on Docker Hub); a missing `mirror-registry` now exits 1 with the download instruction
- `scripts/05-install-ocp-disconnected.sh` (split into 05a/05b, FR-D7)
- `network/dns-hosts-template/` (static copies that drifted from `.env`; the bastion config and the DNS VM zone are rendered)
- `mirror/imageset-ocpv-coe.yaml` (now the `coe` profile, FR-B6) and `graph: true` (OSUS is a v2.0 non-goal)
- `manifests/production/dns-vm/machineconfig-dns.yaml` (its `%0E` data URL wrote an unusable `resolv.conf`), `nad-flat-l2.yaml`, and the ConfigMap-based `cloud-init.yaml`/`vm.yaml` pairs
- `.env` keys `NETWORK_INTERFACE`, `NETWORK_NETMASK`, `CPn_MAC`, `WK01_*`, `WK02_*`, `DNS_SERVER`, `NTP_SERVER`, `OPERATOR_CATALOG`, `CNV_*`, `SSH_USER`, `INSTALL_USER`

### Fixed
- **FR-B1** — script 01 picks the RHEL 9 installer, client and oc-mirror builds from the release's `sha256sum.txt` by pattern and verifies them with `sha256sum -c`; the old `openshift-install.tar.gz`/`oc.tar.gz` names returned 404
- **FR-D3** — `additionalTrustBundle` is emitted as a literal block with every PEM line indented; the old `str.replace` produced YAML that failed to parse
- **FR-E1** — bastion kickstart no longer lists `openshift-clients` (not on the RHEL DVD; Anaconda halted) or a duplicate `nmstate`
- **FR-H1** — VM cloud-init is a `Secret` (`stringData.userdata`) attached with `cloudInitNoCloud.secretRef`; the old ConfigMap was never found and `cloudInitConfigDrive.sources` is not a KubeVirt field
- **FR-I1** — `--post-install` node and ClusterOperator checks are named functions returning one status; the old pipelines swallowed the PASS/FAIL line, lost the counters in a subshell and inverted the logic, so a broken cluster could pass
- **FR-I4** — no `curl -k`/`-sk` remains in scripts or docs
- **FR-J1** — all 16 broken relative links fixed; CI checks every relative link and heading anchor
- **FR-K4** — this section previously recorded the default mirror registry port as 443; the tool default is **8443** (FR-C1). Every v2.0 requirement now appears in exactly one bullet under its Keep a Changelog heading
- `scripts/lib/common.sh` resolved `REPO_ROOT` to `scripts/` (it read `BASH_SOURCE[0]` of itself), so every script exited 1 at `load_env` before doing any work (audit finding beyond the PRD)
- Kickstart firewall rules use the declarative `firewall` command; `firewall-cmd` inside a chrooted `%post` under `set -e` failed (firewalld not running) and aborted the rest of `%post` (audit finding beyond the PRD)

### Security
- **FR-E3** — kickstarts lock `root` and give `installer` a SHA-512 hash made at render time from a prompted password; no `--plaintext` anywhere
- **FR-H10** — VM cloud-init has no passwords: `disable_root`, `lock_passwd`, SSH key rendered from `SSH_PUBLIC_KEY_FILE`
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
