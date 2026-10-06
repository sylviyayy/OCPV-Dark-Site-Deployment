# 03 — Site Worksheet (mandatory)

## Goal

Fill every required field before cabling or generating an Agent ISO.

## WHERE

Copy values into `.env` with `vim` after (or while) filling the worksheet.

```bash
cd OCPV-Dark-Site-Deployment
vim .env
```

## WHY

Agent-based install binds nodes by **MAC + static IP**. Wrong MAC ⇒ ISO boots, zero hosts join.  
Switch MLAG / LUN masking mistakes are not fixable in `install-config.yaml`.

## DO — complete the full worksheet

Use the partner form (print or edit):

→ **[greenfield/01-information-gathering-worksheet.md](../greenfield/01-information-gathering-worksheet.md)**

Then apply values into `.env` using the field-by-field guide:

→ **[Field-by-field `.env` guide](detail/configure-site-env.md)**

### Minimum fields for this 3-node Lenovo rack

| Field | Example | Notes |
|---|---|---|
| `CLUSTER_NAME` / `BASE_DOMAIN` | `coe01` / `lab.example.com` | DNS names |
| `OCP_VERSION` | `4.22.x` | Pin z-stream from mirror.openshift.com |
| `BASTION_IP` | jumpbox IP | Temp DNS/NTP + installer |
| `MIRROR_REGISTRY_IP` | registry IP | **Must differ from `BASTION_IP`** if the bastion will be disconnected after cutover ([Bastion Lifecycle](../BASTION-LIFECYCLE.md)). It may equal the bastion only in throwaway labs |
| `API_VIP` / `INGRESS_VIP` | unused IPs | Not assigned to a NIC permanently |
| `RENDEZVOUS_IP` | = `CP01_IP` | Must be one control-plane IP |
| `MW01_*` … `MW03_*` | IP + **real MAC** per data bond/NIC | From XCC inventory or live USB `ip link` |
| Switch Po / MLAG IDs | from network team | Must match server `bond0` LACP |
| BMC IPs | per server | For virtual CD |
| OS disk | RAID1 VD → e.g. `/dev/sda` | `rootDeviceHints` |
| LUN / IQN | if SAN used | Masking only to these three nodes |

### NIC reminder (fill MACs from the ports you actually cable)

| Server | Ports available |
|---|---|
| Each SR665 V3 | 4-port OCP + 2-port Slot 1 (= 6× 10GBase-T) |
| SR675 V3 | 4-port OCP + 4-port Slot 21 (= 8× 10GBase-T) |

Document which ports join `bond0` / which switch Po members — see [Lab 05](05-compute-resources.md).

## VERIFY

```bash
set -a && source .env && set +a
echo "${CLUSTER_NAME}.${BASE_DOMAIN}  OCP=${OCP_VERSION}"
echo "Rendezvous ${RENDEZVOUS_IP} vs CP01 ${CP01_IP}"
echo "MACs: ${CP01_MAC} ${CP02_MAC} ${CP03_MAC}"
```

- [ ] Worksheet signed by hardware + network (+ storage if SAN)  
- [ ] No sample MACs left (`00:50:56:…` placeholders gone)  
- [ ] `RENDEZVOUS_IP` equals a CP IP  

## FAILS IF

Skipped “until later” → regenerate ISO after fixing MACs, or reinstall nodes.

## Next

→ [04 — Setting up the Bastion](04-bastion.md)
