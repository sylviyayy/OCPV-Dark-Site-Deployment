# Architecture decisions (v2.0)

Nine decisions determine which files exist and what they contain; implementing requirements
before them produces rework. Each is recorded as **Context → Decision → Consequences**.

**Status legend.** *Proposed* = the recommended option is implemented on the v2.0 branch and awaits
the maintainer's acceptance (PRD Phase 0 gate). Change a status to *Accepted* (with date and name)
or record an amendment; an amendment means the listed files change.

| ADR | Decision | Status |
|---|---|---|
| ADR-01 | `docs/labs/` is normative; older pages are non-normative in `docs/reference/` | Proposed |
| ADR-02 | Two machines: low-side staging host, high-side permanent bastion; media + `SHA256SUMS` | Proposed |
| ADR-03 | mirror registry for Red Hat OpenShift at `hostname:8443`, never by IP; no fallback registry | Proposed |
| ADR-04 | Nodes boot the Agent ISO via XCC virtual media; helpers boot a `mkksiso` DVD; no network boot | Proposed |
| ADR-05 | VM storage: Lenovo DM/DG (ONTAP) via NetApp Trident NFS; hostpath provisioner until it is attached; LVMS for a DS-series array | Proposed (amended) |
| ADR-06 | VM network: OVN-K localnet on `br-ex` via an NMState bridge mapping | Proposed |
| ADR-07 | Steady-state DNS/NTP on VMs; the bastion stays the secondary permanently | Proposed |
| ADR-08 | `INSTALL_DIR` outside the git working tree; inputs kept as `*.orig` | Proposed |
| ADR-09 | Node names `mw01`–`mw03` (master + worker), keys `MW01_*`; overrides the PRD's `cp01`–`cp03` | Proposed |

---

## ADR-01 — Source of truth

**Context.** Three documentation trees disagreed on bastion OS, node count, registry port and
bastion form; a reader could not tell which statement was normative — three clocks showing three times.

**Decision.** `docs/labs/` is normative. `docs/0x-*.md`, `GREENFIELD-README.md`, `DEPLOYMENT-TRACKS.md`
and `docs/greenfield/*` move to `docs/reference/` under a non-normative banner; nothing in
`docs/reference/greenfield/` is deleted.

**Consequences.** CI checks every relative link and anchor; the field register exists once in code
(`scripts/lib/render.py`) and CI proves `.env.example`, README and Lab 03 match it.

## ADR-02 — Low side and high side

**Context.** One laptop that mirrors over the internet and then joins the machine network breaks the
air gap most regulated sites enforce: cargo may cross, the truck may not.

**Decision.** A connected RHEL 9 staging host never joins the machine network; a permanent physical
RHEL 9 bastion never touches the internet. Removable media plus `SHA256SUMS` carry the archive.

**Consequences.** Labs 04 and 06 are written for two hosts; the registry password is created on the
high side and never crosses; `--mirror-to-registry` is gone from script 01.

## ADR-03 — Registry endpoint

**Context.** The repo named ports 443 and 5000; the tool listens on 8443 by default and issues a
certificate whose SAN is the hostname. Its fallback image lived on Docker Hub.

**Decision.** `${MIRROR_REGISTRY_HOSTNAME}:${MIRROR_REGISTRY_PORT}` (default 8443), never an IP; the
trust anchor is mirror-registry's own root CA; no fallback registry.

**Consequences.** Every check verifies TLS (no `-k`); `validate-env` rejects a hand-edited
`MIRROR_REGISTRY`.

## ADR-04 — Boot method

**Context.** Network boot presupposes DHCP plus TFTP or HTTP services a greenfield dark site does not have.

**Decision.** Nodes: Agent ISO through XCC virtual media. Helpers: RHEL 9 DVD rebuilt with `mkksiso`,
kickstart embedded, from USB or virtual media. Network boot is out of scope
([Appendix B](labs/appendix-b-network-boot.md)).

## ADR-05 — VM storage

**Context.** RAID1 consumes both SSDs per node, so there is no local data disk. With no
StorageClass every DataVolume stays `Pending`. The site has a Lenovo ThinkSystem storage array,
model not yet confirmed (most likely **DM**; possibly DG or DS). DM and DG run NetApp ONTAP and serve
NFS; DS is block-only (iSCSI/FC/SAS) and has no OpenShift CSI driver.

**Decision.** `STORAGE_BACKEND` selects one of three paths, all implemented in
`scripts/06b-configure-storage.sh`:

| Backend | When | Why |
|---|---|---|
| `ontap` (target) | DM or DG array | NetApp Trident from the certified catalog; `ontap-nas` gives ReadWriteMany volumes, so VMs **live-migrate** during node drains (MachineConfig rollouts, upgrades) |
| `hpp` (interim) | until the array is attached | ships with OpenShift Virtualization; node-local ReadWriteOnce, no live migration, shares the etcd disk — lab-grade |
| `lvms` | DS array (one LUN per node) or added local drives | node-local ReadWriteOnce; production-grade local storage without live migration |

NFS (`ontap-nas`) rather than iSCSI (`ontap-san`): no multipath or iSCSI initiator configuration on
the nodes, and RWX Filesystem volumes are what live migration needs. Re-evaluate `ontap-san` only if
VM disk latency measured on the array demands it.

**Consequences.** Register group G (`ONTAP_*`, required only for `ontap`); the SVM password is
prompted, never stored. `VM_STORAGE_CLASS` and `VM_EVICTION_STRATEGY` (`LiveMigrate` on `ontap`,
`None` otherwise) are derived. Switching backend re-mirrors (the profile adds the operator) and
06b demotes the previous default; existing VM disks are not moved. **Verify on 4.22:** Trident
package name, channel and install mode in the certified catalog; whether Trident's own images and CSI
sidecars are covered by the mirrored bundle; HPP pool path requirements; LVMS on multipath LUNs.

## ADR-06 — VM network

**Context.** The old NetworkAttachmentDefinition named a Linux bridge nothing created; VMs booted
isolated without any error.

**Decision.** OVN-Kubernetes localnet `vmnet` mapped onto `br-ex` by an NMState policy, reusing the
LACP bond. Alternative: a Linux bridge on the spare NIC pair — **not implemented in v2.0**, because the
field register has no keys for the spare ports; `VM_NETWORK_MODEL=linux-bridge` fails loudly.

## ADR-07 — Steady-state DNS and NTP

**Context.** A cluster whose only resolver lives inside it has locked the spare key inside the car:
after a site-wide power loss, nodes need the registry name and time before the VMs that serve them can start.

**Decision.** Two anti-affine DNS VMs and one NTP VM are primary; the bastion keeps serving as secondary
resolver and time source permanently. Node resolvers change through NMState `dns-resolver`, never a
MachineConfig over `/etc/resolv.conf`.

**Consequences.** Lab 14 keeps bastion services enabled; Lab 15 includes a cold-start drill.

## ADR-08 — Install directory

**Context.** The installer writes `auth/kubeconfig`, `auth/kubeadmin-password` and
`.openshift_install_state.json` (with the pull secret) beside its inputs — previously the repo's own
`install-config/` folder, one `git add .` away from publication.

**Decision.** `INSTALL_DIR` lives outside the git tree (validated); inputs are copied to `*.orig`
before `openshift-install` consumes them. Same logic as an out-of-tree build.

---

## ADR-09 — Node names

**Context.** The PRD names the nodes `cp01`–`cp03` (control plane). In a compact cluster every node
is a master **and** a worker, and the site already labels the servers `mw01`–`mw03`. Two
conventions in one repository produced pages that disagreed.

**Decision.** `mw01`–`mw03` everywhere; register keys `MW01_*`–`MW03_*`. `tests/check-repo-hygiene.sh`
fails on any `cp01`–`cp03` or `CP0n_` so the drift cannot return.

**Consequences.** Overrides PRD §1 group C and FR-J2's naming. Dedicated workers, if ever added,
get their own prefix (Appendix A).

---

## Open questions for the maintainer

| # | Question | Recommendation (implemented) | What changes otherwise |
|---|---|---|---|
| Q1 | Is the bastion a permanent site-services host or a transient laptop? | Permanent physical RHEL 9 host | ADR-07 loses its fallback |
| Q2 | Which Lenovo array model (DM, DG or DS), and its SVM/LIF details? | DM assumed: `ontap` target, `hpp` until attached | DS → `lvms` with one LUN per node, no live migration |
| Q3 | VM network: localnet on `br-ex`, or a Linux bridge on spare ports? | localnet | Cabling, NNCP content, two new register keys |
| Q4 | Registry port: 8443, or a site-mandated 443? | 8443 | `MIRROR_REGISTRY_PORT` only |
| Q5 | Keep SAN and greenfield material as non-normative reference, or delete it? | Keep under `docs/reference/` | Maintenance volume |
| Q6 | Keep a Fedora path for at-home learners? | Only in the optional KVM appendix, labelled unsupported | Lab 01 tolerance column |
