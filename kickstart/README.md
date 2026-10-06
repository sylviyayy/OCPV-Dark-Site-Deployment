# Kickstart templates

Unattended RHEL 9 installs for the two helper hosts, from the RHEL 9 DVD alone.
Cluster nodes never use these: they boot the Agent ISO through XCC virtual media (ADR-04).

| Template | Host | Rendered to |
|---|---|---|
| `ks-bastion.cfg.template` | Bastion — permanent DNS/NTP/DVD-repo host, runs `openshift-install` | `${INSTALL_DIR}/kickstart/ks-bastion.cfg` |
| `ks-registry.cfg.template` | Mirror registry host — only when it does not share the bastion | `${INSTALL_DIR}/kickstart/ks-registry.cfg` |

Walkthrough: [Lab 04 — Setting up the Bastion](../docs/labs/04-bastion.md) ·
detail: [bastion-and-registry-usb](../docs/labs/detail/bastion-and-registry-usb.md).

## You edit `.env`, never the kickstart

`scripts/render-kickstart.sh` fills IPs, `BASTION_IFNAME`, domain, SSH key and `/etc/hosts`
from `.env`, and prompts for the `installer` password, which it stores only as a SHA-512
crypt hash (`openssl passwd -6`). `root` is locked. Rendered files carry that hash, so they
are written outside the repo with mode 600.

```bash
# Low-side staging host (RHEL 9), as your user
./scripts/render-kickstart.sh bastion
```

## One ISO that boots from USB or virtual media

`mkksiso` (package `lorax`) rebuilds the DVD with the kickstart embedded and the boot menu
pointing at it, so the install needs zero keystrokes and no guessing of `inst.ks=hd:sdb1`.
`--add` also places this repository on the medium; the kickstart copies it to
`/home/installer/` (FR-E6).

```bash
sudo dnf install -y lorax
mkksiso --ks "${INSTALL_DIR}/kickstart/ks-bastion.cfg" --add ~/OCPV-Dark-Site-Deployment \
  ~/Downloads/rhel-9.x-x86_64-dvd.iso "${INSTALL_DIR}/kickstart/bastion-ks.iso"
```

Write `bastion-ks.iso` to a USB stick (`dd … oflag=sync`) **or** mount it as XCC virtual media.
Same file, both paths.

## Boot order

1. **Bastion** — every later step resolves names and takes time from it.
2. **Registry host** (if separate) — Lab 06 installs mirror registry for Red Hat OpenShift on it.
3. **Cluster nodes** — Agent ISO via XCC virtual media (Lab 10).

Network boot is out of scope; see the [network-boot appendix](../docs/labs/appendix-b-network-boot.md).

## After the install

Continue with [Lab 06 — Mirroring Images](../docs/labs/06-mirroring-images.md) (high-side intake),
then [Lab 07 — MVP DNS and NTP](../docs/labs/07-mvp-dns-ntp.md).
