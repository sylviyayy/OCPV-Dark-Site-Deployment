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

1. Writes dnsmasq records from your `.env` (API VIP, Ingress VIP, nodes, registry)  
2. Configures chronyd in **orphan mode** (authoritative local time with no internet NTP)  
3. Opens firewall ports 53 and 123  
4. Enables and starts both services  

Preview the hosts file without changing the system:

```bash
./scripts/02-bootstrap-dns-ntp.sh --export-hosts | less
```

## VERIFY

```bash
dig @"${BASTION_IP}" "registry.${BASE_DOMAIN}" +short
# Expect: MIRROR_REGISTRY_IP

dig @"${BASTION_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
# Expect: API_VIP

chronyc -h "${BASTION_IP}" tracking
# Expect: a valid tracking response (stratum from orphan mode)
```

## FAILS IF

| Skip / error | Symptom during install |
|---|---|
| dnsmasq not running | Cannot pull from registry by hostname |
| Nodes not pointed at bastion DNS | Same — fix in `agent-config` nmstate (next lab) |
| No NTP | etcd / TLS weirdness; bootstrap never completes |

## Next

→ [Lab 07 — MVP DNS/NTP](../07-mvp-dns-ntp.md) · [Lab 08 — Install/Agent config](../08-install-agent-config.md)
