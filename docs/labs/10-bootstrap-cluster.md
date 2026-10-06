# 10 — Bootstrapping the Cluster with the Agent-based Installer

## Goal

Boot all three Lenovo nodes from the Agent ISO via BMC and wait until install completes.

## WHERE

- Jumpbox: `install-config/agent.x86_64.iso`  
- Each server XCC: virtual media  

## WHY

This replaces Hard Way’s separate “bootstrap control plane” and “bootstrap workers” labs.
The Agent ISO embeds Assisted Service; nodes self-register using Lab 08 networking.

**Not PXE. Not Kickstart on RHCOS.**

> **[WINDOW A]** Boot every node within **12 hours** of creating the ISO (hard limit 24).
> If you miss it, regenerate both the ISO **and** `auth/` from your config backup. Never mix
> artifacts from two runs.
>
> **[WINDOW B]** After install starts, keep the cluster powered on and the bastion's
> DNS/NTP unchanged for at least 24 hours (first certificate rotation).
> See [Bastion Lifecycle §2](../BASTION-LIFECYCLE.md#2-the-two-24-hour-windows-and-what-is-not-on-a-clock).

## DO — BMC on cp01, cp02, cp03

1. Map `agent.x86_64.iso` as virtual CD  
2. One-time boot from virtual CD  
3. Reboot  

Boot the `RENDEZVOUS_IP` node first if you want a clearer bootstrap path, then the others.

## DO — wait on jumpbox

```bash
export PATH="${MIRROR_DIR}/clients:${PATH}"
./scripts/05-install-ocp-disconnected.sh
# or:
openshift-install agent wait-for install-complete --dir=install-config/ --log-level=info
```

## VERIFY

```bash
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
oc get nodes -o wide
oc get clusterversion
```

## FAILS IF

| Problem | Symptom |
|---|---|
| Wrong MAC | Nodes boot ISO; not discovered |
| DNS/NTP down | Bootstrap hangs |
| Registry empty | Image pulls fail |

## Next

→ [11 — Configuring `oc` for Remote Access](11-oc-remote-access.md)

**BMC steps:** mount `agent.x86_64.iso` as virtual CD on each XCC (see Goal/DO above).
