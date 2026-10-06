# Network Design

> **Non-normative reference (ADR-01).** Background kept from v1. The normative values are the
> field register in [Lab 03](../labs/03-checklist.md); where this page and a lab disagree, the lab wins.

## Design principles

1. **One machine network**, untagged on the node port-channels, routed to nothing outside the site.
2. **Static addressing everywhere**: no DHCP on the machine network; nodes get nmstate from `agent-config.yaml`.
3. **Names from the bastion** during install, from the DNS VMs afterwards, with the bastion as secondary.
4. **Redundant links**: each node's four bond members are split across two switches in one LACP port-channel.

## Sample IP plan (values from `.env.example`)

| Range | Purpose |
|---|---|
| `10.10.0.0/24` | Gateway, bastion, registry, VIPs, service VMs |
| `10.10.1.0/24` | Control-plane nodes |
| `10.10.3.0/24` | Reserved for guest VMs |
| `10.20.0.0/24` | XCC (BMC) network, separate from the machine network |

| IP | Name | Role |
|---|---|---|
| `10.10.0.1` | — | Default gateway |
| `10.10.0.5` | `bastion.lab.example.com` | Bastion: DNS, NTP, DVD repo, installer |
| `10.10.0.10` | `registry.lab.example.com` | Mirror registry (port 8443) |
| `10.10.0.50` | `dns-a.lab.example.com` | DNS VM |
| `10.10.0.52` | `dns-b.lab.example.com` | DNS VM |
| `10.10.0.51` | `ntp.lab.example.com` | NTP VM |
| `10.10.0.100` | `api.coe01.lab.example.com`, `api-int…` | API VIP |
| `10.10.0.101` | `*.apps.coe01.lab.example.com` | Ingress VIP |
| `10.10.1.11`–`13` | `mw01`–`mw03.lab.example.com` | Control-plane nodes |

The same plan as CSV: [network/ip-addressing-plan.csv](../../network/ip-addressing-plan.csv).

## Node network (rendered into `agent-config.yaml`)

```yaml
interfaces:
  - name: bond0
    type: bond
    state: up
    mtu: 1500                       # MTU (B4)
    link-aggregation:
      mode: 802.3ad
      options: {miimon: "100"}
      port: [ens1f0, ens1f1, ens2f0, ens2f1]   # MW01_NICS (C3)
    ipv4: {enabled: true, dhcp: false, address: [{ip: 10.10.1.11, prefix-length: 16}]}
dns-resolver:
  config: {server: [10.10.0.5]}     # bastion during install
routes:
  config:
    - {destination: 0.0.0.0/0, next-hop-address: 10.10.0.1, next-hop-interface: bond0}
```

Switch-side example: [network/sample-switch-config/lacp-mlag-switch.conf.example](../../network/sample-switch-config/lacp-mlag-switch.conf.example).

## VM networking on OCP-V

| Network | Type | Purpose |
|---|---|---|
| `default` | OVN pod network | Cluster-internal VM traffic |
| `infrastructure/vmnet` | OVN-K **localnet** mapped onto `br-ex` | DNS and NTP VMs on the machine network |

## Firewall summary

| Port | Protocol | Host | Purpose |
|---|---|---|---|
| 53 | TCP/UDP | bastion, DNS VMs | DNS |
| 123 | UDP | bastion, NTP VM | NTP |
| 80 | TCP | bastion | RHEL DVD repo for the VMs |
| 8443 | TCP | registry host | mirror registry (`MIRROR_REGISTRY_PORT`) |
| 6443, 22623 | TCP | API VIP | Kubernetes API, machine config server |
| 443, 80 | TCP | Ingress VIP | Routes and console |
| 22 | TCP | all hosts | SSH from the admin network |

## DNS zone layout

```text
lab.example.com
├── bastion       A    10.10.0.5
├── registry      A    10.10.0.10
├── dns-a, dns-b  A    10.10.0.50, 10.10.0.52
├── ntp           A    10.10.0.51
├── mw01 … mw03   A    10.10.1.11 … 10.10.1.13
└── coe01
    ├── api       A    10.10.0.100
    ├── api-int   A    10.10.0.100
    └── *.apps    A    10.10.0.101
```

Rendered from `.env` by the DNS VM template
([manifests/production/dns-vm/dns-vm.yaml.template](../../manifests/production/dns-vm/dns-vm.yaml.template)),
with a matching reverse zone.

## Future VLAN segmentation

When the site introduces VLANs, tag the machine network on the port-channels and move management,
storage and guest traffic to their own VLANs; only the switch configuration, `agent-config.yaml`
nmstate and the localnet NAD change.
