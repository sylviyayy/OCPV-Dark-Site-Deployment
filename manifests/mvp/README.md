# MVP manifests — reference only

Bastion DNS and NTP are not Kubernetes manifests: `scripts/02-bootstrap-dns-ntp.sh` configures
dnsmasq and chronyd directly on the bastion (Lab 07), because they must work before the cluster
exists and keep working when it is down (ADR-07).

    sudo ./scripts/02-bootstrap-dns-ntp.sh

See [Lab 07 — Bootstrapping MVP DNS and NTP](../../docs/labs/07-mvp-dns-ntp.md). The steady-state
DNS and NTP VMs are in [manifests/production/](../production/README.md).
