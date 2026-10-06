# MVP DNS and NTP (detail)

> Canonical lab: [07 — Bootstrapping MVP DNS and NTP](../07-mvp-dns-ntp.md).

## What `scripts/02-bootstrap-dns-ntp.sh` writes

Preview without changing anything: `./scripts/02-bootstrap-dns-ntp.sh --print-config`.

### `/etc/dnsmasq.d/ocp-v.conf`

| Line | Why |
|---|---|
| `listen-address=127.0.0.1,<BASTION_IP>` + `bind-interfaces` | answers the machine network **and** the bastion's own resolver (FR-E5) |
| `no-resolv`, `local=/<BASE_DOMAIN>/` | no upstream exists; unknown names under the domain get NXDOMAIN fast |
| `host-record=<fqdn>,<ip>` per host | publishes an A **and** a PTR record; `address=` answers forward queries only, so reverse lookups failed (FR-F1) |
| `address=/apps.<cluster>.<domain>/<INGRESS_VIP>` | matches the name and every name below it: the `*.apps` wildcard without a `*` |
| `dns-a`, `dns-b`, `ntp` records | the Lab 14 VMs resolve the moment they boot |

### `/etc/chrony.conf`

| `TIME_SOURCE` | Result |
|---|---|
| an IP | `server <TIME_SOURCE> iburst`, plus `local stratum 10 orphan` so the site keeps agreeing if the reference is lost |
| `orphan` | `local stratum 10 orphan` only: the site agrees with the bastion, **not with UTC** — lab-grade (FR-F3) |

`allow <MACHINE_NETWORK_CIDR>` lets nodes and VMs query it.

## Checking time without `cmdallow`

`chronyc -h <remote> tracking` is a monitoring command; chronyd accepts those only from localhost
unless `cmdallow` and `bindcmdaddress` are set, so it fails even when NTP is healthy. The client-side
probe measures what a node would see:

```bash
chronyd -Q "server ${BASTION_IP} iburst"     # prints "System clock wrong by <x> seconds (ignored)"
```

`-Q` never touches your clock and needs no privileges (FR-F2).

## Quick DNS check (what the installer and nodes ask first)

```bash
nslookup "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${BASTION_IP}"                             # → API_VIP
nslookup "console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" "${BASTION_IP}"  # → INGRESS_VIP
```

Both must answer with the VIPs. Firewall guidance (lab shortcut vs production allow-list) is in
[Lab 07 step 7.1](../07-mvp-dns-ntp.md#71-configure-and-start-dnsmasq-and-chronyd).

## Lifecycle

| Phase | Primary DNS | Primary time | Bastion role |
|---|---|---|---|
| Install (Labs 07–13) | bastion | `TIME_SOURCE` or bastion | primary |
| After Lab 14 | `dns-a`, `dns-b` | NTP VM, then `TIME_SOURCE` | **secondary, permanently** (ADR-07, FR-H12) |
| Cold start | bastion | bastion / `TIME_SOURCE` | the only service up until the VMs start |

## Next

→ [Lab 07](../07-mvp-dns-ntp.md) · [Lab 08](../08-install-agent-config.md)
