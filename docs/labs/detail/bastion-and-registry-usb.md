# Bastion and registry media (detail)

> Canonical lab: [04 — Setting up the Bastion](../04-bastion.md). This page explains the
> mechanism and the failure modes.

## Why one embedded ISO, not "DVD on USB plus a kickstart file"

The old path wrote the RHEL DVD to USB with `dd`, copied the kickstart to "a mountable USB
filesystem", and asked you to type `inst.ks=hd:sdb1:/ks-bastion.cfg` at the boot prompt. Two
problems: a `dd`-written hybrid ISO leaves no writable partition for the kickstart, and the device
name of the stick at install time is unpredictable. `mkksiso` (package `lorax`) solves both:

- it copies the kickstart **into** the ISO and rewrites the boot menu to use it, so the install
  needs zero keystrokes;
- `--add <dir>` puts extra content (this repository) on the medium;
- the result boots identically from USB or from XCC virtual media.

```bash
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-bastion.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/bastion-ks.iso"
```

## What the bastion kickstart does

| Kickstart setting | Value | Why |
|---|---|---|
| `cdrom` | the embedded DVD | no network repository exists in a dark site |
| `network` | `BASTION_IFNAME`, `BASTION_IP`, netmask from `MACHINE_NETWORK_CIDR`, gateway, `--nameserver=BASTION_IP` | its own dnsmasq answers it after Lab 07 (FR-E5) |
| `firewall` | SSH, DNS, NTP | declarative: `firewall-cmd` cannot run inside `%post` |
| `rootpw --lock`, `user … --iscrypted` | SHA-512 hash from a prompted password | no plaintext in any file (FR-E3) |
| `%packages` | dnsmasq, chrony, podman, nmstate, httpd, python3-pyyaml, … | all on the DVD; `openshift-clients` is not, so it is gone (FR-E1) |
| `%post --nochroot` | copies the repo from the install medium | a chrooted `%post` cannot see the medium (FR-E6) |
| `%post` | `/etc/hosts` for bastion and registry; `/opt/ocp-mirror` owned by `installer` | the registry must resolve in Lab 06, before dnsmasq starts in Lab 07 |

## Writing the USB stick

```bash
lsblk                       # find the stick by size and model; of= must be the whole device
sudo dd if="${INSTALL_DIR}/kickstart/bastion-ks.iso" of=/dev/sdX bs=4M status=progress oflag=sync
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Installer stops at the summary screen | a kickstart value is invalid | run `ksvalidator -v RHEL9` on the rendered file; fix `.env` or the template, re-render |
| No network after install | `BASTION_IFNAME` is wrong | read the name with `ip -br link` in a rescue shell; fix D2; re-render; reinstall |
| Repo missing in `/home/installer` | `--add` omitted, or the medium mounted elsewhere | copy `repo.tar.gz` from the transfer media (Lab 06 step 6.4) |
| Installer asks which disk to use | more disks than expected | detach data disks you want to keep; `clearpart --all` wipes every visible disk |

## Next

→ [Lab 04](../04-bastion.md) · [Lab 06 — high-side intake](../06-mirroring-images.md)
