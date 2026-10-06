# 14 — Production DNS and NTP on OCP-V

## Goal

Move DNS/NTP from the bastion onto VMs running on OpenShift Virtualization.

## WHERE

Bastion + cluster.

```bash
./scripts/07-deploy-dns-vm.sh
./scripts/08-deploy-ntp-vm.sh
```

## WHY

Bastion services were a bootstrap bridge. Steady-state platform DNS/NTP should live on
OCP-V (VMware-exit row 1 — rebuild the function).

These scripts only **deploy** the VMs. They do not switch the nodes over. Switching is
make-before-break:

1. Permanent servers become primary, with the bastion as secondary.
2. Soak.
3. Remove the bastion, prove it is drained, then disconnect it.

Not before the first 24 hours after install have passed (Window B).

## VERIFY

```bash
dig @"${DNS_VM_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
chronyc -h "${NTP_VM_IP}" tracking
oc get vm,vmi -n infrastructure
```

**Do not stop dnsmasq/chronyd on the bastion yet.** Continue with
[Bastion Lifecycle, Phases 7–8](../BASTION-LIFECYCLE.md#phase-7-make-before-break-permanent-primary-bastion-secondary-no-clock).
The bastion services are stopped only in Phase 8, after the drain has been verified.

## Next

→ [15 — Smoke Test](15-smoke-test.md)

