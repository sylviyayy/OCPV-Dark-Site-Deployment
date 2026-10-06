# USB Transfer Kit: What to Download, and Why

The **bill of materials** for the dark site: which Hybrid Cloud Console downloads you need, what
else must be on the drive, and how to prove it arrived intact. **When** each item is used:
[Bastion Lifecycle](BASTION-LIFECYCLE.md). **How** to produce it: Labs 01, 04 and 06.

Think of the drive as a Red Hat Satellite content view you can only sync once:

| Satellite concept | Here |
|---|---|
| `dnf` binary | CLI tools (`oc`, `openshift-install`, `oc-mirror`) |
| Content view and filters | the ImageSet, rendered from `mirror/imageset-profiles.yaml` (`--profile poc`) |
| Content sync | `oc mirror` mirror-to-disk (Lab 06 step 6.2) |
| RPM name | operator **package** name (the ImageSet key is literally `packages:`) |
| RPM dependencies | **not** resolved: oc-mirror v2 mirrors only the packages listed, so the `odf` profile lists ODF's dependencies |

The Downloads page gives you only the `dnf` binary; the content comes from `oc mirror`.

> **Nothing on the drive expires in 24 hours.** Only the Agent ISO does, and it is built on site
> ([Window A](BASTION-LIFECYCLE.md#2-the-two-24-hour-windows)). Mirror days ahead.

---

## 1. Hybrid Cloud Console downloads (OS Linux, x86_64)

Script 01 downloads and checksum-verifies the three clients for exactly `OCP_VERSION`, plus
mirror-registry (Lab 06 step 6.1). The table says why each is needed.

| Item | Runs on | Why |
|---|---|---|
| `oc` (OpenShift client) | staging host, bastion | Cluster administration, **and** a hidden dependency of the installer: `agent create image` calls `oc adm release info` / `oc image extract` to pull the RHCOS ISO out of the mirrored release |
| `openshift-install` | bastion | Builds the Agent ISO and follows the install. Pinned to one release digest: a mismatch means an ISO pointing at a release not in your mirror |
| `oc-mirror` (v2) | staging host **and** bastion | Mirror to disk, then disk to mirror; writes the IDMS/ITMS/CatalogSources the cluster needs. Use the **same binary** on both sides |
| mirror registry for Red Hat OpenShift | registry host | Self-contained Quay that installs offline; the cluster pulls every image from it for its whole life. Port 8443 |
| Pull secret | staging host (copy to bastion) | Authenticates oc-mirror to Red Hat. On site, the cluster's `pullSecret` is rendered from it plus the mirror credentials, without `cloud.openshift.com` |

**Optional:** `opm` on the staging host, to read package names and default channels before
mirroring (`oc mirror list operators --catalog …:v4.22 --v2` does the same in 4.22).

**Not needed**, so nobody second-guesses it on site: `ocm`, `rosa`, `ccoctl` (cloud services);
`coreos-installer` and RHCOS images (inside the release payload); OpenShift Local (`crc`); ARM,
Power, Z and multi-arch installers (EPYC is x86_64); `butane` (script 08 renders the chrony
MachineConfig itself, base64-encoded). Add `kn` (Serverless) and `tkn` (Pipelines) only if
someone will use those CLIs on site.

## 2. Not on the Downloads page, but must be on the drive

| Item | Why |
|---|---|
| **RHEL 9 Binary DVD** ISO (not the Boot ISO: it has no packages) | Installs the bastion and registry host by kickstart; becomes the local dnf repo (script 04b); serves `bind` and `chrony` to the DNS/NTP VMs |
| **Mirror archive** (`mirror_*.tar`, 80–150 GB) | The OpenShift release (**RHCOS is inside it**), the operators of your profiles, and the digest-pinned RHEL guest image |
| The exact `imageset-config.yaml` you mirrored | Disk-to-mirror needs the same file |
| This repo with your `.env` | Scripts and templates; `.env` holds no passwords |
| `SHA256SUMS` | Proves the copy on the dark side is bit-for-bit identical |
| SSH **public** key | Login to the bastion and nodes; the private key never crosses |

### Operators: decide before mirroring

| Profile | Packages | Needed for |
|---|---|---|
| `default` (always) | `kubevirt-hyperconverged`, `kubernetes-nmstate-operator` | Virtualization; the VM network and DNS cut-over |
| storage (by `STORAGE_BACKEND`) | `ontap` → `trident-operator` (certified catalog); `lvms` → `lvms-operator`; `hpp` → none | A default StorageClass, or every DataVolume stays `Pending` |
| `poc` | MTV, Authorino, KMM, Pipelines, Service Mesh 3, Serverless | The POC sheet's operator list |
| `odf` | Local Storage, ODF and its dependency packages | Only with empty disks or LUNs on every node |

Whatever is not in the archive cannot be installed on site without another trip.

## 3. Drive layout

Two drives plus a backup of the data drive:

```text
Drive A — boot:  bastion-ks.iso written with dd (Lab 04 step 4.3); or mount it as XCC virtual media
Drive B — data (exFAT, ext4 or XFS; not FAT32: files exceed 4 GiB)      Drive B' — verified copy of B
└── ocp-transfer/                       # Lab 06 step 6.3 creates exactly this
    ├── SHA256SUMS
    ├── mirror_*.tar
    ├── clients/                        # oc, openshift-install, oc-mirror, mirror-registry/
    ├── imageset-config.yaml
    ├── rhel9-dvd.iso
    ├── repo.tar.gz                     # this repo + .env
    ├── pull-secret.json                # sensitive
    └── id_ed25519.pub
```

`bastion-ks.iso` (built with `mkksiso`, Lab 04) already embeds the kickstart and this repo, so the
bastion installs with zero keystrokes and no `inst.ks=` typing.

## 4. Pre-departure checklist (staging host)

- [ ] `.env` validates in full: `./scripts/lib/validate-env.sh` → `PASS` (node MACs and root disks included)
- [ ] Every `>>> UPDATE` placeholder confirmed: `grep -n UPDATE .env` shows only values you accept
- [ ] `STORAGE_BACKEND` and the profiles are decided, and mirror-to-disk ran with them (`--profile poc`)
- [ ] Mirror-to-disk finished without errors (oc-mirror prints a summary at the end)
- [ ] `openshift-install version` reports `OCP_VERSION`
- [ ] `sha256sum -c --quiet SHA256SUMS` passes on Drive B **and** B'
- [ ] `bastion-ks.iso` (and `registry-ks.iso` for a separate registry host) on Drive A
- [ ] Drives handled as sensitive media: they carry the pull secret

Not on this list on purpose: the Agent ISO. It is built on site at T-0.

## Next

→ [Bastion Lifecycle](BASTION-LIFECYCLE.md) · [Lab 06 — Mirroring](labs/06-mirroring-images.md)
