# 14 — Production DNS and NTP on OCP-V

## Goal

Move DNS/NTP from the jumpbox onto VMs running on OpenShift Virtualization.

## WHERE

Jumpbox + cluster.

```bash
./scripts/07-deploy-dns-vm.sh
./scripts/08-deploy-ntp-vm.sh
```

## WHY

Jumpbox services were a bootstrap bridge. Steady-state platform DNS/NTP should live on
OCP-V (VMware-exit row 1 — rebuild the function).

## VERIFY

```bash
dig @"${DNS_VM_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
chronyc -h "${NTP_VM_IP}" tracking
oc get vm,vmi -n infrastructure
```

Then on jumpbox:

```bash
sudo systemctl disable --now dnsmasq chronyd
```

## Next

→ [15 — Smoke Test](15-smoke-test.md)

