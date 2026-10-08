# Kickstart Files

RHEL Kickstart configurations for bootstrapping a dark site with no DNS, NTP, or internet.

**Preferred boot method: RHEL USB (or KVM ISO attach).**  
PXE is documented only as an optional advanced path if you already have DHCP/TFTP — it is **not** required and is **not** used for OpenShift cluster nodes.

Beginner walkthrough: [docs/labs/04-bastion-and-registry-usb.md](../docs/labs/04-bastion-and-registry-usb.md)

## Files

| File | Target Host | IP | Purpose |
|---|---|---|---|
| `ks-bastion.cfg` | Bastion | `10.10.0.5` | Installer workstation, MVP DNS/NTP |
| `ks-registry-mirror.cfg` | Registry | `10.10.0.10` | Local container mirror registry |

## Before Use

Edit with **`vim`**:

```bash
vim kickstart/ks-bastion.cfg
vim kickstart/ks-registry-mirror.cfg
```

1. **Change passwords** — replace `changeme-rootpw` and `changeme-installer`  
2. **Add your SSH key** — replace the placeholder `ssh-rsa AAAAB3...` key  
3. **Verify NIC name** — change `ens192` if `ip link` shows a different name  
4. **Adjust IPs** — must match `BASTION_IP` / `MIRROR_REGISTRY_IP` in `.env`  

## Boot Methods

### USB Boot (preferred)

```bash
# Identify the USB device first — do not wipe the wrong disk
lsblk

sudo dd if=rhel-9-or-10-x86_64-dvd.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Copy kickstart onto a mountable USB filesystem when available
sudo cp ks-bastion.cfg /mnt/usb/

# Boot target server from USB; at the boot prompt append, for example:
#   inst.ks=hd:sdb1:/ks-bastion.cfg
```

On **Fedora / RHEL 10 KVM**, attach the RHEL ISO (and Kickstart file if needed) as virtual CD/USB in virt-manager — still no PXE.

### PXE Boot (optional — not recommended for greenfield)

Only if you already operate DHCP + TFTP. This path is **not** used for OpenShift nodes (those boot the Agent ISO via BMC). See historical snippet below only if you need it:

```
# /var/lib/tftpboot/pxelinux.cfg/default  (optional advanced)
DEFAULT linux
LABEL linux
  KERNEL vmlinuz
  APPEND initrd=initrd.img inst.ks=http://10.10.0.5/kickstart/ks-bastion.cfg
```

## Boot Order

1. **Bastion first** — temp DNS/NTP live here  
2. **Registry second** — load mirrored images  
3. **OpenShift nodes** — Agent discovery ISO via BMC (**not** Kickstart, **not** PXE)  

## Post-Kickstart

Continue with [docs/labs/05-mvp-dns-ntp.md](../docs/labs/05-mvp-dns-ntp.md) or [docs/03-kickstart-procedure.md](../docs/03-kickstart-procedure.md) Step 4.
