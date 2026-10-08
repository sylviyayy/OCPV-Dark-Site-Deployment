# Configure `.env` (field-by-field detail)

> Used from [Lab 03 — Site Checklist](../03-checklist.md).  
> Tutorial index: [README Labs](../../../README.md#labs).  
> Full rationale tables: [information gathering worksheet](../../greenfield/01-information-gathering-worksheet.md).

## Goal

Create a site-specific `.env` for the **reference Lenovo rack** (2× SR665 V3 + 1× SR675 V3)
and OpenShift **4.21.27** offline OVE install.

## WHERE

Staging machine (Fedora laptop or RHEL 10 KVM) — before you travel with the USB.

```bash
git clone https://github.com/sylviyayy/OCPV-Dark-Site-Deployment.git
cd OCPV-Dark-Site-Deployment
cp .env.example .env
vim .env
```

## WHY this lab exists

Scripts and generated configs read `.env`. Sample MACs/IPs point at machines that do not
exist. Editing once drives DNS records, Kickstart notes, and (on the optional mirror path)
`agent-config.yaml` generation.

## DO — open the file with `vim`

- Move with arrow keys  
- Press `i` to insert  
- Edit the value after `=`  
- Press `Esc`, then type `:wq` and Enter to save and quit  

Do **not** put spaces around `=`.

---

## Fields you almost always must change

### 1) Cluster identity

| Variable | Sample | What to put | How it is used | If wrong | Stage |
|---|---|---|---|---|---|
| `CLUSTER_NAME` | `ocpv-lab` | Short DNS label | `api.<name>.<domain>`, Assisted cluster name | Console/API URLs wrong; DNS rebuild | Lab 07 + install |
| `BASE_DOMAIN` | `ocp-v.local` | Your lab domain | Suffix for all cluster DNS | Same | Lab 07 + install |
| `OCP_VERSION` | **`4.21.27`** | Exact z-stream | Must match `agent.ove.x86_64` download | Version skew / support confusion | Console download |
| `OCP_CHANNEL` | `stable-4.21` | Leave for 4.21 | Optional oc-mirror channel | Mirror path only | Lab 06 (optional) |

```bash
CLUSTER_NAME=coe01
BASE_DOMAIN=lab.example.com
OCP_VERSION=4.21.27
OCP_CHANNEL=stable-4.21
```

### 2) Network basics

| Variable | Sample | How it is used | If wrong | Stage |
|---|---|---|---|---|
| `NETWORK_CIDR` | `10.10.0.0/16` | Firewall allow / chrony `allow` | Bastion blocks node DNS/NTP | Lab 07 |
| `NETWORK_GATEWAY` | `10.10.0.1` | Default route in nmstate | Nodes cannot reach bastion/peers | Agent network |
| `NETWORK_NETMASK` | `255.255.0.0` | Must match CIDR | Wrong mask → one-way traffic | Kickstart / nmstate |
| `NETWORK_INTERFACE` | `ens192` | Hint for first NIC name | Prefer per-port names from live boot in the worksheet | Agent nmstate |

Learn names after a live boot: `ip -br link`.

### 3) Bastion and registry

| Variable | How it is used | If wrong | Stage |
|---|---|---|---|
| `BASTION_IP` | Temp DNS/NTP; scripts | Bootstrap name/time fail | Lab 04/07 |
| `MIRROR_REGISTRY_*` | Optional mirror path image pulls | Ignore for OVE-primary day-1; required if you run Lab 06 mirror | Lab 06 / lifecycle |

If the bastion will leave the network, never co-locate the only registry on it
([Bastion Lifecycle](../../BASTION-LIFECYCLE.md)).

### 4) VIPs

| Variable | How it is used | If wrong | Stage |
|---|---|---|---|
| `API_VIP` | Target of `api.<cluster>.<domain>` | `oc login` / API broken | Lab 07 DNS + install |
| `INGRESS_VIP` | Target of `*.apps.<cluster>.<domain>` | Console/routes broken | Lab 07 DNS + install |

These are **unused** addresses on the machine network — not tied to one physical NIC.

### 5) Rendezvous IP

| Variable | How it is used | If wrong | Stage |
|---|---|---|---|
| `RENDEZVOUS_IP` | Must equal one compact node IP (`CP01_IP` / mw01 typical) | Assisted Service never anchors | Lab 10 |

### 6) Nodes — IPs and **primary** MACs (`.env`)

`.env` keeps one **primary install MAC** per node (what discovery matches). The worksheet
still records **all** physical ports (6 on each SR665, 8 on the SR675).

| Variable | Maps to | How it is used | If wrong | Stage |
|---|---|---|---|---|
| `CP01_IP` / `CP01_MAC` | `mw01` (SR665) | Static IP + discovery MAC | Host missing or wrong identity | Lab 08–10 |
| `CP02_IP` / `CP02_MAC` | `mw02` (SR665) | Same | Same | Lab 08–10 |
| `CP03_IP` / `CP03_MAC` | `mw03` (SR675) | Same | Same | Lab 08–10 |
| `WK01_*` / `WK02_*` | Unused in 3-node compact | Leave or ignore | — | — |

Get MACs from XCC inventory or live USB: `ip -br link`. Replace `00:50:56:…` samples.

Bond slaves and spare ports: fill the **full port tables** in
[01-information-gathering-worksheet.md](../../greenfield/01-information-gathering-worksheet.md)
— not only “port 1 and 2.”

### 7) Production DNS/NTP VM IPs (post-install)

| Variable | How it is used | If wrong | Stage |
|---|---|---|---|
| `DNS_VM_IP` / `NTP_VM_IP` | Lab 14 permanent services | Cutover has no landing IPs | Lab 14 |

### 8) Paths / pull secret

| Variable | How it is used | If wrong | Stage |
|---|---|---|---|
| `MIRROR_DIR` / `PULL_SECRET_FILE` | Staging workspace; secret path | Mirror scripts fail; OVE path may still want secret on USB | Pre-departure |

### 9) Usually leave alone for first lab

| Variable | Why |
|---|---|
| `OPERATOR_CATALOG=...:v4.21` | Matches 4.21 catalogs on optional mirror path |
| `CNV_PACKAGE` / `CNV_CHANNEL` | OVE media already carries Virtualization; keep for optional scripted install |
| `SSH_USER=core` | RHCOS default |
| `DNS_SERVER` / `NTP_SERVER` | Bastion during install |

---

## VERIFY

```bash
set -a && source .env && set +a
echo "Cluster: ${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "OCP: ${OCP_VERSION}"
echo "Bastion: ${BASTION_IP}  Registry: ${MIRROR_REGISTRY}"
echo "Rendezvous: ${RENDEZVOUS_IP} (should match CP01: ${CP01_IP})"
echo "CP01 MAC: ${CP01_MAC}"
test -f "${PULL_SECRET_FILE}" && echo "Pull secret: OK" || echo "Pull secret: check USB/secrets"
```

- [ ] `OCP_VERSION=4.21.27`  
- [ ] `RENDEZVOUS_IP` equals a compact-node IP  
- [ ] Primary `*_MAC` values are real  
- [ ] Worksheet has **all** NIC port MACs for mw01–mw03  

## FAILS IF

| Mistake | Symptom later |
|---|---|
| Left sample MACs | Agent/OVE boots; zero hosts discovered |
| `RENDEZVOUS_IP` not a node IP | Install hangs at bootstrap |
| `OCP_VERSION` ≠ downloaded media | Confusion / wrong assumptions vs console file |
| Only recorded 2 of 6 (or 8) port MACs | Later cable into “spare” breaks LACP mystery |

## Next

→ [Lab 03 — Site Checklist](../03-checklist.md) · [USB Transfer Kit](../../USB-TRANSFER-KIT.md)
