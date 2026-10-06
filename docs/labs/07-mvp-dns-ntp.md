# 07 — Bootstrapping MVP DNS and NTP

> **Grade:** depends on `TIME_SOURCE`. With a reference clock (an IP) this is production-grade
> infrastructure. With `orphan` it is **lab-grade**: see the callout below.

## Goal

Start DNS and NTP on the bastion so the Agent ISO, the nodes and the installer can resolve the
registry, API and ingress names and agree on time — and keep them running for the life of the site.

> **Lab-grade time when `TIME_SOURCE=orphan`.** `local stratum 10 orphan` makes the cluster agree
> with **itself**, not with UTC. That is enough for etcd and TLS between members, but audit logs,
> certificate validity and SIEM correlation need time traceable to UTC, and many financial-services
> and government sites mandate it. For production, set `TIME_SOURCE` to a reference clock (a GPS- or
> PTP-disciplined NTP appliance) and re-run this lab (FR-F3).

## Steps

### 7.1 Configure and start dnsmasq and chronyd

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The Agent ISO resolves `registry.<domain>` to pull the release payload, and every node
resolves `api` and `api-int`; without an answer, discovery stalls at the first image pull. dnsmasq
`host-record` lines publish an A **and** a PTR record per host, and one `address=/apps.<cluster>.<domain>/`
line answers every ingress name. chronyd serves `TIME_SOURCE` (or its own orphan clock) to the machine
network; etcd members and TLS validation fail on skew. dnsmasq binds `127.0.0.1` too, so the bastion
resolves through itself (FR-E5, FR-F1). Consumed by: agent-config `dns-resolver` and
`additionalNTPSources` (Lab 08), and every node after Lab 14 as the secondary.
If skipped: the Agent ISO cannot resolve the registry at Lab 10, and the install never starts.

**EDIT** — No edits in this step. (Preview without changing anything: `./scripts/02-bootstrap-dns-ntp.sh --print-config`.)

**DO**

```bash
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

**VERIFY** — The script runs these itself; to repeat them by hand:

```bash
set -a && source .env && set +a
C="${CLUSTER_NAME}.${BASE_DOMAIN}"
test "$(dig +short @"${BASTION_IP}" "api.${C}")" = "${API_VIP}" && echo PASS || echo FAIL                          # expect: PASS
test "$(dig +short @"${BASTION_IP}" "console-openshift-console.apps.${C}")" = "${INGRESS_VIP}" && echo PASS || echo FAIL  # expect: PASS
test "$(dig +short @"${BASTION_IP}" "${MIRROR_REGISTRY_HOSTNAME}")" = "${MIRROR_REGISTRY_IP}" && echo PASS || echo FAIL  # expect: PASS
test "$(dig +short @"${BASTION_IP}" -x "${MW01_IP}")" = "${MW01_HOSTNAME}.${BASE_DOMAIN}." && echo PASS || echo FAIL   # expect: PASS
chronyd -Q "server ${BASTION_IP} iburst"     # expect: "System clock wrong by <x> seconds", |x| < 1
```

`chronyd -Q` is a client-side probe: it measures the offset without touching your clock and
needs nothing configured on the server. `chronyc -h <remote> tracking` is refused unless the
server sets `cmdallow`, so it fails even when NTP is healthy — a check that always fails teaches
you to ignore checks (FR-F2).

**FAILS IF** — `dig` returns nothing ← dnsmasq is not running (`systemctl status dnsmasq`) or
the firewall blocks 53; the probe prints no offset ← UDP 123 blocked.

### 7.2 Prove the whole high side

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — One run asserts the pinned OS, the packages, the absence of an internet route, the
clients, every DNS answer, time and the registry — the state Lab 08 assumes. Consumed by: Lab 08.
If skipped: a gap here becomes a stalled ISO build there.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/00-prerequisites-check.sh --bastion
```

**VERIFY** — Last line: `Results: N passed, 0 failed` (exit 0).

**FAILS IF** — `no route to the internet` fails ← the machine network routes out; fix before going on.

Detail: [MVP DNS and NTP](detail/mvp-dns-ntp.md)

## Next

→ [08 — Generating Install and Agent Configuration](08-install-agent-config.md)
