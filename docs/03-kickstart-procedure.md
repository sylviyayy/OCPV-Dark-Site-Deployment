# Kickstart Procedure

Bootstrap a dark site from an **empty network** with no DNS, no NTP, and no internet.

## Overview

```
┌─────────────┐     USB/NAS      ┌──────────────┐
│  Staging    │ ──────────────►  │  Dark Site   │
│  Machine    │  RHEL ISO +      │  (empty net) │
│  (internet) │  kickstart +     │              │
│             │  mirror tarball  │              │
└─────────────┘                  └──────────────┘
                                       │
                              ┌────────┴────────┐
                              │ 1. Kickstart    │
                              │    bastion      │
                              │ 2. Kickstart    │
                              │    registry     │
                              │ 3. Copy mirror  │
                              │ 4. MVP DNS/NTP  │
                              └─────────────────┘
```

## Prerequisites (bring to dark site on USB)

| Item | Size (approx) | Source |
|---|---|---|
| RHEL 9 **Binary DVD** ISO (not the Boot ISO, which has no packages) | 10–11 GB | Red Hat Customer Portal |
| Kickstart configs | < 1 MB | `kickstart/` in this repo |
| OCP mirror tarball | 60–80 GB | `scripts/01-mirror-preparation.sh` on staging |
| This repository | < 5 MB | `git clone` or USB copy |
| Pull secret | < 1 KB | console.redhat.com |

## Step 1 — Prepare boot media on staging machine

```bash
# On staging machine (has internet)
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment
cp .env.example .env
# Edit .env with your site values
vi .env

# Download and mirror OCP artifacts
./scripts/01-mirror-preparation.sh

# Create tarball for transport
tar czf /tmp/ocp-mirror.tar.gz -C /opt ocp-mirror
```

Copy to USB/NAS:
- RHEL 9 ISO
- `ocp-mirror.tar.gz`
- This repo
- `pull-secret.json`

## Step 2 — Boot bastion from RHEL ISO

### Option A: USB boot + kickstart (**preferred**)

Beginner detail: [labs/detail/bastion-and-registry-usb.md](labs/detail/bastion-and-registry-usb.md).

1. Write RHEL ISO to USB: `dd if=rhel-9-or-10.iso of=/dev/sdX bs=4M status=progress oflag=sync` (check `lsblk` first)
2. Edit Kickstart with `vim kickstart/ks-bastion.cfg` (passwords, SSH key, NIC, IP)
3. Copy Kickstart to USB; boot bastion from USB
4. At the boot prompt, append for example:

```
inst.ks=hd:sdb1:/ks-bastion.cfg
```

Fedora laptop / RHEL 10 KVM: attach the RHEL ISO as virtual media to a VM instead of physical USB — still not PXE.

### Option B: PXE boot (optional only)

**Not recommended** for greenfield dark sites (needs DHCP/TFTP first).  
**Never** used for OpenShift cluster nodes in this repo (those use Agent ISO + BMC).  
See [kickstart/README.md](../kickstart/README.md) only if you already have PXE infrastructure.

### What the bastion kickstart does

- Installs RHEL 9 minimal
- Sets static IP `10.10.0.5` on `ens192`
- Configures `/etc/hosts` with all cluster hostnames (no DNS needed)
- Installs packages from the RHEL DVD: `git`, `jq`, `podman`, `skopeo`, `nmstate` (provides `nmstatectl`)
- Does **not** install `oc`. The OpenShift CLIs come from tarballs on the USB data drive ([USB Transfer Kit](USB-TRANSFER-KIT.md))
- Creates `installer` user with SSH key
- Enables `chronyd` as local NTP server (orphan mode — no upstream)
- Installs `dnsmasq` (disabled until Phase 2 script runs)

## Step 3 — Boot mirror registry host

Repeat Step 2 using `kickstart/ks-registry-mirror.cfg`:

- Static IP `10.10.0.10`
- Installs `podman`, `skopeo`, `httpd` (for serving CA cert)
- Prepares `/opt/registry` directory

## Step 4 — Copy mirror artifacts to dark site

On the bastion, after both hosts are up:

```bash
# Mount USB / NAS
mount /dev/sdb1 /mnt/usb

# Extract mirror to registry host
scp /mnt/usb/ocp-mirror.tar.gz root@10.10.0.10:/tmp/
ssh root@10.10.0.10 "tar xzf /tmp/ocp-mirror.tar.gz -C /opt && rm /tmp/ocp-mirror.tar.gz"

# Copy repo and pull secret to bastion
cp -r /mnt/usb/OCPV-Dark-Site-Deployment /home/installer/
cp /mnt/usb/pull-secret.json /opt/ocp-mirror/pull-secret.json
```

## Step 5 — Load mirror into local registry

On the registry host (`10.10.0.10`):

```bash
# Start local registry
./scripts/04-mirror-ocp-images.sh --load-only
```

This loads all mirrored images into the local `podman` registry at `:5000`.

## Step 6 — Bootstrap MVP DNS/NTP

On the bastion (`10.10.0.5`):

```bash
cd /home/installer/OCPV-Dark-Site-Deployment
cp .env.example .env
vi .env   # confirm IPs match your site
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

Verify:

```bash
dig @10.10.0.5 registry.ocp-v.local
chronyc -h 10.10.0.5 tracking
```

## Step 7 — Distribute /etc/hosts to all future nodes

Every node that will join the cluster **must** resolve names before DNS is fully operational. Two options:

### Option A: Static hosts file (recommended for install)

```bash
# On bastion — generate and copy
./scripts/02-bootstrap-dns-ntp.sh --export-hosts > /tmp/cluster-hosts
scp /tmp/cluster-hosts root@10.10.1.11:/etc/hosts.extra
```

### Option B: Point all nodes to bastion DNS

Set `nameserver 10.10.0.5` in each node's network config. The dnsmasq instance serves all records from `/etc/dnsmasq.d/ocp-v.conf`.

## Step 8 — Proceed to OpenShift install

With DNS and NTP operational on the bastion:

```bash
./scripts/03-generate-install-config.sh
./scripts/05-install-ocp-disconnected.sh
```

→ Continue to [Offline Installer Guide](04-offline-installer-guide.md)

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Kickstart can't find `inst.ks` | Wrong USB device/partition | Check `blkid`, adjust `hd:sdb1` |
| No network after install | Wrong NIC name | Edit kickstart `network --device=` to match `ip link` |
| `chronyd` not serving time | Firewall blocking UDP 123 | `firewall-cmd --add-service=ntp` |
| Nodes can't resolve names | dnsmasq not running | `systemctl status dnsmasq`, check `/etc/dnsmasq.d/` |
| Registry TLS errors | Self-signed CA not trusted | Copy CA cert: `curl -k https://10.10.0.10:5000/v2/` then trust CA |

## Next Steps

→ [Offline Installer Guide](04-offline-installer-guide.md)
