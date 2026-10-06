# 04 — Setting up the Bastion

> **Grade:** production pattern: a permanent physical RHEL 9 bastion that never touches the internet
> and outlives the install as the secondary DNS/NTP source (ADR-02, ADR-07).

## Goal

Install the bastion (and a separate registry host, if you have one) from the RHEL 9 DVD alone,
unattended, with every site value taken from `.env`.

| | Staging host (low side) | Bastion (high side) |
|---|---|---|
| Network | internet; **never** the machine network | machine network; **never** the internet |
| Runs | `scripts/01`, `render-kickstart.sh`, `mkksiso` | `scripts/02`–`08`, `openshift-install`, dnsmasq, chrony, httpd |
| Lifetime | until the media leave it | life of the site |

## Steps

### 4.1 Render the bastion kickstart

**WHERE** — Staging host (low side), RHEL 9.x, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Renders Anaconda's instructions (address, NIC, domain, packages, disk layout) from
`.env`, so the bastion agrees with every later DNS record. The `installer` password is prompted and
stored only as a SHA-512 hash; `root` is locked. `/` gets the whole disk because `/opt/ocp-mirror`
holds the archive, cache and DVD. *If skipped:* a hand-edited kickstart drifts from `.env`.

**EDIT** — None (values from `.env` B1, B2, D1–D5, F2).

**DO**

```bash
./scripts/render-kickstart.sh bastion
```

**VERIFY**

```bash
set -a && source .env && set +a
grep -o -- "--device=[^ ]*" "${INSTALL_DIR}/kickstart/ks-bastion.cfg"   # expect: --device=<BASTION_IFNAME>
stat -c %a "${INSTALL_DIR}/kickstart/ks-bastion.cfg"                    # expect: 600
```

The script also runs `ksvalidator` (RHEL 9 syntax) and stops on any error.

**FAILS IF** — `ksvalidator` errors ← a template edit broke syntax; fix the template, never the rendered file.

### 4.2 Build one ISO for USB or virtual media

**WHERE** — Staging host, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `mkksiso` embeds the kickstart in the DVD and points the boot menu at it: zero keystrokes,
no guessing which device the USB stick will be. `--add` copies this repo (with `.env`) onto the
medium; the kickstart places it in `/home/installer/`.

**EDIT** — None.

**DO**

```bash
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-bastion.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/bastion-ks.iso"
```

**VERIFY** — `ls -lh "${INSTALL_DIR}/kickstart/bastion-ks.iso"` → a file about the DVD's size.

**FAILS IF** — `mkksiso: command not found` ← `lorax` missing (Lab 01 step 1.2).

### 4.3 Install the bastion

**WHERE** — Bastion server: XCC virtual media, or a USB port

**WHY** — Anaconda installs from the DVD's own repositories; no network repo or internet is needed.

**EDIT** — None.

**DO** — Mount `bastion-ks.iso` as XCC virtual media and boot once from it, or write it to USB:

```bash
lsblk     # identify the stick; of= must be the whole device, never a real disk
sudo dd if="${INSTALL_DIR}/kickstart/bastion-ks.iso" of=/dev/sdX bs=4M status=progress oflag=sync
```

Then log in from the admin workstation: `ssh installer@<BASTION_IP>`.

**VERIFY** — Step 4.4.

**FAILS IF** — Install stops at "Installation source" ← written to a partition (`/dev/sdX1`), not the device.

### 4.4 Verify the bastion

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Falsifies the Lab 01 assumptions on the machine itself before anything depends on it.

**EDIT** — None.

**DO / VERIFY**

```bash
set -a && source .env && set +a
grep -q '^VERSION_ID="9\.' /etc/os-release && echo rhel9                                  # expect: rhel9
ip -br addr show "${BASTION_IFNAME}" | grep -c "${BASTION_IP}/"                            # expect: 1
rpm -q dnsmasq chrony podman nmstate httpd python3-pyyaml | grep -c 'not installed'        # expect: 0
curl -m 5 -sS -o /dev/null https://quay.io && echo ONLINE || echo air-gapped               # expect: air-gapped
df -h / | tail -n1                                                                         # expect: / spans the disk
```

**FAILS IF** — `ONLINE` ← the machine network routes out; fix routing before any image crosses.
No address on `BASTION_IFNAME` ← D2 is wrong; fix, re-render, reinstall.

### 4.5 Registry host (only if `MIRROR_REGISTRY_IP` ≠ `BASTION_IP`)

**WHERE** — Staging host, then the registry server

**WHY** — Same unattended install; its firewall opens only SSH and `MIRROR_REGISTRY_PORT`, and it
carries no certificate of its own (mirror-registry issues its CA in Lab 06).

**EDIT** — None.

**DO**

```bash
./scripts/render-kickstart.sh registry
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-registry.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/registry-ks.iso"
```

Boot it as in 4.3.

**VERIFY** — On the registry host: `sudo firewall-cmd --list-ports` → `8443/tcp`.

**FAILS IF** — Port missing ← installed from an old kickstart.

Detail: [bastion and registry media](detail/bastion-and-registry-usb.md).

## Next

→ [05 — Provisioning Compute Resources](05-compute-resources.md)
