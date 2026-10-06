# Configure `.env` (field-by-field detail)

> Used from [Lab 03 — Site Checklist](../03-checklist.md).  
> Tutorial index: [README Labs](../../../README.md#labs).

## Goal

Create a site-specific `.env` and change **only** the values that match your lab.

## WHERE

Staging machine (Fedora laptop or RHEL 10 KVM) — same place you will run the mirror later.

```bash
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment
cp .env.example .env
vim .env
```

## WHY this lab exists

Every script reads `.env`. If MAC addresses or IPs are still the sample placeholders, the Agent installer will look for servers that do not exist. Editing `.env` once drives Kickstart notes, DNS records, and `agent-config.yaml` generation.

## DO — open the file

Inside `vim`:

- Move with arrow keys  
- Press `i` to insert  
- Edit the value after `=`  
- Press `Esc`, then type `:wq` and Enter to save and quit  

Do **not** put spaces around `=`.

---

## Fields you almost always must change

Work top to bottom. Leave a field alone only if the sample value is already correct for your site.

### 1) Cluster identity

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `CLUSTER_NAME` | `ocpv-lab` | Short name, letters/numbers/hyphen | Becomes part of DNS: `api.<CLUSTER_NAME>.<BASE_DOMAIN>` |
| `BASE_DOMAIN` | `ocp-v.local` | Your lab DNS domain | All hostnames hang under this |
| `OCP_VERSION` | `4.22.2` | Exact z-stream from [mirror.openshift.com clients](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/) | Tools and release images must match |
| `OCP_CHANNEL` | `stable-4.22` | Usually leave as-is for 4.22 | oc-mirror channel |

**Example edit:**

```bash
CLUSTER_NAME=coe01
BASE_DOMAIN=lab.example.com
OCP_VERSION=4.22.10
OCP_CHANNEL=stable-4.22
```

### 2) Network basics

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `NETWORK_CIDR` | `10.10.0.0/16` | Your install subnet/CIDR | Firewall and chrony `allow` ranges |
| `NETWORK_GATEWAY` | `10.10.0.1` | Default gateway for nodes | Without it, nodes cannot reach registry/bastion off-subnet |
| `NETWORK_NETMASK` | `255.255.0.0` | Must match CIDR | Kickstart/static IP helpers |
| `NETWORK_INTERFACE` | `ens192` | Real NIC name from `ip link` on a node | Wrong name → no network after install |

**How to learn the NIC name (on a temporary live USB or existing OS):**

```bash
ip -br link
# pick the data NIC, e.g. ens1f0, eno1, eth0
```

### 3) Bastion and registry

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `BASTION_IP` | `10.10.0.5` | Static IP of helper / installer host | Temp DNS/NTP + `openshift-install` run here |
| `MIRROR_REGISTRY_IP` | `10.10.0.10` | Static IP of registry host | Cluster pulls images from here |
| `MIRROR_REGISTRY` | `10.10.0.10:443` | `IP:port` or `hostname:port` | mirror-registry for RH OpenShift uses **443** by default |
| `MIRROR_REGISTRY_HOSTNAME` | `registry.ocp-v.local` | Hostname nodes will use | Must resolve via bastion DNS |
| `MIRROR_REGISTRY_USER` | `init` | Registry admin user | Created when registry is installed |
| `MIRROR_REGISTRY_PASSWORD` | `changeme` | **Change this** | Used to push/pull mirrored images |

If bastion and registry are **one machine**, set both IPs to that machine’s IP and adjust later docs accordingly.
**Do not do this if the bastion will be disconnected after cutover.** The cluster pulls
images from the registry for its whole life ([Bastion Lifecycle](../../BASTION-LIFECYCLE.md), hard constraints).

### 4) VIPs (virtual IPs — not a physical server)

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `API_VIP` | `10.10.0.100` | Unused IP on the machine network | Clients use this for `oc login` / API |
| `INGRESS_VIP` | `10.10.0.101` | Different unused IP | `*.apps.<cluster>.<domain>` |

**WHY VIPs:** Agent-based bare metal does not require an external load balancer. These addresses float for API and router.

### 5) Rendezvous IP

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `RENDEZVOUS_IP` | `10.10.1.11` | **Must equal one control-plane node IP** (usually `CP01_IP`) | That node temporarily runs Assisted Service during install |

### 6) Control plane and workers — IPs, hostnames, MACs

For **each** node, set IP and **real MAC address**.

| Variable | What to put | Why |
|---|---|---|
| `CP01_IP` … `CP03_IP` | Static IPs | Written into `agent-config.yaml` |
| `CP01_MAC` … `CP03_MAC` | From BMC inventory or `ip link` | Agent matches the physical NIC |
| `WK01_IP` / `WK02_IP` | Static IPs | Workers host OCP-V VMs |
| `WK01_MAC` / `WK02_MAC` | Real MACs | Same as above |

**How to get a MAC on bare metal:** BMC inventory, or boot a live USB and run:

```bash
ip -br link
# look at the data NIC line, e.g. ens192  UP  aa:bb:cc:dd:ee:ff
```

Replace samples like `00:50:56:00:00:11` (those are placeholders).

### 7) Production DNS/NTP VM IPs (post-install)

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `DNS_VM_IP` | `10.10.0.50` | Free IP for future DNS VM on OCP-V | Pre-create DNS records now |
| `NTP_VM_IP` | `10.10.0.51` | Free IP for future NTP VM | Same |

You can leave these as samples if they do not collide with real hosts.

### 8) Paths on staging

| Variable | Sample | What to put | Why |
|---|---|---|---|
| `MIRROR_DIR` | `/opt/ocp-mirror` | Directory with space for the mirror | Staging workspace |
| `PULL_SECRET_FILE` | `${MIRROR_DIR}/pull-secret.json` | Where you will copy the pull secret | Scripts look here |

After saving `.env`:

```bash
sudo mkdir -p /opt/ocp-mirror
sudo cp ~/Downloads/pull-secret.json /opt/ocp-mirror/pull-secret.json
# or wherever you saved the pull secret — adjust path
sudo chown "$USER:$USER" /opt/ocp-mirror/pull-secret.json
```

### 9) Usually leave alone for first lab

| Variable | Why leave default |
|---|---|
| `OPERATOR_CATALOG` | Must stay `.../redhat-operator-index:v4.22` for OCP 4.22 |
| `CNV_PACKAGE` / `CNV_CHANNEL` | Official Virtualization package on `stable` |
| `SSH_USER=core` | RHCOS default user after install |
| `DNS_SERVER` / `NTP_SERVER` | Point at bastion during install via `${BASTION_IP}` |

---

## VERIFY

```bash
# From repo root — does the shell load your values?
set -a && source .env && set +a
echo "Cluster: ${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "OCP: ${OCP_VERSION}"
echo "Bastion: ${BASTION_IP}  Registry: ${MIRROR_REGISTRY}"
echo "Rendezvous: ${RENDEZVOUS_IP} (should match CP01: ${CP01_IP})"
echo "CP01 MAC: ${CP01_MAC}"
test -f "${PULL_SECRET_FILE}" && echo "Pull secret: OK" || echo "Pull secret: MISSING"
```

Checklist:

- [ ] `RENDEZVOUS_IP` equals `CP01_IP` (or whichever CP you chose)  
- [ ] No two hosts share an IP  
- [ ] Every `*_MAC` is a real interface, not the sample  
- [ ] `NETWORK_INTERFACE` matches real NIC names (or you will fix per-node later in agent-config)  
- [ ] Pull secret file exists at `PULL_SECRET_FILE`  

## FAILS IF

| Mistake | Symptom later |
|---|---|
| Left sample MACs | Agent ISO boots; zero hosts discovered |
| `RENDEZVOUS_IP` not a CP IP | Install hangs at bootstrap |
| Wrong `OCP_VERSION` | Client download 404 from mirror.openshift.com |
| Pull secret path wrong | Mirror script exits immediately |

## Next

→ [Lab 03 — Site Checklist](../03-checklist.md) · [Lab 06 — Mirroring](../06-mirroring-images.md)
