# MVP Network Services

Minimal DNS and NTP services on the **bastion host** to bootstrap OpenShift installation when no infrastructure services exist.

## Why MVP Services?

| Service | Required By | Without It |
|---|---|---|
| **DNS** | OpenShift installer, etcd, operators | Install fails — nodes can't resolve API/ingress |
| **NTP** | etcd (500ms skew limit), TLS cert validation | etcd quorum loss, cert errors |

In a dark site, these services **do not exist** until you create them. The bastion fills this gap temporarily.

## Architecture

```
┌─────────────────────────────────────────┐
│  Bastion (10.10.0.5)                    │
│                                         │
│  ┌─────────────┐  ┌──────────────────┐  │
│  │  dnsmasq    │  │  chronyd         │  │
│  │  :53        │  │  :123            │  │
│  │  DNS only   │  │  local stratum   │  │
│  │  (no DHCP)  │  │  (stratum 10)    │  │
│  └─────────────┘  └──────────────────┘  │
│                                         │
│  /etc/dnsmasq.d/ocp-v.conf              │
│  /etc/chrony.conf (local clock master)  │
└─────────────────────────────────────────┘
         │                    │
    DNS queries           NTP sync
         │                    │
    ┌────┴────────────────────┴────┐
    │  All cluster nodes           │
    │  nameserver 10.10.0.5        │
    │  NTP server 10.10.0.5        │
    └──────────────────────────────┘
```

## Deployment

```bash
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

### What the script does

1. Checks that `BASTION_IP` is on this host and port 53 is free
2. Installs `dnsmasq`, `chrony` and `bind-utils` if missing
3. Generates `/etc/dnsmasq.d/ocp-v.conf` and `/etc/chrony.conf` from `.env` variables
4. Opens firewall ports 53 and 123
5. Restarts and enables both services, then verifies them

Run `./scripts/02-bootstrap-dns-ntp.sh --dry-run` to see the exact files.

## DNS Records (dnsmasq)

The script generates A **and PTR** records for all infrastructure and cluster hosts:

```
# /etc/dnsmasq.d/ocp-v.conf (excerpt)
listen-address=127.0.0.1,10.10.0.5
bind-interfaces
no-resolv
no-hosts
local=/ocp-v.local/
address=/apps.ocpv-lab.ocp-v.local/10.10.0.101
host-record=bastion.ocp-v.local,10.10.0.5
host-record=registry.ocp-v.local,10.10.0.10
host-record=api.ocpv-lab.ocp-v.local,10.10.0.100
host-record=api-int.ocpv-lab.ocp-v.local,10.10.0.100
host-record=cp01.ocp-v.local,10.10.1.11
...
```

`address=/apps.<cluster>.<domain>/` matches `apps.<cluster>.<domain>` and every name
below it. That is the `*.apps` wildcard, written without a `*` because wildcard syntax
differs across dnsmasq versions.

## NTP Configuration (local clock, no upstream)

```ini
# /etc/chrony.conf
local stratum 10
allow 10.10.0.0/16
makestep 1.0 3
rtcsync
driftfile /var/lib/chrony/drift
logdir /var/log/chrony
```

`local stratum 10` makes chronyd serve its own clock with no upstream NTP servers. All
cluster nodes sync to the bastion. Drift from true UTC is acceptable during install, as
long as all nodes agree. Stratum 10 is deliberately high, so any later real source wins.

## Verification

```bash
# DNS
dig @10.10.0.5 registry.ocp-v.local +short
# Expected: 10.10.0.10

dig @10.10.0.5 api.ocpv-lab.ocp-v.local +short
# Expected: 10.10.0.100

# Everything at once, on the bastion
sudo ./scripts/02-bootstrap-dns-ntp.sh --verify

# NTP from another host (chronyc -h does not work remotely)
sudo chronyd -Q -t 10 'port 0' 'cmdport 0' 'pidfile /run/chronyd-q.pid' 'server 10.10.0.5 iburst'
# Expected: "System clock wrong by <offset> seconds (ignored)"

# From a cluster node
chronyc sources
# Expected: ^* 10.10.0.5
```

## Configuring Cluster Nodes

### During agent-based install

Set DNS and NTP in `agent-config.yaml`:

```yaml
hosts:
  - hostname: cp01
    role: master
    rootDeviceHints:
      deviceName: /dev/sda
    networkConfig:
      interfaces:
        - name: ens192
          type: ethernet
          state: up
          ipv4:
            enabled: true
            address:
              - ip: 10.10.1.11
                prefix-length: 16
            dhcp: false
      dns-resolver:
        config:
          server:
            - 10.10.0.5
      routes:
        config:
          - destination: 0.0.0.0/0
            next-hop-address: 10.10.0.1
            next-hop-interface: ens192
```

### MachineConfig for NTP (post-install)

```yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-master-chrony
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
        - contents:
            source: data:text/plain;charset=utf-8,server%2010.10.0.5%20iburst%0Adriftfile%20%2Fvar%2Flib%2Fchrony%2Fdrift%0Amakestep%201.0%203%0Artcsync%0A
          mode: 420
          path: /etc/chrony.conf
          overwrite: true
```

## Lifecycle

| Phase | DNS Source | NTP Source | Action |
|---|---|---|---|
| Pre-install | Bastion dnsmasq | Bastion chronyd | Deploy MVP |
| During install | Bastion dnsmasq | Bastion chronyd | No change |
| Post-install soak (≥ 24 h) | Bastion dnsmasq | Bastion chronyd | Deploy production VMs; do **not** switch yet |
| Make-before-break | DNS VM `10.10.0.50`, then bastion | NTP VM `10.10.0.51` (`prefer`), then bastion | NNCP + Butane `MachineConfig`; soak |
| Break | DNS VM | NTP VM | Remove bastion from configs, verify drain, stop services, disconnect |
| Steady state | DNS VM | NTP VM | Bastion gone |

Full procedure: [Bastion Lifecycle](BASTION-LIFECYCLE.md), Phases 6–8.

## Decommissioning MVP Services

After production DNS/NTP VMs are verified:

```bash
# On bastion
sudo systemctl stop dnsmasq chronyd
sudo systemctl disable dnsmasq chronyd

# Update all nodes to point to production services
# (scripts/07 and 08 handle this via MachineConfig)
```

## Next Steps

→ [Production Network Services](06-production-network-services.md)
