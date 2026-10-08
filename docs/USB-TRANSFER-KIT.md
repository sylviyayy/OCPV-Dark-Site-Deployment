# USB Transfer Kit: What to Download, and Why

This page is the **bill of materials (BOM)** for crossing the air gap for this hands-on.

**Pinned release for this repo:** OpenShift **4.21.27** (OpenShift Virtualization /
Assisted Installer offline media).

For **when** each item is used, see [Bastion Lifecycle](BASTION-LIFECYCLE.md).

---

## 0. Primary path (this hands-on): offline Assisted Installer OVE ISO

This lab uses the **Assisted Installer “disconnected / air-gapped”** download that
produces a self-contained **OpenShift Virtualization** agent image
(`agent.ove.x86_64`, about **58 GB**). That path is currently exposed as a **technology
preview** style workflow in the Hybrid Cloud Console: you must **create a cluster**
first before the offline toggle and download appear.

> You do **not** need a full oc-mirror release archive on the USB for this primary path.
> The OVE offline ISO already carries the release images and the curated Virtualization
> operator bundle. (If you later need operators outside that bundle, use the optional
> mirror path in §3.)

### 0.1 Prepare the USB stick first

| Requirement | Why |
|---|---|
| Capacity **≥ 65 GB** | The `agent.ove.x86_64` file is ~**58 GB**; leave headroom for checksums / this repo / secrets |
| Filesystem **exFAT** (or another FS that allows files **> 4 GiB**) | Many sticks ship as **FAT32**, which **cannot** store a ~58 GB single file. **Reformat FAT/FAT32 → exFAT** before copying |
| Label something memorable | e.g. `OCPV-OVE` so you recognize it on the bastion |

Example (Linux staging host — **check `lsblk` first; this wipes the stick**):

```bash
lsblk
# Replace sdX1 with your USB partition
sudo mkfs.exfat -n OCPV-OVE /dev/sdX1
```

On macOS: Disk Utility → erase the stick as **exFAT**.

### 0.2 Download from Red Hat Hybrid Cloud Console

**WHERE:** Connected laptop (internet).  
**WHY:** This is the only supported way to obtain the offline OVE agent media for this lab.

1. Log in to [console.redhat.com](https://console.redhat.com).
2. Open **OpenShift** → **Resources** (Assisted Installer entry point for OpenShift).
3. Start **Create cluster** (Assisted Installer).  
   The offline controls appear only after you begin creating a cluster.
4. When the cluster-details UI offers it, enable the toggle for a
   **disconnected / air-gapped / secured** (offline) deployment.
5. Continue until the UI offers the download for **OpenShift 4.21.27** for
   **OpenShift Virtualization**.
6. Download the offline agent media — filename similar to **`agent.ove.x86_64`**
   (~**58 GB**). Save it to the **exFAT** USB.

Confirm the version string in the console UI matches **4.21.27** before you leave the
connected site.

### 0.3 Also put on the same USB (small extras)

| Item | Why |
|---|---|
| This git repository (with filled `.env`) | Labs, Kickstart for bastion, worksheets |
| Pull secret (if the UI/path still requires it on site) | Auth material — treat USB as sensitive |
| SSH public key you will inject for `core` | Node access after install |
| Optional: RHEL Binary DVD + Kickstart | Only if you still install a **physical bastion/registry** from USB ([Lab 04](labs/04-bastion.md)) |

### 0.4 Pre-departure checklist (OVE path)

- [ ] USB reformatted to **exFAT** (not FAT32)
- [ ] Stick is **≥ 65 GB** and has a verified copy of `agent.ove.x86_64` (~58 GB)
- [ ] Console download is **4.21.27** Virtualization / OVE offline media
- [ ] Worksheet complete ([information gathering](greenfield/01-information-gathering-worksheet.md))
- [ ] This repo + `.env` on the stick
- [ ] You can reach each node’s **XCC** to map the ISO as virtual CD at the dark site

**At the dark site:** attach/boot `agent.ove.x86_64` on the rendezvous node first, then the
other nodes (Lab 10). Bastion DNS/NTP (Lab 07) still matters for greenfield name/time
services even with a self-contained ISO.

---

## 1. The rule: if it's not on the drive, it doesn't exist at the dark site

Once you cross the air gap you have no supply line. For this hands-on the critical file
is the **OVE offline agent image**. Missing it means another trip to the connected side.

### Artifact classes (OVE-primary)

| Artifact class | What it is | How it crosses the air gap |
|---|---|---|
| **OVE offline agent media** | `agent.ove.x86_64` (~58 GB) — RHCOS + Assisted Service + release + Virtualization bundle | Single large file on **exFAT** USB |
| **Tooling / docs** | This repo, optional `oc` later, bastion Kickstart | Small files on the same USB |
| **Trust** | Pull secret, SSH keys | Same USB (sensitive) |
| **Optional helper OS** | RHEL DVD for bastion/registry Kickstart | Separate bootable stick or second drive |

> The OVE offline ISO is large, but it is **not** the same as the classic 24-hour
> ephemeral `openshift-install agent create image` ISO. Still boot promptly and follow
> on-screen Assisted guidance; see [Bastion Lifecycle](BASTION-LIFECYCLE.md) for DNS/NTP
> and certificate windows that still apply after the cluster exists.

---

## 2. Hybrid Cloud Console — what you need for the OVE path

| Action | Result | Version rule |
|---|---|---|
| OpenShift → Resources → Create cluster → **offline / air-gapped toggle** → Download | `agent.ove.x86_64` (~58 GB) | **4.21.27** for this repo |
| Tokens / pull secret (if prompted) | `pull-secret.json` | Not version-bound; do not commit |

### Not needed for the OVE-primary USB

| Item | Why not (for this primary path) |
|---|---|
| Full oc-mirror mirror-to-disk archive (80–150 GB) | OVE offline ISO already embeds the release + Virtualization bundle |
| Separate RHCOS live ISO / `coreos-installer` | Agent/OVE media installs RHCOS |
| `oc adm release mirror` | Deprecated / wrong path for this lab |
| Random CLI packs (rosa, ocm, crc, …) | Unreachable or irrelevant offline |

---

## 3. Optional advanced path: oc-mirror + local registry

Use this **only** if you need operators or content **beyond** the OVE offline bundle, or
you are practicing the classic disconnected mirror workflow.

Then you still need (on a large data drive, **XFS/ext4**, not FAT32):

- `oc`, `openshift-install`, `oc-mirror` (latest v2 binary), `mirror-registry`
- ImageSetConfiguration + mirror archive
- Registry host that **outlives** the bastion ([Bastion Lifecycle](BASTION-LIFECYCLE.md))

Details of that alternate BOM remain in older mirror-focused labs
([Lab 06](labs/06-mirroring-images.md), [task flow](00-disconnected-install-task-flow.md)).
For day-1 of **this** hands-on, prefer §0.

### Optional RHEL Binary DVD (bastion helper)

If you Kickstart a physical bastion/registry:

- Download **RHEL 9 Binary DVD** (not Boot ISO) from access.redhat.com  
- Use [Kickstart](labs/detail/bastion-and-registry-usb.md)  
- That USB is separate from the **exFAT** stick holding `agent.ove.x86_64`

---

## 4. Suggested physical media layout (OVE hands-on)

```text
Stick 1 — "OVE" (exFAT, ≥ 65 GB, label OCPV-OVE)
├── agent.ove.x86_64                 # ~58 GB — OpenShift 4.21.27 Virtualization offline
├── SHA256SUMS                       # optional but recommended
├── secrets/
│   └── pull-secret.json
├── ssh/
│   └── id_ed25519.pub
└── OCPV-Dark-Site-Deployment/       # this repo + filled .env

Stick 2 — "RHEL boot" (optional)     # dd of rhel-*-dvd.iso for bastion Kickstart
└── (ISO 9660 installer)
```

---

## 5. Verify before you travel

```bash
ls -lh /path/to/USB/agent.ove.x86_64    # expect ~58G
df -h /path/to/USB                      # filesystem type should allow huge files
# If you recorded a checksum from the console or your own sha256sum, verify it here
```

- [ ] File size looks complete (~58 GB), not a truncated few-GB download
- [ ] `.env` has `OCP_VERSION=4.21.27`
- [ ] Worksheet signed ([§6](greenfield/01-information-gathering-worksheet.md#6-sign-off-by-function-same-lean-team))

---

## Next

→ [Bastion Lifecycle](BASTION-LIFECYCLE.md)  
→ [Lab 03 — Site checklist](labs/03-checklist.md)  
→ [Lab 10 — Boot the agent / OVE ISO](labs/10-bootstrap-cluster.md)
