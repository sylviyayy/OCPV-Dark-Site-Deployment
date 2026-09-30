# 07 — Bootstrapping MVP DNS and NTP

## Goal

Start temporary DNS and NTP on the jumpbox.

## WHERE

Jumpbox (`BASTION_IP`), dark site.

```bash
cd OCPV-Dark-Site-Deployment
set -a && source .env && set +a
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

## WHY

No enterprise DNS/NTP yet. OpenShift needs name resolution and clock sync for etcd.
This is the greenfield bridge until [Lab 14](14-production-dns-ntp.md).

## VERIFY

```bash
dig @"${BASTION_IP}" "registry.${BASE_DOMAIN}" +short
dig @"${BASTION_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
chronyc -h "${BASTION_IP}" tracking
```

## Next

→ [08 — Generating Install and Agent Configuration](08-install-agent-config.md)

**Detail:** [detail/mvp-dns-ntp.md](detail/mvp-dns-ntp.md) · [greenfield/05-bootstrap-services.md](../greenfield/05-bootstrap-services.md)
