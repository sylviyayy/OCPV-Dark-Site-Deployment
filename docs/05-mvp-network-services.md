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
│  │  (no DHCP)  │  │  (orphan mode)   │  │
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

1. Installs `dnsmasq` and `chrony`
2. Generates `/etc/dnsmasq.d/ocp-v.conf` from `.env` variables
3. Configures chronyd in **orphan mode** (acts as authoritative time source with no upstream)
4. Opens firewall ports 53 and 123
5. Starts and enables both services

## DNS Records (dnsmasq)

The script generates A records for all infrastructure and cluster hosts:

```
# /etc/dnsmasq.d/ocp-v.conf
address=/bastion.ocp-v.local/10.10.0.5
address=/registry.ocp-v.local/10.10.0.10
address=/api.ocpv-lab.ocp-v.local/10.10.0.100
address=/api-int.ocpv-lab.ocp-v.local/10.10.0.100
address=/*.apps.ocpv-lab.ocp-v.local/10.10.0.101
address=/cp01.ocp-v.local/10.10.1.11
...
```

Wildcard `*.apps` is supported by dnsmasq for ingress resolution.

## NTP Configuration (chronyd orphan mode)

```ini
# /etc/chrony.conf (relevant section)
local stratum 10 orphan
allow 10.10.0.0/16
bindaddress 10.10.0.5
makestep 1.0 3
rtcsync
```

**Orphan mode** means chronyd acts as the time source even without upstream NTP servers. All cluster nodes sync to the bastion. Clock drift is acceptable during install as long as all nodes agree.

## Verification

```bash
# DNS
dig @10.10.0.5 registry.ocp-v.local +short
# Expected: 10.10.0.10

dig @10.10.0.5 api.ocpv-lab.ocp-v.local +short
# Expected: 10.10.0.100

# NTP
chronyc -h 10.10.0.5 tracking
# Expected: Reference ID shows bastion IP, stratum 10

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
| Post OCP-V install | DNS VM on OCP-V | NTP VM on OCP-V | Deploy production VMs |
| Cutover | DNS VM `10.10.0.50` | NTP VM `10.10.0.51` | Update node configs, stop bastion services |
| Steady state | DNS VM | NTP VM | Bastion DNS/NTP decommissioned |

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
