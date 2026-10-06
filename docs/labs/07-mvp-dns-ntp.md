# 07 — Bootstrapping MVP DNS and NTP

## Goal

Turn the bastion into the site's temporary DNS server (dnsmasq) and NTP server (chronyd).

## WHERE

Bastion (`BASTION_IP`), dark site, as root.

## WHY

No enterprise DNS/NTP exists yet. OpenShift needs name resolution, and etcd needs the
nodes' clocks to agree. This is the greenfield bridge until [Lab 14](14-production-dns-ntp.md).

### "Primary" or "secondary"? The nodes decide, not the bastion

A DNS or NTP server doesn't know where it sits in a client's list. The order lives on
each **node**, in `agent-config.yaml`. So this one script covers the bastion's whole
life: it is the sole server during install and the fallback during cutover.

Two precise terms:

- **Resolver, not kernel.** The kernel does not look up names. The resolver library
  (glibc, Go's resolver, CoreDNS on the node) reads the nameserver list and tries the
  entries **in order**. chronyd, a userspace daemon, then sets the kernel's clock.
- **Fallback nameserver, not "secondary DNS".** In DNS terminology a "secondary" server
  is a zone-transfer replica. What you mean is the second `nameserver` entry.

**During install, list only the bastion.** Do not list the future permanent servers
(`DNS_VM_IP`, `NTP_VM_IP`) yet:

| If the nodes list the not-yet-built permanent DNS first | Result |
|---|---|
| Every lookup tries the dead first server and waits for its timeout (about 5 s by default) before asking the bastion | The install crawls, and timeouts can trip |
| When the permanent DNS later comes up half-configured, it answers "no such name" (NXDOMAIN) | Resolvers fall back to the next server only on silence or errors, **not** on NXDOMAIN. Nodes stop resolving records the bastion still has: an outage you didn't schedule |

For NTP, a dead first entry is harmless, because chrony marks it unreachable. It just
gains nothing. The bastion becomes "secondary" later, in
[Bastion Lifecycle, Phase 7](../BASTION-LIFECYCLE.md#phase-7-make-before-break-permanent-primary-bastion-secondary-no-clock),
after the permanent servers pass a parity check. That is a change on the nodes; the
bastion stays exactly as this lab leaves it.

## DO

```bash
cd ~/OCPV-Dark-Site-Deployment
cp -n .env.example .env && vim .env        # BASTION_IP, BASE_DOMAIN, CLUSTER_NAME, VIPs, node IPs

./scripts/02-bootstrap-dns-ntp.sh --dry-run          # optional: preview the generated configs

# The bastion's clock becomes the site's time authority. If it's wrong, set it first (UTC):
date -u
sudo ./scripts/02-bootstrap-dns-ntp.sh --set-time '2026-10-06 14:30:00'   # your real UTC time
# or, if the clock is already right:
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

The script:

1. Refuses to run if `BASTION_IP` isn't on this host, if another DNS server holds port 53,
   or if `.env` has a malformed IP.
2. Installs `dnsmasq`, `chrony` and `bind-utils` if missing. Mount the RHEL DVD repository
   first ([Bastion Lifecycle, Phase 1](../BASTION-LIFECYCLE.md#phase-1-arrival-install-the-bastion-and-registry-host-no-clock)).
3. Writes `/etc/dnsmasq.d/ocp-v.conf` with A and PTR records for every host and VIP, plus
   the `*.apps` wildcard. Writes `/etc/chrony.conf` serving the local clock at stratum 10
   to `NETWORK_CIDR`. Originals are kept as `*.orig`.
4. Opens firewalld `dns` and `ntp`, then restarts and enables both services. Re-running it
   is safe, and is how you apply `.env` changes.
5. Verifies every record, the wildcard, a reverse lookup, the loopback listener, and a real
   NTP query to `BASTION_IP`.

Also set every node's **BMC/UEFI clock to UTC**, within a minute of the bastion.

## VERIFY

```bash
sudo ./scripts/02-bootstrap-dns-ntp.sh --verify        # every check must say [PASS]
```

From **another** machine on the install network (the registry host, for example):

```bash
dig +short @<BASTION_IP> api.<cluster>.<domain>
sudo chronyd -Q -t 10 'port 0' 'cmdport 0' 'pidfile /run/chronyd-q.pid' 'server <BASTION_IP> iburst'
# expect "System clock wrong by <offset> seconds (ignored)". This measures only, never sets the clock.
```

> `chronyc -h <BASTION_IP> tracking` does **not** work from other hosts. chronyd accepts
> monitoring commands only from localhost by default. Use the `chronyd -Q` probe above.

## FAILS IF

| Symptom | Cause | Fix |
|---|---|---|
| `BASTION_IP=... is not configured on any interface` | The bastion's NIC has a different IP | `nmcli` or fix `.env` |
| `Another process already listens on port 53` | `named` or another DNS server is running | `systemctl disable --now <it>` |
| DNS passes on the bastion, times out from other hosts | firewalld or switch path | `firewall-cmd --list-services` must show `dns ntp` |
| NTP probe gets no answer from other hosts | Client outside `NETWORK_CIDR`, or UDP 123 blocked | Fix `NETWORK_CIDR` in `.env` and re-run |

## Next

→ [08 — Generating Install and Agent Configuration](08-install-agent-config.md)

**Detail:** [detail/mvp-dns-ntp.md](detail/mvp-dns-ntp.md) · [greenfield/05-bootstrap-services.md](../greenfield/05-bootstrap-services.md)
