# Production Network Services

Deploy full **DNS** (BIND9) and **NTP** (chrony) virtual machines on OpenShift Virtualization, then cut over from MVP bastion services.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  OpenShift Cluster (OCP-V)                               │
│                                                          │
│  ┌────────────────────┐    ┌────────────────────┐        │
│  │  DNS VM            │    │  NTP VM            │        │
│  │  BIND9             │    │  chrony            │        │
│  │  10.10.0.50        │    │  10.10.0.51        │        │
│  │  dns.ocp-v.local   │    │  ntp.ocp-v.local   │        │
│  │                    │    │                    │        │
│  │  Multus NAD ───────┼────┼── Flat L2 network  │        │
│  └────────────────────┘    └────────────────────┘        │
│                                                          │
│  Worker nodes (KVM hypervisors)                          │
└──────────────────────────────────────────────────────────┘
         │                           │
    DNS :53                    NTP :123
         │                           │
    ┌────┴───────────────────────────┴────┐
    │  All cluster nodes + infrastructure │
    └─────────────────────────────────────┘
```

## Prerequisites

- OpenShift cluster installed and healthy
- OpenShift Virtualization (CNV) deployed and available
- Storage class available for VM disks
- Multus CNI installed (default with OVN-Kubernetes)

## Step 1 — Deploy DNS VM

```bash
export KUBECONFIG=install-config/auth/kubeconfig
./scripts/07-deploy-dns-vm.sh
```

This creates:
- `NetworkAttachmentDefinition` for flat L2 attachment
- `DataVolume` with RHEL 9 cloud image
- `VirtualMachine` with cloud-init configuring BIND9
- `Service` (optional, for cluster-internal access)

### DNS VM specification

| Property | Value |
|---|---|
| OS | RHEL 9 (cloud image from mirror) |
| vCPU | 2 |
| RAM | 4 GiB |
| Disk | 30 GiB |
| Network | Multus NAD → flat L2 at `10.10.0.50` |
| Software | BIND9 authoritative for `ocp-v.local` |

### BIND9 zone

The VM serves the full `ocp-v.local` zone including:
- All infrastructure A records
- `ocpv-lab.ocp-v.local` subdomain with API, ingress, and node records
- Reverse DNS for the `10.10.0.0/16` range

Zone file: [network/dns-hosts-template/zone.ocp-v.local.example](../network/dns-hosts-template/zone.ocp-v.local.example)

## Step 2 — Deploy NTP VM

```bash
./scripts/08-deploy-ntp-vm.sh
```

### NTP VM specification

| Property | Value |
|---|---|
| OS | RHEL 9 (cloud image from mirror) |
| vCPU | 1 |
| RAM | 2 GiB |
| Disk | 10 GiB |
| Network | Multus NAD → flat L2 at `10.10.0.51` |
| Software | chronyd (stratum 3, orphan mode initially) |

## Step 3 — Verify production services

```bash
# DNS
dig @10.10.0.50 registry.ocp-v.local +short
dig @10.10.0.50 api.ocpv-lab.ocp-v.local +short

# NTP
chronyc -h 10.10.0.51 tracking

# VM health
oc get vm -n infrastructure
oc get vmi -n infrastructure
```

## Step 4 — Cutover cluster DNS/NTP

Update all nodes to use production services via MachineConfig:

```bash
# DNS cutover
oc apply -f manifests/production/dns-vm/machineconfig-dns.yaml

# NTP cutover
oc apply -f manifests/production/ntp-vm/machineconfig-ntp.yaml
```

These MachineConfigs update `/etc/resolv.conf` and `/etc/chrony.conf` on all nodes. Nodes will drain and reboot one at a time.

Monitor:

```bash
watch oc get mcp    # MachineConfigPools
watch oc get nodes
```

## Step 5 — Decommission MVP bastion services

After all nodes report the new DNS/NTP:

```bash
# On bastion
ssh root@10.10.0.5 "systemctl stop dnsmasq chronyd && systemctl disable dnsmasq chronyd"
```

Verify no nodes still query the bastion:

```bash
# On bastion — should see no DNS traffic
tcpdump -i ens192 port 53 -c 10
```

## Self-Hosting: OCP-V Hosts Its Own Infrastructure

Once cutover is complete, the DNS and NTP VMs run **on the same cluster they serve**. This is intentional:

- DNS VM resolves all cluster endpoints including its own
- NTP VM provides time to the nodes it runs on (via flat L2, not pod network)
- If the cluster restarts, VMs auto-start (VM run strategy: `Always`)

### Boot order consideration

Configure VM priority so DNS/NTP start before application workloads:

```yaml
spec:
  template:
    spec:
      priorityClassName: system-node-critical
```

## Ongoing Operations

### DNS zone updates

When adding new nodes or services:

```bash
# SSH to DNS VM
ssh root@10.10.0.50

# Edit zone file
vi /var/named/ocp-v.local.zone
# Add new A record

# Reload BIND
rndc reload
```

Or automate via the script:

```bash
./scripts/07-deploy-dns-vm.sh --update-zone
```

### NTP upstream (if internet becomes available later)

```ini
# /etc/chrony.conf on NTP VM
server time.google.com iburst
server pool.ntp.org iburst
local stratum 3
```

### VM backups

```bash
# Snapshot VM disks via CDI
oc create -f manifests/production/dns-vm/snapshot.yaml
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| VM won't start | No KVM on worker | Check `ls /dev/kvm` on workers |
| DNS VM unreachable | NAD misconfigured | Verify Multus NAD bridge matches flat L2 |
| Nodes still use bastion DNS | MachineConfig not applied | `oc get mcp`, force reboot: `oc adm reboot-machine-config` |
| BIND fails to start | Zone file syntax error | `named-checkzone ocp-v.local /var/named/ocp-v.local.zone` |
| Clock drift after cutover | NTP VM not reachable | Check firewall, verify NAD IP `10.10.0.51` |

## Next Steps

→ [Post-Install Validation](07-post-install-validation.md)
