# Kickstart Procedure

> **Non-normative reference (ADR-01).** Background kept from v1. The normative procedure is
> [Lab 04 — Setting up the Bastion](../labs/04-bastion.md); where this page and a lab disagree, the lab wins.

## Why kickstart, and why embedded in the ISO

The bastion and registry host must install from an **empty network**: no DNS, no NTP, no
repository, no internet. A kickstart makes the install repeatable and reviewable; embedding it
into the RHEL 9 DVD with `mkksiso` makes it unattended and removes two failure points of the old
"DVD on USB plus a kickstart file plus a typed `inst.ks=` argument" method: no writable partition
on a `dd`-written hybrid ISO, and an unpredictable device name at the boot prompt.

```text
Staging host (low side)                       Bastion server
  .env ──render-kickstart.sh──► ks-bastion.cfg
  RHEL 9 DVD + ks + repo ──mkksiso──► bastion-ks.iso ──USB or XCC virtual media──► unattended install
```

## What changed from v1

| v1 | v2 | Why |
|---|---|---|
| `ks-*.cfg` edited by hand | `kickstart/*.cfg.template` rendered from `.env` | the `/etc/hosts` block silently disagreed with an edited `.env` |
| plaintext `rootpw` and `user` passwords | `rootpw --lock`; hashed `installer` password | plaintext passwords in a public repository |
| `openshift-clients` in `%packages` | removed | not on the RHEL DVD; Anaconda stopped |
| `--nameserver=127.0.0.1` | `--nameserver=<BASTION_IP>`; dnsmasq binds both | dnsmasq listened only on the bastion IP |
| `firewall-cmd` in `%post` | `firewall` kickstart command | firewalld is not running in `%post` |
| registry host self-signed certificate | none | mirror-registry generates and serves its own CA |
| registry port 5000 | `MIRROR_REGISTRY_PORT` (8443) | the tool's default port |
| PXE option | removed (Appendix B) | network boot is out of scope (ADR-04) |

## Boot order

1. **Bastion** — every later step resolves names and takes time from it.
2. **Registry host**, if separate.
3. **Cluster nodes** — Agent ISO via XCC virtual media (Lab 10), never kickstart.

See also: [kickstart/README.md](../../kickstart/README.md) ·
[bastion and registry media (detail)](../labs/detail/bastion-and-registry-usb.md).
