# Production Network Services

> **Non-normative reference (ADR-01).** Background kept from v1. The normative procedure is
> [Lab 14](../labs/14-production-dns-ntp.md); where this page and a lab disagree, the lab wins.

## Architecture

```text
┌──────────────────────────────────────────────────────────────┐
│ OpenShift Virtualization (namespace: infrastructure)         │
│                                                              │
│  dns-a (BIND)        dns-b (BIND)         ntp (chrony)       │
│  DNS_VM_IPS[0]       DNS_VM_IPS[1]        NTP_VM_IP          │
│  └── anti-affine ──┘                                         │
│         all three on localnet "vmnet" → br-ex → bond0        │
└──────────────────────────────────────────────────────────────┘
        node resolvers: dns-a, dns-b, bastion   (NMState NNCP)
        node time:      ntp, TIME_SOURCE/bastion (MachineConfig)
```

## Design points

| Choice | Reason |
|---|---|
| Two DNS VMs with required anti-affinity | one DNS VM is a single point of failure for every node's resolver |
| cloud-init in Secrets via `cloudInitNoCloud` | KubeVirt reads userdata and network-config from Secrets; no passwords in them |
| Static guest addresses from network-config v2 | the machine network has no DHCP |
| Packages from the bastion's DVD repo | the guest image lacks `bind`; a dark site has no CDN |
| Guest image pinned by digest, pulled with the registry CA and credentials | the CDI importer has its own TLS trust and auth |
| `evictionStrategy: None` | node-local ReadWriteOnce disks cannot live-migrate; a drain would otherwise block |
| Dedicated `infrastructure-vm` PriorityClass | ahead of workloads after a cold start, below node-critical daemons |
| Resolvers via NMState `dns-resolver` | on bare metal NetworkManager and the node-local CoreDNS own `resolv.conf` |
| Bastion stays on | the cold-start fallback (ADR-07) |

## Ongoing operations

- **Zone changes:** edit `.env` (or the template), re-run `scripts/07-deploy-dns-vm.sh`; the rendered
  zone is validated by CI with `named-checkconf -z`. Recreate the VMs to apply new cloud-init.
- **Time upstream:** set `TIME_SOURCE` to a reference clock and re-run Labs 07 and 14.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| DataVolume `Pending` | no default StorageClass | Lab 13 step 13.2 |
| Importer `x509` or `401` | `registry-ca` or `registry-pull` missing | re-run script 07 |
| VMI Ready, no DNS answers | cloud-init failed (often the DVD repo) | `virtctl console dns-a -n infrastructure`; `cloud-init status --long` |
| VM unreachable | NNCP `vmnet-bridge-mapping` not Available | `oc get nncp,nnce` |
| `mcp/master` stuck Updating | a node cannot drain | check PodDisruptionBudgets on that node |
