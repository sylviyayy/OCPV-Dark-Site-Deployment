# Kickstart Files

RHEL 9 kickstart configurations for bootstrapping a dark site with no DNS, NTP, or internet.

## Files

| File | Target Host | IP | Purpose |
|---|---|---|---|
| `ks-bastion.cfg` | Bastion | `10.10.0.5` | Installer workstation, MVP DNS/NTP |
| `ks-registry-mirror.cfg` | Registry | `10.10.0.10` | Local container mirror registry |

## Before Use

1. **Change passwords** — replace `changeme-rootpw` and `changeme-installer`
2. **Add your SSH key** — replace the placeholder `ssh-rsa AAAAB3...` key
3. **Verify NIC name** — change `ens192` if your hardware uses a different interface name
4. **Adjust IPs** — if your `.env` uses different addresses, update the kickstart files to match

## Boot Methods

### USB Boot

```bash
# Write RHEL 9 ISO to USB
dd if=rhel-9.x-x86_64-dvd.iso of=/dev/sdX bs=4M status=progress

# Copy kickstart to USB root partition
mount /dev/sdX1 /mnt
cp ks-bastion.cfg /mnt/
umount /mnt

# Boot target server, at GRUB prompt append:
inst.ks=hd:sdb1:/ks-bastion.cfg
```

### PXE Boot (optional)

If you have a temporary DHCP/TFTP server on the staging network:

```
# /var/lib/tftpboot/pxelinux.cfg/default
DEFAULT linux
LABEL linux
  KERNEL vmlinuz
  APPEND initrd=initrd.img inst.ks=http://10.10.0.5/kickstart/ks-bastion.cfg
```

Serve kickstart files via HTTP on the bastion after initial boot, or include them in the PXE server's HTTP root.

## Boot Order

1. **Bastion first** — needed for DNS/NTP that the registry host depends on
2. **Registry second** — loads mirrored images after bastion DNS is running
3. **OCP nodes** — boot from agent discovery ISO (generated later)

## Post-Kickstart

After both hosts are up, proceed to [docs/03-kickstart-procedure.md](../docs/03-kickstart-procedure.md) Step 4.
