# Labs — OpenShift Virtualization the Explicit Way

This tutorial walks you through a **greenfield, disconnected** OpenShift Virtualization
install step by step. It is optimized for **learning**: every lab explains *where* you
are, *what* you type, and *why* that step exists.

Inspired by the structure of
[Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
(numbered labs, prerequisites first, verify before moving on).

> **Not a black box.** Scripts in `scripts/` are helpers. These labs tell you what they
> do and what you must edit by hand (especially `.env`).

---

## Who this is for

Someone who has never installed OpenShift or Kubernetes before, but can:

- open a terminal
- edit a text file with `vim`
- plug in a USB stick or use a laptop as a temporary helper machine

---

## Boot methods we use (and do not use)

| Machine | How you install / boot it | PXE? |
|---|---|---|
| Staging (mirror download) | Fedora laptop **or** RHEL 10 KVM VM with internet | No |
| Bastion / registry (RHEL) | **RHEL USB + Kickstart** (preferred) | No |
| OpenShift cluster nodes | Agent discovery ISO via **BMC virtual CD** | No |

**PXE is not part of this path.** Ignore PXE notes elsewhere unless you already run DHCP/TFTP.

---

## Lab list (do in order)

| Lab | Title |
|---|---|
| 00 | [Overview and mental model](00-overview.md) |
| 01 | [Prerequisites](01-prerequisites.md) |
| 02 | [Configure `.env` (what to edit)](02-configure-site-env.md) |
| 03 | [Staging: download tools and mirror images](03-staging-mirror.md) |
| 04 | [Bastion and registry via RHEL USB](04-bastion-and-registry-usb.md) |
| 05 | [MVP DNS and NTP on the bastion](05-mvp-dns-ntp.md) |
| 06 | [Generate agent configs and the discovery ISO](06-agent-config-and-iso.md) |
| 07 | [Boot cluster nodes from the ISO (BMC)](07-boot-nodes-bmc.md) |
| 08 | [Finish install and connect OperatorHub to the mirror](08-install-and-mirror-integration.md) |
| 09 | [Install OpenShift Virtualization](09-openshift-virtualization.md) |
| 10 | [Production DNS/NTP VMs on OCP-V](10-production-dns-ntp.md) |
| 11 | [Smoke test and sign-off](11-smoke-test.md) |

Partner / rack planning (cabling, switches, SAN) still lives under
[`docs/GREENFIELD-README.md`](../GREENFIELD-README.md). Complete the
[worksheet](../greenfield/01-information-gathering-worksheet.md) before Lab 02 if you
are on real hardware.

---

## Conventions used in every lab

```text
WHERE:   which machine you type on
WHY:     why this step exists
DO:      exact commands (use vim, not vi)
VERIFY:  how you know it worked
FAILS IF: what breaks if you skip or get it wrong
```
