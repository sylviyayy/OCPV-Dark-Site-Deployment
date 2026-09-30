# 04 — Bastion and Registry via RHEL USB

## Goal

Install the helper machines **without PXE**, using RHEL USB + Kickstart (or an equivalent RHEL VM you create on Fedora/RHEL KVM).

## WHERE

- Physical servers: console or BMC virtual media with RHEL ISO  
- Or: create RHEL VMs on your Fedora / RHEL 10 KVM host and treat them as bastion/registry  

## WHY this lab exists

You need:

1. **Bastion** — place to run `openshift-install` and temporary DNS/NTP  
2. **Registry** — place that serves mirrored container images  

Kickstart makes those installs repeatable. **USB** (or KVM ISO attach) avoids inventing DHCP/PXE on an empty network.

## Preferred path A — Physical RHEL USB + Kickstart

### DO — prepare USB

On staging (or any Linux box):

```bash
# WARNING: of= must be your USB disk, not a real hard drive. Check with lsblk first.
lsblk
sudo dd if=/path/to/rhel-9-or-10-x86_64-dvd.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Copy Kickstart to the USB filesystem (mount the USB partition that is writable, often the data partition after hybrid ISO — if that is awkward, serve `ks-*.cfg` from a second small USB or paste at boot):

```bash
# Example if you have a second FAT USB mounted at /mnt/usb
sudo cp kickstart/ks-bastion.cfg /mnt/usb/
sudo cp kickstart/ks-registry-mirror.cfg /mnt/usb/
```

**Before first use, edit Kickstart files** (passwords, SSH key, NIC name, IPs) to match `.env`:

```bash
vim kickstart/ks-bastion.cfg
vim kickstart/ks-registry-mirror.cfg
```

Change at least:

| Kickstart setting | Must match |
|---|---|
| `network --ip=...` | `BASTION_IP` / `MIRROR_REGISTRY_IP` |
| `network --device=...` | Real NIC (`NETWORK_INTERFACE`) |
| `rootpw` / user password | Something you know (not `changeme-*` in production) |
| `sshkey` | Your real public key |

### DO — boot bastion from USB

1. Boot the bastion server from the RHEL USB  
2. At the boot prompt, start Kickstart from USB, for example:

```text
inst.ks=hd:sdb1:/ks-bastion.cfg
```

(Adjust `sdb1` if your USB shows as `sda`/`sdc` — check the boot help screen.)

### WHY bastion first

Registry host NTP/DNS can point at the bastion. Bastion is the temporary “mini IT” box.

### DO — boot registry host

Same process with `ks-registry-mirror.cfg` and `MIRROR_REGISTRY_IP`.

## Preferred path B — Fedora laptop / RHEL 10 KVM (no bare-metal USB)

If you are learning on one hypervisor host:

1. Create two RHEL VMs (or one combined) with static IPs from `.env`  
2. Attach the RHEL ISO in virt-manager / `virt-install`  
3. Either run interactive minimal install **or** attach Kickstart as a second CD/USB  

**WHY this is OK for learning:** Same software roles (bastion/registry). For Lenovo customer delivery, prefer Path A on real servers.

You still **do not need PXE**.

## DO — copy mirror archive into the dark site

On bastion (after install), with USB mounted:

```bash
sudo mkdir -p /opt
sudo tar -xzf /mnt/usb/ocp-mirror.tar.gz -C /opt
# Ensure clients are on PATH for later labs
export PATH="/opt/ocp-mirror/clients:${PATH}"
oc version || /opt/ocp-mirror/clients/oc version
```

Copy this git repo onto the bastion as well (USB or `scp`).

## DO — load images into the registry

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
./scripts/04-mirror-ocp-images.sh disk-to-mirror
```

**WHY:** Unpacks the staging tarball into a registry the cluster can pull from. Until this succeeds, Agent install will starve for images.

## VERIFY

```bash
ping -c1 "${BASTION_IP}"
ping -c1 "${MIRROR_REGISTRY_IP}"
curl -sk "https://${MIRROR_REGISTRY}/v2/" && echo "registry API reachable"
```

## FAILS IF

| Problem | Result |
|---|---|
| Kickstart NIC name wrong | Machine installs with no network |
| Skipped registry load | Later: mass `ImagePullBackOff` |
| Used PXE without DHCP | Boot never starts — stick to USB/ISO attach |

## Next

→ [05 — MVP DNS and NTP](05-mvp-dns-ntp.md)
