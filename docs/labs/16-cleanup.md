# 16 — Cleaning Up

## Goal

Tear down lab state safely when the exercise is finished (or reset for a re-run).

## WHERE

Bastion, BMCs, and optional registry host.

## WHY

Hard Way ends with cleanup so the next learner starts clean. On bare metal, “cleanup”
means re-image / re-ISO, not deleting cloud VMs.

## DO — soft cleanup (configs only)

```bash
cd OCPV-Dark-Site-Deployment
# Remove generated install dir (keeps templates)
rm -rf install-config/auth install-config/agent.x86_64.iso \
       install-config/install-config.yaml install-config/agent-config.yaml \
       install-config/cluster-resources
# Keep .env if you will redeploy the same rack; otherwise:
# rm -f .env
```

## DO — hard cleanup (reinstall cluster)

1. On each node BMC: mount a fresh Agent ISO (or wipe disks / re-RAID)  
2. Re-run Labs 08–10  
3. Optionally wipe registry data under the registry host’s quay/registry volume  

## DO — bastion DNS/NTP

If production DNS/NTP VMs are gone but bastion services were stopped:

```bash
sudo ./scripts/02-bootstrap-dns-ntp.sh   # only if you need MVP again
```

## VERIFY

- [ ] No cluster API responds on `API_VIP` (after wipe)  
- [ ] Removable media / pull secrets stored securely offline  

## Done

Return to the [README labs list](../../README.md#labs).
