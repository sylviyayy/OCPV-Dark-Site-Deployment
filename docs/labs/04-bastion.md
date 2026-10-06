# 04 — Setting up the Bastion

> **Grade:** production-grade pattern. A permanent physical RHEL 9 bastion that never touches the
> internet is what a regulated dark site expects; it outlives the install as the secondary DNS
> and NTP source (ADR-02, ADR-07).

## Goal

Build the bastion — and, if your registry is a separate host, the registry host — from the
RHEL 9 DVD alone, unattended, with every site value taken from `.env`.

## Two machines, two roles

| | Staging host (low side) | Bastion (high side) |
|---|---|---|
| Network | Internet; **never** the machine network | Machine network; **never** the internet |
| Runs | `scripts/01`, `render-kickstart.sh`, `mkksiso` | `scripts/02`–`08`, `openshift-install`, dnsmasq, chrony, httpd |
| Lifetime | Until media leave it | Life of the site |

No host in these labs is placed on both networks. Moving one laptop from the internet into the
enclave breaks most regulated air gaps (FR-B8).

## Steps

### 4.1 Render the bastion kickstart

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Anaconda reads its network, user and package list from the kickstart, so rendering it
from `.env` makes the bastion's address, NIC name, domain and `/etc/hosts` identical to what the
DNS records and install configs will say. The `installer` password is prompted and stored only as
a SHA-512 hash; `root` is locked. Consumed by: Anaconda on the bastion (step 4.3).
If skipped: a hand-edited kickstart drifts from `.env` and the registry name resolves to the wrong address in Lab 06.

**EDIT** — No edits in this step. (Values come from `.env` D1, D2, D3, D5, B1, B2, F2.)

**DO**

```bash
./scripts/render-kickstart.sh bastion
```

**VERIFY**

```bash
grep -c -- '--plaintext' "${INSTALL_DIR}/kickstart/ks-bastion.cfg"           # expect: 0
grep -o -- "--device=[^ ]*" "${INSTALL_DIR}/kickstart/ks-bastion.cfg"        # expect: --device=<BASTION_IFNAME>
stat -c %a "${INSTALL_DIR}/kickstart/ks-bastion.cfg"                         # expect: 600
```

Run `set -a && source .env && set +a` first so `${INSTALL_DIR}` resolves in your shell.

**FAILS IF** — `ksvalidator` reports an error ← a template edit broke kickstart syntax; fix the template, never the rendered file.

### 4.2 Build one ISO that boots from USB or virtual media

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `mkksiso` rebuilds the DVD with the kickstart embedded and the boot menu pointing at
it, so the install needs zero keystrokes. A `dd`-written hybrid DVD leaves no writable partition
for a kickstart, and the boot-prompt device name (`hd:sdb1`) is unpredictable. `--add` also places
this repository (with your `.env`) on the medium for the bastion to copy (FR-E2, FR-E6).
Consumed by: the bastion's firmware (step 4.3). If skipped: you type boot options by hand and guess device names.

**EDIT** — No edits in this step.

**DO**

```bash
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-bastion.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/bastion-ks.iso"
```

**VERIFY**

```bash
ls -lh "${INSTALL_DIR}/kickstart/bastion-ks.iso"        # expect: a file ~ the DVD size
```

**FAILS IF** — `mkksiso: command not found` ← `lorax` missing (Lab 01 step 1.2).

### 4.3 Install the bastion

**WHERE** — Bastion server console: XCC remote console with virtual media, or a USB port

**WHY** — Booting the embedded ISO runs Anaconda unattended from the DVD's own repositories, so
the bastion needs no network repository and no internet. Consumed by: every later lab.
If skipped: there is no host to run DNS, NTP or the installer on the high side.

**EDIT** — No edits in this step.

**DO** — Either mount `bastion-ks.iso` as XCC virtual media and boot once from it, or write it
to USB on the staging host and boot from the stick:

```bash
lsblk                                   # identify the USB stick; of= must not be a real disk
sudo dd if="${INSTALL_DIR}/kickstart/bastion-ks.iso" of=/dev/sdX bs=4M status=progress oflag=sync
```

The installer reboots into RHEL 9 when done. Log in from the admin workstation:
`ssh installer@<BASTION_IP>` with the private key matching `SSH_PUBLIC_KEY_FILE`.

**VERIFY** — See 4.4.

**FAILS IF** — The install stops at "Installation source" ← the ISO was written to a partition (`/dev/sdX1`) instead of the device.

### 4.4 Verify the bastion

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Each check falsifies one assumption from Lab 01 on the machine itself.
Consumed by: Labs 06–16. If skipped: a wrong NIC or a missing package surfaces mid-lab.

**EDIT** — No edits in this step.

**DO**

```bash
cd ~/OCPV-Dark-Site-Deployment && set -a && source .env && set +a
```

**VERIFY**

```bash
grep -q '^VERSION_ID="9\.' /etc/os-release && echo rhel9                     # expect: rhel9
ip -br addr show "${BASTION_IFNAME}" | grep -c "${BASTION_IP}/"               # expect: 1
rpm -q dnsmasq chrony podman nmstate httpd python3-pyyaml | grep -c 'not installed'   # expect: 0
curl -m 5 -sS -o /dev/null https://quay.io && echo ONLINE || echo air-gapped  # expect: air-gapped
test -O /opt/ocp-mirror && echo owned                                         # expect: owned
```

**FAILS IF** — `ONLINE` ← the machine network routes to the internet; stop and fix routing before
any image crosses. `0` addresses on `BASTION_IFNAME` ← D2 is wrong; re-render and reinstall.

### 4.5 Registry host (only if `MIRROR_REGISTRY_IP` ≠ `BASTION_IP`)

**WHERE** — Staging host (render, build), then the registry server's console

**WHY** — The registry kickstart opens only SSH and `MIRROR_REGISTRY_PORT` and carries no
certificate of its own: mirror registry for Red Hat OpenShift issues and serves its own CA (FR-C3).
Consumed by: Lab 06 step 6.6. If skipped (when separate): the registry has no host.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/render-kickstart.sh registry
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-registry.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/registry-ks.iso"
```

Boot it exactly as in 4.3.

**VERIFY** — On the registry host:
`sudo firewall-cmd --list-ports` → expect: `8443/tcp` (your `MIRROR_REGISTRY_PORT`).

**FAILS IF** — The port list is empty ← the host was installed from an older kickstart.

Detail and troubleshooting: [bastion and registry media](detail/bastion-and-registry-usb.md).

## Next

→ [05 — Provisioning Compute Resources](05-compute-resources.md)
