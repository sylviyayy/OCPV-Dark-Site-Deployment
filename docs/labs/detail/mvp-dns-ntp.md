# MVP DNS and NTP (detail)

> Canonical lab: [07 — Bootstrapping MVP DNS and NTP](../07-mvp-dns-ntp.md).

## Goal

Start temporary DNS and NTP on the bastion so OpenShift nodes can resolve names and sync time during install.

## WHERE

Bastion host (`BASTION_IP`), as root or with sudo.

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

## WHY this lab exists

| Service | OpenShift needs it because… |
|---|---|
| **DNS** | Installer and nodes look up `api.<cluster>.<domain>`, `*.apps...`, and the registry hostname |
| **NTP** | etcd (the cluster’s key-value brain) requires clocks within ~500 ms |

There is no corporate DNS yet (greenfield row 1). The bastion fills the gap **only until** Lab 10.

## WHAT the script does

1. Pre-flight: `BASTION_IP` must be on this host, port 53 must be free, and `.env` IPs must be well-formed  
2. Writes dnsmasq A and PTR records (`host-record=`) for hosts and VIPs, plus the `apps` wildcard, listening on `127.0.0.1` and `BASTION_IP`  
3. Configures chronyd to serve the local clock at **stratum 10** (no upstream) to `NETWORK_CIDR`  
4. Opens firewalld `dns`/`ntp`, then restarts (not just starts) and enables both services  
5. Verifies DNS and NTP, including a real NTP query to `BASTION_IP`  

Optional `--set-time 'YYYY-MM-DD HH:MM:SS'` sets the clock (UTC) first.

Preview without changing the system:

```bash
./scripts/02-bootstrap-dns-ntp.sh --dry-run                # generated configs
./scripts/02-bootstrap-dns-ntp.sh --export-hosts | less    # hosts-file format
```

## VERIFY

```bash
sudo ./scripts/02-bootstrap-dns-ntp.sh --verify
# Expect: every line [PASS]
```

From another host, use `chronyd -Q`, not `chronyc -h`. chronyd answers monitoring
commands only from localhost. See [Lab 07](../07-mvp-dns-ntp.md#verify).

## FAILS IF

| Skip / error | Symptom during install |
|---|---|
| dnsmasq not running | Cannot pull from registry by hostname |
| Nodes not pointed at bastion DNS | Same — fix in `agent-config` nmstate (next lab) |
| No NTP | etcd / TLS weirdness; bootstrap never completes |

## Next

→ [Lab 07 — MVP DNS/NTP](../07-mvp-dns-ntp.md) · [Lab 08 — Install/Agent config](../08-install-agent-config.md)
