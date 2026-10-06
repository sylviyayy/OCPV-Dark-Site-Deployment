# 07 — Bootstrapping MVP DNS and NTP

> **Grade:** set by `TIME_SOURCE`. A reference clock (an IP) makes this production-grade; `orphan`
> makes time **lab-grade** (see below). DNS is production-grade either way.

## Goal

Serve DNS and NTP from the bastion, so the installer and the nodes can resolve the registry, API
and ingress names and agree on time — and keep both running for the life of the site (ADR-07).

> **`TIME_SOURCE=orphan` is lab-grade time.** The cluster agrees with the bastion, not with UTC.
> etcd and TLS between members only need agreement; audit logs, certificate validity and SIEM
> correlation need UTC, and regulated sites mandate it. For production, set `TIME_SOURCE` to a
> GPS- or PTP-disciplined NTP appliance and re-run this lab.

## Day 1 on site: DNS and NTP only

You can run this lab on its own, before the mirror, the registry or any node exists. It needs
only names and addresses from `.env`.

| Need on the bastion | How |
|---|---|
| RHEL 9.x, NIC holding `BASTION_IP` | kickstart (Lab 04) or a hand install; script 02 stops with the `nmcli` fix if the address is missing |
| This repo with your `.env` | the kickstart copies it to `/home/installer/`; otherwise copy it from the USB drive |
| `dnsmasq`, `chrony`, `bind-utils` | the kickstart installs them; otherwise script 02 installs them from the DVD repo (below) |

```bash
cd ~/OCPV-Dark-Site-Deployment
grep -n 'UPDATE' .env                                  # every placeholder: confirm or correct each one
./scripts/lib/validate-env.sh --scope services         # expect: PASS for scope 'services'
# Only if the three packages are missing (hand-installed bastion):
sudo mkdir -p /opt/ocp-mirror && sudo cp /run/media/$USER/<USB>/rhel-9*-dvd.iso /opt/ocp-mirror/rhel9-dvd.iso
sudo ./scripts/04b-serve-dvd-repo.sh                   # local dnf repo from the DVD
```

Then steps 7.0 and 7.1. From a laptop on `MACHINE_NETWORK_CIDR`, check the bastion as a client would:

```bash
nslookup api.ocpv-poc.example.com <BASTION_IP>                           # Windows or Linux → API_VIP
w32tm /stripchart /computer:<BASTION_IP> /samples:3 /dataonly            # Windows: small offsets
chronyd -Q "server <BASTION_IP> iburst"                                  # Linux (sudo): |offset| < 1 s
```

Step 7.2 also checks the Lab 06 clients and registry, so skip it on a DNS/NTP-only day.

## Steps

### 7.0 Set the bastion clock to UTC (before anything serves time)

**WHERE** — Bastion, `installer` with `sudo`

**WHY** — Whatever this clock reads becomes the site's time: with `orphan`, directly; with a
`TIME_SOURCE`, until chrony first reaches it. Certificates minted later (registry, cluster) carry
this time; a node whose BMC clock lags behind sees them as *not yet valid*.

**EDIT** — None.

**DO**

```bash
sudo timedatectl set-timezone UTC
timedatectl                                         # compare with a trusted clock (phone, watch)
sudo timedatectl set-ntp false && sudo timedatectl set-time 'YYYY-MM-DD HH:MM:SS'   # only if it is off
sudo hwclock --systohc --utc
```

Set each node's XCC/UEFI clock to UTC within a minute of the bastion.

**VERIFY** — `date -u` agrees with your reference to within a few seconds.

**FAILS IF** — Later: `x509: certificate has expired or is not yet valid` ← clocks disagreed when the certificate was minted.

### 7.1 Configure and start dnsmasq and chronyd

**WHERE** — Bastion, RHEL 9.x, `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Every name the install needs comes from here:

| Record | Who needs it |
|---|---|
| `registry.<domain>` | Agent ISO and nodes, to pull the release payload |
| `api`, `api-int.<cluster>.<domain>` → `API_VIP` | nodes and `oc` |
| `*.apps.<cluster>.<domain>` → `INGRESS_VIP` (one `address=` line) | console, OAuth, routes |
| A **and** PTR per host (`host-record`) | node hostname checks, certificates, logs |

chronyd serves `TIME_SOURCE` (or its own orphan clock at stratum 10) to `MACHINE_NETWORK_CIDR`;
skew breaks etcd and TLS. dnsmasq also listens on `127.0.0.1`, so the bastion resolves through itself.
*Consumed by:* agent-config `dns-resolver` and `additionalNTPSources` (Lab 08); every node as
secondary after Lab 14. *If skipped:* the Agent ISO cannot resolve the registry and the install never starts.

**EDIT** — None. Preview without changing anything: `./scripts/02-bootstrap-dns-ntp.sh --print-config`.

**DO** — `sudo ./scripts/02-bootstrap-dns-ntp.sh`

**VERIFY** — The script compares each answer with `.env` and exits 1 on any mismatch. By hand:

```bash
set -a && source .env && set +a
C="${CLUSTER_NAME}.${BASE_DOMAIN}"
dig +short @"${BASTION_IP}" "api.${C}"                                # expect: API_VIP
dig +short @"${BASTION_IP}" "console-openshift-console.apps.${C}"     # expect: INGRESS_VIP
dig +short @"${BASTION_IP}" -x "${MW01_IP}"                           # expect: <MW01_HOSTNAME>.<BASE_DOMAIN>.
chronyd -Q "server ${BASTION_IP} iburst"                              # expect: "System clock wrong by x seconds", |x| < 1
```

`chronyd -Q` measures the offset as a client without touching your clock. Do not use
`chronyc -h <host> tracking`: the server refuses it unless `cmdallow` is set, so it fails while NTP is healthy.

**FAILS IF** — `BASTION_IP=… is not configured on any interface` ← `.env` and the NIC disagree: fix
whichever is wrong (the message prints the `nmcli` command); `dig` returns nothing ← dnsmasq not
running or UDP/TCP 53 blocked; no offset printed ← UDP 123 blocked. `[WARN] TIME_SOURCE … does not
answer` is not a failure: the bastion serves its own clock (set in 7.0) until the site NTP server
is reachable.

### 7.2 Prove the whole high side

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — One run asserts everything Lab 08 assumes: RHEL 9, the DVD packages, **no** internet
route, clients matching `OCP_VERSION`, every DNS answer, time, and the registry over verified TLS.
*If skipped:* a gap here surfaces as a stalled ISO build in Lab 08.

**EDIT** — None.

**DO** — `./scripts/00-prerequisites-check.sh --bastion`

**VERIFY** — Last line `Results: N passed, 0 failed`.

**FAILS IF** — `no route to the internet` fails ← the machine network routes out; fix before going on.

Detail: [MVP DNS and NTP](detail/mvp-dns-ntp.md)

## Next

→ [08 — Generating Install and Agent Configuration](08-install-agent-config.md)
