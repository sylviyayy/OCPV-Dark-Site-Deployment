# 04 — Setting up the Bastion

## Goal

Build the **bastion**: the machine that runs mirroring tools (when online),
`openshift-install`, and temporary DNS/NTP.

## WHERE

One of:

- Fedora laptop on the install VLAN (and internet when mirroring), or  
- RHEL 9 KVM VM, or  
- Physical RHEL host installed with **USB + Kickstart** (preferred for rack delivery)

## WHY

This tutorial standardizes on the name **bastion**. It is the temporary DNS/NTP server
since we are deploying this OpenShift cluster from scratch (greenfield).

The bastion is **temporary**. It receives the USB drive, runs DNS/NTP and the installer,
acts as the **secondary** DNS/NTP during cutover, and is then disconnected. Plan for that
from the start, and keep the mirror registry on a separate host:
[Bastion Lifecycle](../BASTION-LIFECYCLE.md). The drive's contents are listed in the
[USB Transfer Kit](../USB-TRANSFER-KIT.md).

**PXE is not required.** Use USB or KVM virtual CD.

## DO — path A: Fedora / RHEL KVM

```bash
sudo dnf install -y git vim jq curl podman
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment
# .env already filled in Lab 03
sudo mkdir -p /opt/ocp-mirror
sudo cp /path/to/pull-secret.json /opt/ocp-mirror/pull-secret.json
sudo chown "$USER:$USER" /opt/ocp-mirror/pull-secret.json
```

Give the VM a static IP = `BASTION_IP` from `.env` on the install network.

## DO — path B: Physical RHEL USB + Kickstart

Follow the detailed USB steps:

→ [bastion-and-registry-usb (detail)](detail/bastion-and-registry-usb.md)

Edit Kickstart first:

```bash
vim kickstart/ks-bastion.cfg
# passwords, ssh key, NIC name, IP = BASTION_IP
```

If registry is a second host, also prepare `ks-registry-mirror.cfg`.  
In a small lab, registry may co-locate on the bastion.

## VERIFY

```bash
hostname
ip -br a
ping -c1 "${NETWORK_GATEWAY}"
which vim git
test -f /opt/ocp-mirror/pull-secret.json && echo pull-secret-ok
```

## FAILS IF

| Problem | Result |
|---|---|
| Bastion not on install VLAN | Cannot serve DNS or reach nodes |
| No pull secret | Lab 06 fails |

## Next

→ [05 — Provisioning Compute Resources](05-compute-resources.md)
