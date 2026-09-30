# 10 — Production DNS/NTP VMs on OCP-V

## Goal

Run permanent DNS and NTP as VMs on OpenShift Virtualization, then stop using the bastion for those services.

## WHERE

Bastion with kubeconfig; VMs land on worker nodes.

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
./scripts/07-deploy-dns-vm.sh
./scripts/08-deploy-ntp-vm.sh
```

## WHY this lab exists

Bastion DNS/NTP was a **bootstrap bridge**. For a VMware-exit / greenfield CoE story (DNS row 1), the customer-owned name and time services should live on the platform you installed — not forever on a helper laptop.

See also: [appendix — does this repo apply?](../greenfield/appendix-brownfield-contrast.md).

## WHAT happens

1. Multus network attachment for flat L2 (so VMs get `DNS_VM_IP` / `NTP_VM_IP`)  
2. VirtualMachines + cloud-init for BIND / chrony  
3. MachineConfigs so OpenShift nodes use the new DNS/NTP  
4. You manually stop bastion dnsmasq/chronyd after verification  

## VERIFY

```bash
dig @"${DNS_VM_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
chronyc -h "${NTP_VM_IP}" tracking
oc get vm,vmi -n infrastructure
```

Only then on bastion:

```bash
sudo systemctl disable --now dnsmasq chronyd
```

## FAILS IF

| Mistake | Result |
|---|---|
| Cut over before VMs answer | Cluster-wide DNS outage |
| Never cut over | Bastion remains a single point of failure |

## Next

→ [11 — Smoke test](11-smoke-test.md)
