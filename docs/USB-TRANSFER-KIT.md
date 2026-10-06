# USB Transfer Kit: What to Download, and Why

This page is the **bill of materials (BOM)** for the dark site. It answers two questions:

1. Which items on the Red Hat Hybrid Cloud Console **Downloads** page
   (`console.redhat.com/openshift/downloads`) you need, and why.
2. What else must be on the USB drive. This includes things that are not on that page,
   such as RHCOS, the Virtualization operators, and the RHEL ISO.

For **when** each item is used, and where the 24-hour limit actually applies, see the
companion page: [Bastion Lifecycle](BASTION-LIFECYCLE.md).

---

## 1. The rule: if it's not on the drive, it doesn't exist at the dark site

Once you cross the air gap you have no supply line. A missing file means another trip
to the connected side. Plan the drive the way you would plan a **Red Hat Satellite
content view**:

| Satellite concept | What it is in this project |
|---|---|
| `dnf` binary | The CLI tools on the Downloads page (`oc`, `openshift-install`, ...) |
| Content view definition and filters | `ImageSetConfiguration` (`mirror/imageset-config.yaml.template`) |
| Content sync | `oc mirror` (mirror-to-disk) |
| Repository metadata | The operator catalog index image |
| RPM name | Operator **package** name. "Package" is the actual OLM term, and the ImageSet key is literally `packages:` |
| RPM dependencies | A bundle's related images |

The Downloads page only gives you the equivalent of the `dnf` binary. **The repository
content comes from `oc mirror`, not from the Downloads page.**

### The four kinds of artifact

| Artifact class | What it is | How it crosses the air gap | Where it comes from |
|---|---|---|---|
| **Tooling** | Programs you run on the staging host, the bastion and the registry host | Tarballs and binaries on the USB drive | Hybrid Cloud Console Downloads page (section 2) |
| **Payload** | Container images: the OpenShift release, operators and VM guest images | Mirror archive written by `oc mirror` | `registry.redhat.io`, `quay.io` (section 3.2) |
| **Boot media** | The RHEL installer for the bastion and registry host. The RHCOS agent ISO for cluster nodes | RHEL: an ISO on the USB drive. RHCOS: **built at the dark site** | Red Hat Customer Portal (RHEL). The release payload (RHCOS) |
| **Trust and identity** | Pull secret, registry credentials, registry CA | Files on the USB drive (treat the drive as sensitive) | Console "Tokens" section. Your own registry |

> **Nothing on this drive expires in 24 hours.** The 24-hour limit applies only to
> the **agent ISO**, which you build at the dark site minutes before booting the nodes.
> Download everything days in advance. See
> [Bastion Lifecycle → The two 24-hour windows](BASTION-LIFECYCLE.md#2-the-two-24-hour-windows-and-what-is-not-on-a-clock).

---

## 2. Hybrid Cloud Console downloads

Select **OS type = Linux** and **Architecture = x86_64** for every item. The
reference servers use AMD EPYC CPUs, which are x86_64.

### 2.1 Required

| Console section | Item | What you get | Runs on | Version rule | Why you need it |
|---|---|---|---|---|---|
| Command-line interface (CLI) tools | **OpenShift command-line interface (`oc`)** | `openshift-client-linux.tar.gz` (contains `oc` and `kubectl`) | Staging host, bastion, later the registry host | Same version as the cluster (pin `OCP_VERSION`, e.g. `4.22.2`) | Cluster administration from day 1 onward. It is also a **hidden dependency of the installer**. In a disconnected install, `openshift-install agent create image` runs `oc adm release info` and `oc image extract` to pull the RHCOS base ISO out of your mirrored release. If `oc` is not on `PATH`, ISO creation fails. |
| OpenShift installation | **OpenShift for x86_64 Installer** | `openshift-install-linux.tar.gz` | Bastion | **Exactly** the release you mirror (e.g. `4.22.2`) | Builds the agent ISO and monitors the install (`agent create image`, `agent wait-for`). Each `openshift-install` binary is pinned to one release-image digest. Run `openshift-install version` to see it. A version mismatch means the ISO points at a release that isn't in your mirror, and the install hangs. |
| OpenShift disconnected installation tools | **OpenShift Client (oc) mirror plugin (`oc-mirror`)** | `oc-mirror.tar.gz` (a RHEL 9 build, `oc-mirror.rhel9.tar.gz`, exists on the same release) | Staging host (mirror to disk) **and** bastion (disk to mirror) | Red Hat says to use the **latest** oc-mirror v2, whatever OpenShift version you mirror. Use the **same binary** on both sides of the air gap. | It is the content-sync engine. It turns your `ImageSetConfiguration` into a mirror archive on the connected side, then pushes that archive into your registry at the dark site. It also generates the IDMS, ITMS and CatalogSource resources the cluster needs. |
| OpenShift disconnected installation tools | **mirror registry for Red Hat OpenShift** | `mirror-registry-amd64.tar.gz` | **Registry host** (not the bastion, see note) | Latest | A self-contained, small-scale Quay registry. The tarball bundles every image it needs, so it **installs with no internet**. The cluster pulls every image from it for its whole life, including after the bastion is gone. Default port is **8443**. It runs on RHEL 8 or 9 with Podman 3.4.2 or later. |
| OpenShift installation customization tools | **Butane config transpiler CLI (`butane`)** | `butane-amd64` (a single binary; rename it to `butane`) | Bastion, later the registry host | Latest. It must support `variant: openshift`, `version: 4.22.0` | The NTP cutover from the bastion to the permanent NTP server is a chrony `MachineConfig`. Red Hat's documented way to produce one is a Butane config. You can hand-write the URL-encoded MachineConfig instead, but this repo's own `machineconfig-dns.yaml` shows why you shouldn't: it encodes newlines as `%0E` (the ASCII Shift Out character) instead of `%0A`. |
| Tokens | **Pull secret** | JSON text ("Download" or "Copy") → save as `pull-secret.json` | Staging host. A copy goes to the bastion | Not version-bound, and **not** on a 24-hour clock | It authenticates `oc mirror` to `registry.redhat.io` and `quay.io` on the connected side. At the dark site, the `install-config.yaml` `pullSecret` must contain your **mirror registry's** credentials, because nodes pull only from the mirror. The Red Hat entries are optional there. Removing the `cloud.openshift.com` entry disables remote health reporting, which can't reach Red Hat from a dark site anyway. |

> **Registry host ≠ bastion.** In this design the bastion leaves the network after
> cutover. The mirror registry must therefore live on a host that stays. If you
> co-locate the registry on the bastion, you can never disconnect the bastion: every new
> pod, upgrade, operator install and node replacement depends on that registry.

### 2.2 Optional

| Item | Where | Why you might want it |
|---|---|---|
| **Operator Package Manager (`opm`)** | Staging host only | Check exact operator package names and default channels before you write the `ImageSetConfiguration`: `opm render registry.redhat.io/redhat/redhat-operator-index:v4.22 \| jq -r 'select(.schema=="olm.package") \| "\(.name)\t\(.defaultChannel)"'`. It is never needed at the dark site. |
| **Helm 3 CLI (`helm`)** | Bastion | Only if you will deploy Helm charts. Every image a chart references must also be in the mirror archive. |

### 2.3 Not needed, and why

Recorded here so that nobody second-guesses the list on site.

| Item | Why it is not needed |
|---|---|
| OpenShift Cluster Manager API CLI (`ocm`) | A client for the OpenShift Cluster Manager SaaS API (`api.openshift.com`), which is unreachable from a dark site |
| Red Hat OpenShift Service on AWS CLI (`rosa`) | For a managed AWS service. Irrelevant on bare metal |
| Knative CLI (`kn`) | OpenShift Serverless is not part of this design |
| Tekton CLI (`tkn`) | OpenShift Pipelines is not part of this design |
| Argo CD CLI (`argocd`) | OpenShift GitOps is not part of this design. If you add it later, mirror its operator too |
| Shipwright CLI (`shp`) | Builds for OpenShift is not part of this design |
| `odo` | A developer inner-loop tool, not an install or ops tool |
| Operator SDK CLI (`operator-sdk`) | For **writing** operators, not consuming them |
| Red Hat OpenShift Application Services CLI (`rhoas`) | For cloud-hosted services that can't be reached from a dark site |
| OpenShift for ARM / IBM Z (s390x) / Power installers | Wrong CPU architecture. EPYC is x86_64 |
| OpenShift Installer with multi-architecture compute machines | For mixed-architecture clusters. This cluster is x86_64 only |
| OpenShift Local (`crc`) | A single-node developer VM for a laptop, not an installer for this rack |
| CoreOS Installer CLI (`coreos-installer`) | For installing or customizing RHCOS by hand. The agent ISO already contains the install logic |
| Cloud Credential Operator CLI (`ccoctl`) | Manages cloud IAM credentials (AWS STS, GCP Workload Identity, Azure). Bare metal has no cloud IAM |
| OpenShift Cluster Manager API Token | Authenticates `ocm` and API automation against `console.redhat.com`. Useless offline |

---

## 3. Not on the Downloads page, but must be on the drive

### 3.1 RHEL 9 Binary DVD ISO (Red Hat Customer Portal)

Download the full **Binary DVD** image, `rhel-9.x-x86_64-dvd.iso` (about 10–11 GB), from
`access.redhat.com/downloads`. Do **not** use the Boot ISO: the Boot ISO contains no
packages, so the `cdrom`-sourced Kickstart has nothing to install from.

The DVD serves **three** purposes, which is why it appears twice in the drive layout
(section 4):

| Purpose | Where | Why |
|---|---|---|
| 1. Install the bastion and registry host | Boot drive (Drive A) | Kickstart (`kickstart/ks-*.cfg`) installs from local media. There is no network repo |
| 2. Local `dnf` repository on the bastion | Data drive copy, loop-mounted | Supplies `nmstate` (provides `nmstatectl`), `dnsmasq`, `chrony`, `bind-utils`, `podman`, `skopeo` and any package you forgot |
| 3. Package repository for the permanent DNS/NTP VMs | Registry host, served over HTTP | The RHEL guest image does **not** contain BIND. The DNS VM's cloud-init needs a reachable repository to install `bind` |

> **`nmstatectl` is mandatory** on the host that runs `openshift-install agent create image`.
> The installer uses it to validate each host's `networkConfig` in `agent-config.yaml`.
> Without it, ISO creation fails with `executable file not found in $PATH`. It comes from
> the `nmstate` RPM on the RHEL DVD, not from the Downloads page.

Use **RHEL 9** for the registry host. Red Hat documents mirror registry support for
RHEL 8 and 9. Check that RHEL 10 is supported before you choose it.

### 3.2 The mirror archive: OpenShift release, RHCOS, operators and guest images

`oc mirror` (mirror-to-disk) writes this archive on the connected side. It is the
largest item on the drive, typically 80–150 GB depending on the operators you select.

**RHCOS is inside it.** You do not download RHCOS separately. The OpenShift release
payload carries a `machine-os-images` component that contains the RHCOS base ISO. At
the dark site, `openshift-install agent create image` extracts that ISO from your
mirrored release and bakes your `install-config.yaml` and `agent-config.yaml` into it.
Think of it as a golden-image build, like Packer: base image plus your configuration
gives a site-specific image.

**The Virtualization operators are inside it too.** They come from your
`ImageSetConfiguration`, never from the Downloads page. Sort them by what breaks
without them:

| Tier | Operator package(s) | In `imageset-config.yaml.template`? | What breaks without it |
|---|---|---|---|
| 1. Core | `kubevirt-hyperconverged` | Yes | No OpenShift Virtualization at all |
| 2. Required by this design | `kubernetes-nmstate-operator` | Yes | The permanent DNS/NTP VMs can't get a host bridge on the flat L2. The DNS cutover `NodeNetworkConfigurationPolicy` has no controller |
| 2. Required by this design: **storage, pick one** | SAN vendor CSI operator (in `certified-operator-index`, which needs a second `catalog:` entry), **or** `lvms-operator` (needs an unused local disk), **or** ODF (pulls in several dependency packages you must list) | **No. This is a decision you must make before mirroring** | The DNS/NTP VM `DataVolume`s stay `Pending` (no `StorageClass`). On the reference hardware the two 960 GB SSDs form the RAID1 OS volume, so LVMS has nothing to claim unless you add disks |
| 3. VM high availability | `node-healthcheck-operator`, plus `fence-agents-remediation` (BMC power fencing) or `self-node-remediation` | No | VMs on a dead node are not restarted elsewhere |
| 4. Workload-dependent | `mtv-operator` (VMware migration), `cluster-kube-descheduler-operator`, `nfd`, plus `gpu-operator-certified` (certified catalog) for the SR675 L40S GPUs | No | Only the features those workloads need |

The **VM guest image** for the permanent DNS/NTP VMs comes from the archive too, via
`additionalImages` (`registry.redhat.io/rhel9/rhel-guest-image`).

> **Decision gate: storage.** Pick the storage operator **before** you run
> mirror-to-disk. You cannot fetch it later without another trip across the air gap.

### 3.3 Everything else

| Item | Why |
|---|---|
| This repository, with your filled-in `.env` | Scripts, templates and Kickstart files. `.env` holds registry passwords, so treat it as a secret |
| `SHA256SUMS` manifest (you generate it) | Proves the copy on the dark side is bit-for-bit identical (section 5) |
| The exact `ImageSetConfiguration` you mirrored | oc-mirror needs the same file for disk-to-mirror, and later for incremental updates |

### 3.4 Things you do **not** need to carry

| Item | Why not |
|---|---|
| RHCOS ISO or RHCOS images | Extracted from the mirrored release payload at the dark site (3.2) |
| `virtctl` | The cluster serves it from its own console download links once OpenShift Virtualization is installed |
| `coreos-installer` | The agent ISO replaces manual RHCOS installs |
| `openshift-clients` RPM | It comes from an OpenShift repository that is not on the RHEL DVD. Use the `oc` tarball instead, which also avoids two `oc` binaries drifting apart |

---

## 4. Drive layout

Use **two physical drives, plus a backup of the data drive**. Two drives are needed
because the RHEL DVD written with `dd` becomes a read-only ISO 9660 filesystem with no
room for your files.

Format the data drive as **XFS or ext4, not FAT32**. FAT32 cannot hold files larger than
4 GiB, and both the RHEL DVD ISO and the mirror archive chunks exceed that.

```text
Drive A — "boot" (dd of rhel-9.x-x86_64-dvd.iso)
└── (read-only RHEL installer)

Drive B — "data" (XFS, label OCPV-DATA)        Drive B' — byte-identical backup of B
├── SHA256SUMS
├── kickstart/
│   ├── ks-bastion.cfg
│   └── ks-registry-mirror.cfg
├── tools/
│   ├── openshift-client-linux.tar.gz           # oc + kubectl
│   ├── openshift-install-linux.tar.gz          # exact release, e.g. 4.22.2
│   ├── oc-mirror.tar.gz                        # the SAME binary used for mirror-to-disk
│   ├── mirror-registry-amd64.tar.gz            # for the registry host
│   ├── butane-amd64
│   └── opm-linux.tar.gz                        # optional
├── media/
│   └── rhel-9.x-x86_64-dvd.iso                 # purposes 2 and 3 in section 3.1
├── mirror/
│   ├── imageset-config.yaml                    # exactly what you mirrored
│   └── oc-mirror-workdir/                      # mirror_*.tar archive(s) + working-dir/
├── secrets/
│   └── pull-secret.json
└── OCPV-Dark-Site-Deployment/                  # this repo, with your .env
```

Referencing the drive by its filesystem **label** removes the guesswork about whether
it shows up as `sda` or `sdb`. Anaconda accepts it directly:

```text
inst.ks=hd:LABEL=OCPV-DATA:/kickstart/ks-bastion.cfg
```

---

## 5. Pre-departure checklist (connected side)

**WHERE:** Staging host, with internet.
**WHY:** Every item below is impossible or expensive to fix once you are inside the air gap.

```bash
# Pin check: the installer's embedded release must be the one you mirrored
./openshift-install version          # shows "release image ...@sha256:<digest>"
./oc version --client                # same 4.22.z
./oc-mirror version                  # record it; carry this exact binary

# Format and label the data drive (check lsblk FIRST; this wipes the device)
lsblk
sudo mkfs.xfs -f -L OCPV-DATA /dev/sdX1

# After copying everything onto Drive B:
cd /run/media/$USER/OCPV-DATA
find . -type f ! -name SHA256SUMS -print0 | xargs -0 sha256sum > SHA256SUMS
sha256sum -c --quiet SHA256SUMS && echo "Drive B verified"
# Repeat the copy for Drive B' and verify it independently
```

- [ ] The storage decision is made, and its operator is in the `ImageSetConfiguration`
- [ ] `oc mirror` mirror-to-disk finished **without errors**. Errors are summarized at the end of the run and in its logs
- [ ] `openshift-install version` digest matches the release you mirrored
- [ ] The same `oc-mirror` binary is on the drive (used again for disk-to-mirror)
- [ ] The RHEL **Binary DVD** (not the Boot ISO) is on Drive A **and** in `media/` on Drive B
- [ ] `SHA256SUMS` verifies on Drive B **and** on backup Drive B'
- [ ] Kickstart files are edited: IPs, NIC names, passwords, SSH key
- [ ] Drives are handled as sensitive media: they carry the pull secret and registry passwords. If your policy requires LUKS, add `cryptsetup` to the Kickstart `%packages` so a fresh bastion can unlock them

**Not on this checklist on purpose:** building the agent ISO. That happens at the dark
site, at **T-0**. See [Bastion Lifecycle](BASTION-LIFECYCLE.md).

---

## Next

→ [Bastion Lifecycle: USB → temporary DNS/NTP → install → permanent DNS/NTP → disconnect](BASTION-LIFECYCLE.md)
→ [Lab 06: Mirroring Images](labs/06-mirroring-images.md)
