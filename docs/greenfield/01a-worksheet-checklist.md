# Worksheet Completion Checklist

> Companion to the [Information Gathering Worksheet](01-information-gathering-worksheet.md).
> The worksheet **records** the values. This checklist **proves** they are complete, valid and
> mutually consistent. Run it before anyone signs the worksheet.

## Goal

Turn the worksheet from "filled in" into "fit to build from". Every value the Agent
installer, the switches and the SAN will consume is checked once, by its owner, against its
source of truth.

## WHERE

- **Sections 0–7:** a review meeting with the hardware, network, storage and OpenShift
  owners, worksheet on screen.
- **VERIFY:** the staging machine, after the values are transcribed into `.env`
  ([field-by-field guide](../labs/detail/configure-site-env.md)).

## WHY

Treat this like an aviation **pre-flight checklist**, run as *challenge and response*. The
worksheet is the flight plan. One person reads each item aloud (the challenge). The owner
answers from the source of truth (XCC/iDRAC/iLO inventory, switch running-config, SAN
console), never from memory (the response).

The cost of an error depends on when it is caught:

| Caught at | Cost |
|---|---|
| This checklist | Edit one cell |
| Cabling / switch config | Re-cable, re-configure a port-channel |
| After T-0 (agent ISO built) | Rebuild the ISO inside the 24-hour window ([Bastion Lifecycle](../BASTION-LIFECYCLE.md)) |
| After install | Reinstall the node or the cluster |

### Three passes

Run the sections below in three passes. Each pass asks a different question:

| Pass | Question | Typical catch |
|---|---|---|
| 1. **Completeness** | Is every required cell filled? | Blank cells, "TBD", "same as above" |
| 2. **Validity** | Is each value correct on its own? | Malformed MAC, VIP outside the machine network |
| 3. **Consistency** | Do values agree across sections and teams? | Po ID differs between server and switch, IQN missing from the masking group |

A cell that does not apply is marked **N/A with a reason** (for example "N/A: no SAN,
local disks only"). A blank cell is never read as N/A.

---

## 0. Entry criteria

- [ ] The customer is qualified: the [brownfield contrast appendix](appendix-brownfield-contrast.md) confirms this repo applies
- [ ] The track (A / B / C) is chosen per [DEPLOYMENT-TRACKS.md](../DEPLOYMENT-TRACKS.md) and recorded in *Site metadata*
- [ ] One accountable name exists for each sign-off row: hardware, network, storage, OpenShift lead
- [ ] The pull secret is downloaded, stored outside the repository, and contains `"auths"` ([Lab 01](../labs/01-prerequisites-assumptions.md))

---

## 1. Site metadata

- [ ] **Customer / site name** and **partner engineer** are filled
- [ ] **Target track** is a single letter, not "A/B/C"
- [ ] **OCP version** is an exact z-stream (`4.22.z`, e.g. `4.22.2`), not `4.22.x`. It is the release you will mirror
- [ ] **Cluster name** is a valid DNS label (RFC 1123): lowercase letters, digits and hyphens, starting and ending with a letter or digit. Keep it short; it becomes part of every route hostname
- [ ] **Base domain** is a domain the site will be authoritative for (bastion DNS during install, the DNS VM afterwards)
- [ ] **Base domain** does not end in `.local` outside a throwaway lab. RFC 6762 reserves `.local` for multicast DNS, and mDNS-aware resolvers may never send those queries to unicast DNS

---

## 2. Per-server inventory (repeat for every node)

**Count first.** The number of node blocks equals the planned topology: 5 for Track A
(3 control plane + 2 workers), 3 for compact, 1 for SNO.

### Identity

- [ ] **Role** is `master` or `worker`. There are exactly 3 `master` nodes (etcd quorum) unless the track is SNO. Compact: all three are `master`
- [ ] **Hostname** is unique, is a valid DNS label, and matches the `.env` hostname variable for that node
- [ ] **Serial / asset tag** is read from the chassis label or the BMC, not from the purchase order

### BMC

- [ ] **BMC IP** is static, unique, and on the management network, not the machine network
- [ ] **BMC type** is recorded (XCC / iDRAC / iLO)
- [ ] **BMC username** is a vault reference. No password appears anywhere on the worksheet

### NICs and bond

- [ ] All **four bond-member MACs** are filled, read from BMC inventory or from `ip -br link` on a live USB boot
- [ ] Every MAC has the form `xx:xx:xx:xx:xx:xx` (six hexadecimal octets) and is **unique across the whole site**
- [ ] No MAC starts with `00:50:56`. That prefix is VMware's OUI and only appears in this repo's samples; a physical NIC will never carry it
- [ ] The MACs belong to the ports that will be **cabled**, not to spare ports. The Agent installer maps a booted host to its configuration block by `interfaces[].macAddress` in `agent-config.yaml`. A wrong MAC means the ISO boots and the host never joins
- [ ] Bond members are **split across both switches**: two members land on Switch A and two on Switch B
- [ ] **Bond name** is `bond0` and **bond mode** is `802.3ad` on every node

### Layer 3

- [ ] **Node IP / prefix** is unique, inside the machine network, and outside any DHCP pool. The prefix length is identical on every node
- [ ] **Gateway** is identical on every node and inside the machine network
- [ ] **DNS (install)** equals the bastion IP on every node

### Disks and SAN identity

- [ ] **OS disk device** is the RAID1 virtual disk, confirmed from the RAID controller or a live boot, not assumed to be `/dev/sda`. If the name can shift (for example when virtual media enumerates first), also record the virtual disk's WWN or serial number as a fallback `rootDeviceHints` key
- [ ] **iSCSI IQN** is unique per node. For Fibre Channel, record WWPNs instead and say so
- [ ] **Assigned LUN IDs** match the *SAN team worksheet*

---

## 3. Network team worksheet

- [ ] **Machine network VLAN** states a VLAN ID or the literal words "flat L2". A blank is not "flat L2"
- [ ] **BMC VLAN** differs from the machine network (segmentation; see [02-physical-cabling-and-bmc.md](02-physical-cabling-and-bmc.md))
- [ ] **Storage VLAN** (iSCSI) is recorded or marked N/A with a reason
- [ ] **Switch A / Switch B port-channel IDs** are recorded per node, and the network team confirms that **all four members of one node's `bond0` sit in a single MLAG / vPC port-channel spanning both switches**. A Linux `802.3ad` bond activates only one aggregator; members split across two independent port-channels leave half the links idle or the bond degraded
- [ ] **API VIP** and **Ingress VIP** are distinct, inside the machine network, not assigned to any host, and outside any DHCP pool
- [ ] **Bastion IP** and **Registry IP** are static and distinct. They may be equal only in a throwaway lab: if the bastion is disconnected after cutover, the cluster still pulls from the registry for its whole life ([Bastion Lifecycle](../BASTION-LIFECYCLE.md))
- [ ] **DNS VM IP** and **NTP VM IP** (post-install) are reserved now and not handed to anything else
- [ ] **MTU** is a single agreed value for the machine network, and the switch ports carry at least that MTU. If jumbo frames are used, they are set end to end, including the bastion and registry. OVN-Kubernetes derives the pod MTU from it (machine MTU − 100 bytes of Geneve overhead), so do not plan a separate pod MTU
- [ ] The workstation that will mount the agent ISO can reach every BMC (HTTPS and the vendor's virtual-media ports are permitted)

---

## 4. SAN team worksheet

Mark the whole section N/A with a reason if no SAN is used.

- [ ] **Protocol** is iSCSI or FC, and the per-node identifiers match it (IQNs for iSCSI, WWPNs for FC)
- [ ] **Target portal(s)**: at least two, on independent paths, so that multipath has something to fail over to
- [ ] **LUN name / ID** and **size** are recorded, and the size matches the agreed sizing for VM disks
- [ ] **Masking group** contains **exactly** the cluster nodes' IQNs/WWPNs: no extra host (data-corruption and security risk), no missing node (PVC mount failures)
- [ ] **CHAP**, if used, is a vault reference only. Record whether it is one-way or mutual

---

## 5. Cluster install

- [ ] **rendezvousIP** equals exactly one control-plane node's IP. It is not a VIP, not a worker, and not the bastion
- [ ] **Pull secret path** is a path outside the repository. The file itself is never committed (`.gitignore` covers `pull-secret.json`)
- [ ] **SSH public key path** is recorded, and the OpenShift lead holds the matching private key **at the site**
- [ ] **Mirror registry hostname** is an FQDN under the base domain, will resolve through bastion DNS, and matches a Subject Alternative Name in the registry's TLS certificate
- [ ] **Mirror registry CA path** points to the CA that signed the registry certificate (it goes into `additionalTrustBundle`)

---

## 6. Cross-section consistency (pass 3)

| Check | Compare |
|---|---|
| Every IP on the worksheet is unique | Node IPs, BMC IPs, VIPs, gateway, bastion, registry, DNS VM, NTP VM |
| Node count agrees everywhere | Per-server blocks = masking-group members = port-channels = `.env` nodes |
| Every node's DNS (install) is the bastion | Per-server *DNS (install)* vs *Network: Bastion IP* |
| Registry identity agrees | *Network: Registry IP* vs *Cluster install: Mirror registry hostname* (the hostname resolves to that IP) |
| MTU agrees | *Network: MTU* vs switch running-config vs storage VLAN (if iSCSI) |
| LUN IDs agree | Per-server *Assigned LUN IDs* vs *SAN: LUN name / ID* |
| Rendezvous node is a master | *Cluster install: rendezvousIP* vs the node block that has that IP and `Role = master` |

---

## 7. Not on the form, but needed: confirm anyway

The worksheet form has no row for these values, yet later labs consume them. Record each in
the worksheet's margin or notes, or the gap reappears at T-0.

| Item | Consumed by | Owner |
|---|---|---|
| Machine network CIDR and netmask (`NETWORK_CIDR`, `NETWORK_NETMASK`) | `install-config.yaml` `machineNetwork`, chrony `allow`, firewall | Network |
| Real NIC interface names (`NETWORK_INTERFACE`, per node if they differ) | `agent-config.yaml` `interfaces[].name` | Hardware |
| Topology: standard (3 + 2) or compact (3 + 0) | `install-config.yaml` replicas | OpenShift lead |
| BIOS/UEFI virtualization (AMD-V / VT-x) enabled on every node that runs VMs | OpenShift Virtualization (`/dev/kvm`) | Hardware |
| RAID1 virtual disk built on every node | `rootDeviceHints` | Hardware |
| BMC clocks set to UTC | Go/no-go gate in [Bastion Lifecycle](../BASTION-LIFECYCLE.md) | Hardware |
| Storage consumption decision (LVMS, or the partner SAN CSI driver) | `ImageSetConfiguration`, which must contain the operator **before departure** ([USB Transfer Kit](../USB-TRANSFER-KIT.md)) | Storage + OpenShift lead |
| Mirror registry admin credentials (vault reference) | `oc mirror` disk-to-mirror, pull-secret merge | OpenShift lead |
| Site time source: free-running orphan mode, or a GPS/PTP reference | Risk R3 in [Bastion Lifecycle](../BASTION-LIFECYCLE.md) | Network |

---

## 8. Secrets hygiene

- [ ] No password, CHAP secret, pull-secret content or private key appears on the worksheet. Only vault references
- [ ] A filled worksheet is customer-confidential. It is not committed to this public repository; keep it in the customer's document store or a private fork
- [ ] `.env` is never committed (it is listed in `.gitignore`)

---

## VERIFY: after transcribing into `.env`

**WHERE:** Staging machine, repository root.

```bash
set -a && source .env && set +a

# 1. rendezvousIP must be a control-plane IP
[[ " ${CP01_IP} ${CP02_IP} ${CP03_IP} " == *" ${RENDEZVOUS_IP} "* ]] \
  && echo "PASS rendezvous = control-plane IP" || echo "FAIL rendezvous ${RENDEZVOUS_IP}"

# 2. No sample (VMware OUI) MACs, and every MAC is well formed
grep -nE '^[A-Z0-9]+_MAC=00:50:56:' .env && echo "FAIL sample MACs above" || echo "PASS no sample MACs"
grep -E '^[A-Z0-9]+_MAC=' .env | grep -viE '=([0-9a-f]{2}:){5}[0-9a-f]{2}([[:space:]]|$)' \
  && echo "FAIL malformed MACs above" || echo "PASS MAC format"

# 3. No duplicate IPs or MACs (RENDEZVOUS_IP deliberately repeats a CP IP)
dups=$(grep -E '^[A-Z0-9_]+_(IP|VIP|MAC)=' .env | grep -v '^RENDEZVOUS_IP=' \
  | cut -d= -f2 | awk '{print tolower($1)}' | sort | uniq -d)
[[ -z "${dups}" ]] && echo "PASS no duplicates" || echo "FAIL duplicates: ${dups}"

# 4. Registry must not share the bastion's IP if the bastion will be disconnected
[[ "${MIRROR_REGISTRY_IP}" != "${BASTION_IP}" ]] \
  && echo "PASS registry != bastion" || echo "WARN registry == bastion (throwaway lab only)"
```

For a compact cluster, delete or comment out the unused `WK*` lines first, so the sample
worker MACs do not report as failures.

Once on the install network (before any node is booted), confirm the VIPs are free:

```bash
for vip in "${API_VIP}" "${INGRESS_VIP}"; do
  ping -c2 -W1 "${vip}" >/dev/null && echo "FAIL ${vip} answers: already in use" || echo "PASS ${vip} free"
done
```

## FAILS IF

| Skipped check | Symptom later |
|---|---|
| Sample or wrong MACs | Agent ISO boots; zero hosts discovered |
| `rendezvousIP` not a control-plane IP | Install hangs at bootstrap |
| Bond split across two independent port-channels | Bond degraded or half its links idle; LACP flaps under failover |
| VIP already in use | API or ingress unreachable; intermittent `oc login` failures |
| Masking group too broad / too narrow | Data-corruption risk / PVCs stuck `Pending` |
| Storage operator not decided before departure | Operator missing from the mirror; return trip |
| Registry co-located with a bastion that is later removed | `ImagePullBackOff` after cutover |

## Sign-off rule

Sign the worksheet only when every box in sections 0–8 is ticked or marked N/A with a
reason, and VERIFY reports no `FAIL`.

**Next →** [Sign-off in the worksheet](01-information-gathering-worksheet.md#sign-off), then
[02-physical-cabling-and-bmc.md](02-physical-cabling-and-bmc.md)
