# 10 — Bootstrapping the Cluster with the Assisted / OVE Offline Agent

## Goal

Boot all three Lenovo nodes (`mw01`–`mw03`) from the **offline OVE agent media**
(`agent.ove.x86_64`, OpenShift **4.21.27**) via BMC virtual CD and finish the Assisted
UI / install until the cluster is up.

## WHERE

- USB / bastion copy of `agent.ove.x86_64` (~58 GB; see [USB Transfer Kit](../USB-TRANSFER-KIT.md))  
- Each server XCC: virtual media  

## WHY

This replaces Hard Way’s separate “bootstrap control plane” and “bootstrap workers” labs.
The OVE offline agent embeds Assisted Service plus the Virtualization-oriented payload;
nodes self-register. You configure the cluster in the Assisted UI on the rendezvous host
(or follow the console-exported flow you started when downloading the media).

**Not PXE. Not Kickstart on RHCOS. Not a separate RHCOS installer USB.**

> **DNS/NTP:** Keep bastion MVP DNS/NTP up (Lab 07) so `api.` / `*.apps.` and clocks work
> during bootstrap.
>
> **[WINDOW B]** After install starts, keep the cluster powered on and the bastion's
> DNS/NTP unchanged for at least 24 hours (first certificate rotation).
> See [Bastion Lifecycle §2](../BASTION-LIFECYCLE.md#2-the-two-24-hour-windows-and-what-is-not-on-a-clock).

### Optional alternate: classic `openshift-install agent create image`

If you are on the advanced oc-mirror path instead of OVE media, use the ISO from Lab 08
(`agent.x86_64.iso`) and `openshift-install agent wait-for install-complete`. Primary
hands-on path for this repo is **OVE offline media**.

## DO — BMC on mw01, mw02, mw03

1. Map **`agent.ove.x86_64`** as virtual CD (file is large — prefer HTTP virtual media from
   bastion if XCC upload is slow; otherwise attach from a locally mounted exFAT stick)  
2. One-time boot from virtual CD  
3. Let Assisted proceed; reboot into the installed system when directed  

Boot the **`RENDEZVOUS_IP`** node first, complete its Assisted steps, then boot the others
from the **same** media.

## DO — wait / finish install

Use the Assisted UI hosted on the rendezvous node (URL shown on the console after boot),
or, on the classic ABI path only:

```bash
export PATH="${MIRROR_DIR}/clients:${PATH}"
openshift-install agent wait-for install-complete --dir=install-config/ --log-level=info
```

## VERIFY

```bash
# After kubeconfig is available (Assisted download or install-config/auth/)
export KUBECONFIG=/path/to/kubeconfig
oc get nodes -o wide
oc get clusterversion
# Expect OpenShift 4.21.27
```

## FAILS IF

| Problem | Symptom |
|---|---|
| Wrong MAC / bond | Nodes boot ISO; not discovered or no IP |
| DNS/NTP down | Bootstrap hangs on names or clocks |
| Truncated USB copy | Media will not boot or fails mid-stream |
| FAT32 USB used for copy | Never got the full ~58 GB file onto the stick |

## Next

→ [11 — Configuring `oc` for Remote Access](11-oc-remote-access.md)
