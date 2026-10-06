# 07 — Bootstrapping MVP DNS and NTP

## Goal

Start temporary DNS and NTP on the bastion, then **prove** name lookups work
before you generate the Agent ISO.

## WHERE

Bastion (`BASTION_IP`), dark site.

```bash
cd OCPV-Dark-Site-Deployment
set -a && source .env && set +a
sudo ./scripts/02-bootstrap-dns-ntp.sh
```

## WHY

No enterprise DNS/NTP yet. OpenShift needs name resolution and clock sync for etcd.
This is the greenfield bridge until [Lab 14](14-production-dns-ntp.md).

The bastion's clock becomes the site's time authority (chronyd orphan mode). **Set it to
correct UTC before running the script**, and set node BMC clocks to match
([Bastion Lifecycle, Phase 2](../BASTION-LIFECYCLE.md#phase-2-the-bastion-becomes-the-sole-dns-and-ntp-authority-no-clock)).
Nodes reach this NTP server during install through `additionalNTPSources` in `agent-config.yaml`.

The installer and nodes will query **two default names** that must resolve from day one:

| Name | Must resolve to | Why |
|---|---|---|
| `api.<CLUSTER_NAME>.<BASE_DOMAIN>` | `API_VIP` | Kubernetes API / `oc login` |
| `*.apps.<CLUSTER_NAME>.<BASE_DOMAIN>` (e.g. console) | `INGRESS_VIP` | Routes / OpenShift console |

If either is missing, treat DNS as **not ready**.

With sample `.env` values (`CLUSTER_NAME=ocpv-lab`, `BASE_DOMAIN=ocp-v.local`):

- API: `api.ocpv-lab.ocp-v.local` → `10.10.0.100`
- Apps example: `console-openshift-console.apps.ocpv-lab.ocp-v.local` → `10.10.0.101`

---

## DO — firewall (lab vs production)

DNS (UDP/TCP **53**) and NTP (UDP **123**) must reach the bastion from every OpenShift node IP.

### Lab / CoE (fast path)

For a closed lab VLAN, it is common to **open the path widely** so you are not debugging firewall and DNS at the same time:

```bash
# On the bastion — lab only
sudo systemctl stop firewalld
sudo systemctl disable firewalld
# Or: whitelist the whole install CIDR (from .env NETWORK_CIDR), e.g. 10.10.0.0/16
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --permanent --add-service=ntp
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.10.0.0/16" accept'
sudo firewall-cmd --reload
```

> **Lab tip:** whitelist the install CIDR or temporarily disable firewalld while validating DNS.  
> **Production:** do **not** leave firewalld off. Restrict sources to the OpenShift machine
> network (node IPs + VIPs subnet). Document the allow-list in the checklist.

### Production-minded minimum

Allow from `NETWORK_CIDR` (all cluster nodes) to bastion:

| Port | Protocol | Purpose |
|---|---|---|
| 53 | TCP + UDP | DNS (dnsmasq) |
| 123 | UDP | NTP (chronyd) |

---

## VERIFY — DNS with `nslookup` (primary check)

Run this on the **bastion** or any machine that can reach `BASTION_IP` (a cluster node is ideal).

### 1) Point the query at the bastion

```bash
set -a && source .env && set +a

nslookup
```

Inside the interactive `nslookup` prompt:

```text
server <BASTION_IP>
```

Example if bastion is `10.10.0.5`:

```text
server 10.10.0.5
```

### 2) Query the API URL (required)

```text
api.<CLUSTER_NAME>.<BASE_DOMAIN>
```

Example:

```text
api.ocpv-lab.ocp-v.local
```

**Pass:** answer address = your `API_VIP` (e.g. `10.10.0.100`).  
**Fail:** `NXDOMAIN`, timeout, or SERVFAIL → dnsmasq not listening, wrong server IP, or firewall blocking port 53.

### 3) Query an apps URL (required — the other default name)

OpenShift also needs the apps wildcard. Query a concrete name under `*.apps`:

```text
console-openshift-console.apps.<CLUSTER_NAME>.<BASE_DOMAIN>
```

Example:

```text
console-openshift-console.apps.ocpv-lab.ocp-v.local
```

**Pass:** answer address = your `INGRESS_VIP` (e.g. `10.10.0.101`).  
**Fail:** API works but apps does not → wildcard record missing; re-run the script / check `/etc/dnsmasq.d/ocp-v.conf`.

Type `exit` to leave `nslookup`.

### One-liner form (same checks)

```bash
set -a && source .env && set +a

nslookup "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "${BASTION_IP}"
nslookup "console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" "${BASTION_IP}"
nslookup "registry.${BASE_DOMAIN}" "${BASTION_IP}"
```

Optional with `dig`:

```bash
dig @"${BASTION_IP}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
dig @"${BASTION_IP}" "console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" +short
```

---

## VERIFY — NTP

```bash
chronyc -h "${BASTION_IP}" tracking
```

You should get a tracking response (bastion is the time source in orphan mode). From a node later:

```bash
chronyc sources
# Expect the bastion IP as a reachable source
```

---

## VERIFY — service health on bastion

```bash
sudo systemctl status dnsmasq chronyd --no-pager
sudo ss -ulnp | grep -E ':53|:123'
# Optional: watch queries
sudo tail -f /var/log/dnsmasq.log
```

Confirm both VIP records exist in the generated config:

```bash
grep -E "api\.|apps\." /etc/dnsmasq.d/ocp-v.conf
```

You must see lines for `api.<cluster>.<domain>` **and** `*.apps.<cluster>.<domain>`.

---

## FAILS IF

| Symptom | Likely cause |
|---|---|
| `nslookup` times out | Firewall blocking 53; dnsmasq not running; wrong `server` IP |
| API resolves, apps does not | Wildcard apps record missing |
| Resolves only on bastion, not from nodes | Nodes not using bastion as nameserver yet (fixed in agent-config Lab 08) **or** firewall allows only localhost |
| etcd / bootstrap clock errors later | NTP (123/udp) blocked; bastion/BMC clocks not set to UTC |

## Next

→ [08 — Generating Install and Agent Configuration](08-install-agent-config.md)

**Detail:** [detail/mvp-dns-ntp.md](detail/mvp-dns-ntp.md) · [greenfield/05-bootstrap-services.md](../greenfield/05-bootstrap-services.md) · [Bastion Lifecycle](../BASTION-LIFECYCLE.md)
