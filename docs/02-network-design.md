# Network Design

## Design Principles

1. **Single flat L2** — all hosts on one broadcast domain, no VLAN tagging
2. **Static IP everywhere** — no DHCP dependency during install (dnsmasq DHCP is optional)
3. **Hostname resolution via MVP DNS** — bastion runs dnsmasq until production DNS VMs are ready
4. **Room to grow** — IP plan reserves ranges for future VLAN segmentation

## IP Addressing Plan

| Range | Purpose | Notes |
|---|---|---|
| `10.10.0.0/24` | Infrastructure | Gateway, bastion, registry, VIPs, service VMs |
| `10.10.1.0/24` | Control plane | 3+ master nodes |
| `10.10.2.0/24` | Workers | Compute + CNV hypervisor nodes |
| `10.10.3.0/24` | VM workloads | Guest VMs hosted on OCP-V |
| `10.10.4.0/24` | Future VLAN expansion | Reserved |

### Infrastructure Addresses

| IP | Hostname | Role |
|---|---|---|
| `10.10.0.1` | `gw.ocp-v.local` | Default gateway (router/L3 switch) |
| `10.10.0.5` | `bastion.ocp-v.local` | Bastion + MVP DNS/NTP |
| `10.10.0.10` | `registry.ocp-v.local` | Mirror container registry |
| `10.10.0.50` | `dns.ocp-v.local` | Production DNS VM (post-install) |
| `10.10.0.51` | `ntp.ocp-v.local` | Production NTP VM (post-install) |
| `10.10.0.100` | `api.ocpv-lab.ocp-v.local` | API VIP |
| `10.10.0.101` | `*.apps.ocpv-lab.ocp-v.local` | Ingress VIP |

### Control Plane

| IP | Hostname |
|---|---|
| `10.10.1.11` | `cp01.ocp-v.local` |
| `10.10.1.12` | `cp02.ocp-v.local` |
| `10.10.1.13` | `cp03.ocp-v.local` |

### Workers

| IP | Hostname |
|---|---|
| `10.10.2.21` | `wk01.ocp-v.local` |
| `10.10.2.22` | `wk02.ocp-v.local` |

## Sample Switch Configuration

See [network/sample-switch-config/flat-l2-switch.conf.example](../network/sample-switch-config/flat-l2-switch.conf.example) for a reference switch port config (Cisco-style).

Key points for a flat L2 switch:

```
! All ports in access mode, same VLAN (or no VLAN / native)
interface range Gi1/0/1-48
  switchport mode access
  switchport access vlan 1
  spanning-tree portfast
  no shutdown
```

No trunking, no 802.1Q tagging — every host sees every other host at L2.

## Node Network Configuration

Each bare-metal node needs a static network config. Example for RHEL 9 / RHCOS:

```yaml
# nmstate or NetworkManager keyfile
addresses:
  - ip: 10.10.1.11
    prefix-length: 16
dns-resolver:
  config:
    server:
      - 10.10.0.5        # MVP: bastion dnsmasq
      # - 10.10.0.50     # Production: DNS VM (after cutover)
routes:
  config:
    - destination: 0.0.0.0/0
      next-hop-address: 10.10.0.1
      next-hop-interface: ens192
```

## VM Networking on OCP-V

Once OpenShift Virtualization is installed, VMs connect via **OVN** (default in OpenShift 4.22):

| Network | Type | Purpose |
|---|---|---|
| `default` | OVN pod network | Cluster-internal VM traffic |
| `vm-network` | Secondary NAD (Multus) | VMs on the flat L2 segment |

The production DNS/NTP VMs use a **Multus NetworkAttachmentDefinition** to attach directly to the flat L2 so they are reachable at `10.10.0.50` and `10.10.0.51`.

See manifests in `manifests/production/`.

## Firewall Rules (Bastion MVP)

| Port | Protocol | Source | Purpose |
|---|---|---|---|
| 53 | TCP/UDP | `10.10.0.0/16` | DNS (dnsmasq) |
| 123 | UDP | `10.10.0.0/16` | NTP (chronyd) |
| 22 | TCP | Admin subnet | SSH |
| 5000 | TCP | `10.10.0.0/16` | Mirror registry (on registry host) |

## DNS Zone Layout

```
ocp-v.local
├── bastion          A    10.10.0.5
├── registry         A    10.10.0.10
├── dns              A    10.10.0.50
├── ntp              A    10.10.0.51
├── cp01             A    10.10.1.11
├── cp02             A    10.10.1.12
├── cp03             A    10.10.1.13
├── wk01             A    10.10.2.21
├── wk02             A    10.10.2.22
└── ocpv-lab
    ├── api          A    10.10.0.100
    ├── api-int      A    10.10.0.100
    ├── *.apps       A    10.10.0.101
    └── ...
```

Zone file template: [network/dns-hosts-template/zone.ocp-v.local.example](../network/dns-hosts-template/zone.ocp-v.local.example)

## Future VLAN Segmentation

When VLANs are introduced later:

| VLAN ID | Subnet | Purpose |
|---|---|---|
| 10 | `10.10.0.0/24` | Management / infrastructure |
| 20 | `10.10.1.0/24` | Control plane |
| 30 | `10.10.2.0/24` | Workers |
| 40 | `10.10.3.0/24` | VM workloads |

The current flat design maps 1:1 to these VLANs when you add 802.1Q tagging — only the switch config and node NIC profiles need updating.

## Next Steps

→ [Kickstart Procedure](03-kickstart-procedure.md)
