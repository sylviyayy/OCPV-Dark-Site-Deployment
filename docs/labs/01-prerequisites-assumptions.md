# 01 — Prerequisites and Assumptions

## Goal

Confirm accounts, tooling, and scope before touching hardware.

## WHERE

Your admin workstation (Fedora laptop or RHEL 10 KVM jumpbox candidate).

## WHY

Disconnected installs fail for boring reasons: missing pull secret, wrong ISO, or
assuming VMware DNS still exists. This lab locks scope.

## Assumptions (this tutorial)

| Assumption | Detail |
|---|---|
| Field | Greenfield **cluster** (customer may be exiting VMware — see [appendix](../greenfield/appendix-brownfield-contrast.md)) |
| Network | Shared install network; start flat L2 unless worksheet says otherwise |
| Internet on cluster VLAN | None during install |
| DNS / NTP at day zero | None — you build MVP on the jumpbox |
| Installer | Agent-based Installer + oc-mirror v2 |
| OpenShift | 4.22 (`stable-4.22`) |
| Hardware | 2× SR665 V3 + 1× SR675 V3 (see [Lab 05](05-compute-resources.md)) |
| Jumpbox OS | RHEL 9/10, Fedora, or CentOS Stream for learning |

## DO — checklist

1. Red Hat account + [pull secret](https://console.redhat.com/openshift/install/pull-secret) → save as `pull-secret.json` (**never commit**)  
2. RHEL DVD/USB ISO for jumpbox/registry Kickstart (if installing helpers from USB)  
3. USB / portable disk large enough for the mirror (often 80–150 GB)  
4. BMC access to all three Lenovo servers  
5. Tools on the jumpbox candidate:

```bash
sudo dnf install -y git vim jq curl podman
which vim git curl jq
```

```bash
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment
cp .env.example .env
```

## VERIFY

- [ ] `pull-secret.json` opens and contains `"auths"`  
- [ ] You can reach BMC IPs from your admin browser (or will after Lab 05 cabling)  
- [ ] You know jumpbox will be physical USB install **or** Fedora/RHEL KVM VM  

## FAILS IF

| Missing | Later failure |
|---|---|
| Pull secret | `oc mirror` cannot authenticate |
| No BMC plan | Cannot mount Agent ISO |
| Assumed enterprise DNS | Wrong lab path — re-read [appendix](../greenfield/appendix-brownfield-contrast.md) |

## Next

→ [02 — Architecture Overview and Network Design](02-architecture-network-design.md)

**Deeper reading:** [greenfield/00-assumptions-and-scope.md](../greenfield/00-assumptions-and-scope.md)
