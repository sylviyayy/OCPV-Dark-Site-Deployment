# 01 — Prerequisites

## Goal

Confirm you have accounts, media, and machines before editing configs.

## WHERE

Your desk — no cluster commands yet.

## WHY this lab exists

Disconnected installs fail for boring reasons: missing pull secret, wrong architecture ISO, or no USB large enough for the mirror. Catch that now.

## DO — accounts and downloads checklist

1. **Red Hat account** with OpenShift entitlement  
   - Pull secret: https://console.redhat.com/openshift/install/pull-secret  
   - Save as a file named `pull-secret.json` (you will copy it later — **never commit it to git**)

2. **RHEL 9 or 10 DVD/USB ISO** for bastion/registry Kickstart  
   - From Red Hat Customer Portal (subscription required)

3. **Staging machine** (pick one):
   - **Fedora laptop** with internet, or  
   - **RHEL 10 KVM VM** with internet and ≥ 200 GB free disk for the mirror workspace

4. **USB / portable disk** large enough for the mirror (often 80–150 GB depending on ImageSet)

5. **Cluster hardware or VMs** matching your track:
   - Track A: physical servers + BMC access  
   - Track C / practice: enough VMs for 3 control plane + 2 workers (or compact/SNO)

6. Tools on staging (install if missing):

```bash
# Fedora example
sudo dnf install -y git vim jq curl podman

# Confirm editors and shell basics
which vim git curl jq
```

## WHY `vim` not `vi`

This guide always uses **`vim`**. `vi` on some systems is a minimal binary without the habits most people expect. Install `vim` if `which vim` fails.

## VERIFY

- [ ] You can open `pull-secret.json` and see JSON with `auths`  
- [ ] Staging has internet (`curl -I https://mirror.openshift.com` returns a response)  
- [ ] You know whether bastion will be a bare-metal RHEL USB install or a RHEL VM you create yourself  

## FAILS IF

| Missing | What breaks later |
|---|---|
| Pull secret | `oc mirror` cannot authenticate to Red Hat |
| Small USB | Cannot transport mirror into dark site |
| No BMC plan on bare metal | Cannot mount agent ISO on nodes |

## Next

→ [02 — Configure `.env`](02-configure-site-env.md)
