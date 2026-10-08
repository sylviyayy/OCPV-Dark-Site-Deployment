# 03 — Site Worksheet (mandatory)

## Goal

Fill every required field for **this Lenovo CoE rack** before cabling or booting the
offline OVE agent ISO (`agent.ove.x86_64`, OpenShift **4.21.27**).

## WHERE

Copy values into `.env` with **`vim`** after (or while) filling the worksheet.

```bash
cd OCPV-Dark-Site-Deployment
vim .env
```

## WHY

Assisted / Agent-based install binds nodes by **MAC + static IP** (and your bond/nmstate).
Wrong MAC ⇒ ISO boots, zero hosts join. Wrong VIP ⇒ DNS and API never line up.
This worksheet is for a **lean team** (no separate network/storage orgs) — collect by
**function**, not by “wait for another team.”

## DO — complete the full worksheet

Partner / CoE form (print or edit):

→ **[greenfield/01-information-gathering-worksheet.md](../greenfield/01-information-gathering-worksheet.md)**

Then apply values into `.env`:

→ **[Field-by-field `.env` guide](detail/configure-site-env.md)**

### Minimum fields for this 3-node Lenovo rack

| Field | Example | Why it matters / when |
|---|---|---|
| `CLUSTER_NAME` / `BASE_DOMAIN` | `coe01` / `lab.example.com` | Builds `api.` and `*.apps.` names — Lab 07 DNS and Assisted cluster identity |
| `OCP_VERSION` | **`4.21.27`** | Must match the console OVE download; skew breaks expectations and supportability |
| `BASTION_IP` | bastion IP | Install-time DNS/NTP; without it bootstrap name/time fail (Lab 07) |
| `MIRROR_REGISTRY_IP` | registry IP or unused if OVE-only | Required only for optional mirror path; must ≠ bastion if bastion will leave |
| `API_VIP` / `INGRESS_VIP` | unused IPs | Floating API and router addresses — not assigned to a physical NIC |
| `RENDEZVOUS_IP` | = `mw01` (or chosen CP) IP | That node runs Assisted Service first (Lab 10) |
| `MW01_*` … `MW03_*` | IP + **primary install MAC** | Discovery identity; also record **all** port MACs in the worksheet |
| Switch Po / MLAG IDs | from your switch config | Must match server `bond0` LACP or the bond never comes up (Lab 05) |
| BMC IPs | per server | Virtual CD for `agent.ove.x86_64` |
| OS disk | RAID1 VD → e.g. `/dev/sda` | `rootDeviceHints` / disk selection |
| LUN / IQN | if SAN used | Same lean team masks LUNs — wrong mask = no VM disks later |

### NIC reminder — inventory **all** ports, cable a subset

| Server | Ports available |
|---|---|
| Each SR665 V3 (`mw01`, `mw02`) | 4-port OCP + 2-port Slot 1 = **6×** 10GBase-T |
| SR675 V3 (`mw03`) | 4-port OCP + 4-port Slot 21 = **8×** 10GBase-T |

Do **not** stop at “NIC1/NIC2 port 1–2.” Record every MAC in the worksheet, mark which
ports join `bond0`, and leave spares documented — see [Lab 05](05-compute-resources.md).

## VERIFY

```bash
set -a && source .env && set +a
echo "${CLUSTER_NAME}.${BASE_DOMAIN}  OCP=${OCP_VERSION}"
echo "Rendezvous ${RENDEZVOUS_IP} vs MW01 ${CP01_IP}"
echo "MACs: ${CP01_MAC} ${CP02_MAC} ${CP03_MAC}"
```

- [ ] Worksheet signed by **function** (hardware, network, storage if used, media)  
- [ ] `OCP_VERSION=4.21.27`  
- [ ] No sample MACs left (`00:50:56:…` placeholders gone)  
- [ ] `RENDEZVOUS_IP` equals a compact-node IP  
- [ ] All physical port MACs recorded even if not all are cabled  

## FAILS IF

Skipped “until later” → re-discover hosts or reinstall after fixing MACs/IPs.

## Next

→ [04 — Setting up the Bastion](04-bastion.md)
