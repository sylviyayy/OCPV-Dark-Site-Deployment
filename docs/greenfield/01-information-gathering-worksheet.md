# Information Gathering Worksheet

> **Audience:** A **lean** delivery team (partners / CoE / small SI crew). There are **no
> separate network or storage teams** in this workflow — one small group owns the whole
> rack. Sections below are split by **function** (what you are collecting), not by org chart.
>
> **Hardware context:** Values below are sized for the **reference rack in the
> [README](../../README.md)** — two ThinkSystem **SR665 V3** + one **SR675 V3** (8× L40S),
> compact 3-node OpenShift **4.21.27** + Virtualization, Agent-based / Assisted offline
> install (`agent.ove.x86_64`).

> **STOP:** Do not cable, switch-configure, or boot the agent ISO until every required
> field is filled and the sign-off at the bottom is complete.

Copy this file (or print it) for each deployment. After filling it, copy the same values
into `.env` with `vim` ([Lab 03](../labs/03-checklist.md),
[field guide](../labs/detail/configure-site-env.md)).

---

## How to use each field

Every row below answers four questions:

| Column | Meaning |
|---|---|
| **Value** | What you write down for *this* rack |
| **Used how** | What consumes the value (file, UI, switch, BMC) |
| **If missing / wrong** | What breaks |
| **Stage** | When it first matters |

---

## 1) Site and cluster identity

| Field | Value (fill in) | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| Customer / site name | | Tracking only (handover notes) | Confusion between racks; no install impact | Pre-rack |
| Engineer(s) on site | | Ownership / escalation | No one knows who changed cabling or `.env` | Pre-rack |
| Deployment track | A / B / C (see [tracks](../DEPLOYMENT-TRACKS.md)) | Chooses bare-metal vs optional KVM practice | Wrong track → wrong lab path | Pre-rack |
| **OCP version** | **`4.21.27`** (pin; do not float) | Must match the downloaded `agent.ove.x86_64` / release | Version skew → ISO and payload disagree; install hangs or wrong operators | Connected: Hybrid Cloud Console download |
| **Cluster name** | e.g. `coe01` | DNS labels: `api.<name>.<domain>`, `*.apps.<name>.<domain>`; Assisted / `install-config` `metadata.name` | Rebuild DNS and configs; certs / console URL wrong | DNS (Lab 07) + agent config / Assisted UI |
| **Base domain** | e.g. `lab.example.com` | Suffix for all cluster DNS | Same as above | DNS + install |

---

## 2) Reference host roles (this CoE rack)

| Hostname (example) | Hardware | Role | Fill BMC IP | Fill node IP |
|---|---|---|---|---|
| `mw01` | SR665 V3 | Compact master+worker | | |
| `mw02` | SR665 V3 | Compact master+worker | | |
| `mw03` | SR675 V3 (8× L40S) | Compact master+worker (GPU / heavy VMs) | | |
| `bastion` | Fedora laptop / RHEL KVM / small RHEL host | Temp DNS/NTP + install helper (not a cluster node) | n/a | |

---

## 3) Per-node inventory (duplicate for `mw01`, `mw02`, `mw03`)

### Node hostname: _______________   Model: SR665 V3 / SR675 V3 (circle one)

#### Identity and BMC

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| Role | master (+ worker for compact) | Assisted / `agent-config` host role | Wrong role → wrong replica count or unschedulable GPU node | Agent / Assisted host assignment |
| Serial / asset tag | | RMA / Lenovo support | Support delay only | Ops |
| **BMC IP** | | XCC URL; map `agent.ove.x86_64` as **virtual CD** | Cannot boot ISO without console/virtual media | Lab 05 + Lab 10 |
| BMC credentials | (vault / sealed note — never commit) | XCC login | Blocked at boot day | Lab 05 / 10 |
| BMC network / VLAN | | Reachability from laptop used for install | Virtual media works only if you can reach XCC | Cabling |

#### Networking — record **every** data-plane MAC on the card(s)

The reference NICs are **not** “NIC1/NIC2 with two ports only.” Inventory **all** ports,
then mark which ones you actually cable into the machine-network bond.

**SR665 V3 (`mw01` / `mw02`) — 6× 10GBase-T total**

| Port (physical) | MAC (from XCC or `ip link`) | Cabled? (Y/N) | Switch / Po member | Role in design |
|---|---|---|---|---|
| OCP slot — port 1 | | | | Typical `bond0` slave (Sw A) |
| OCP slot — port 2 | | | | Typical `bond0` slave (Sw B) |
| OCP slot — port 3 | | | | Spare / storage / future — **document** |
| OCP slot — port 4 | | | | Spare / storage / future — **document** |
| Slot 1 — port 1 | | | | Typical `bond0` slave (Sw A) |
| Slot 1 — port 2 | | | | Typical `bond0` slave (Sw B) |

**SR675 V3 (`mw03`) — 8× 10GBase-T total**

| Port (physical) | MAC | Cabled? | Switch / Po member | Role in design |
|---|---|---|---|---|
| OCP slot — port 1 | | | | Typical `bond0` slave (Sw A) |
| OCP slot — port 2 | | | | Typical `bond0` slave (Sw B) |
| OCP slot — port 3 | | | | Spare / document |
| OCP slot — port 4 | | | | Spare / document |
| Slot 21 — port 1 | | | | Typical `bond0` slave (Sw A) |
| Slot 21 — port 2 | | | | Typical `bond0` slave (Sw B) |
| Slot 21 — port 3 | | | | Spare / document |
| Slot 21 — port 4 | | | | Spare / document |

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| **Primary install MAC** (interface Assisted / `agent-config` matches for discovery) | Usually first `bond0` slave or the bond’s effective MAC — **be consistent** | Host identity during discovery | ISO boots; host never appears / wrong host claimed | Lab 08–10 / Assisted host discovery |
| Bond name | e.g. `bond0` | nmstate / Assisted static network | Interface name mismatch → no IP after RHCOS write | Agent network config |
| Bond mode | `802.3ad` (LACP) typical | Must match switch Po mode | LACP suspend → link down mid-install | Switch + agent nmstate |
| Kernel NIC names | e.g. `ens1f0`… (from live boot) | nmstate `interfaces[].name` | Config applies to wrong NIC → blackhole | Agent config |
| Node IP / prefix | | Static address on machine network | Duplicate / wrong IP → API VIP conflict or no registry path | DNS + agent |
| Gateway | | Default route | Node cannot reach bastion DNS/NTP or peers | Agent nmstate |
| DNS (install-time) | Bastion IP | Resolves `api.` / `*.apps.` during bootstrap | etcd / API bootstrap hangs on name lookup | Lab 07 + agent |
| NTP (install-time) | Bastion IP (`additionalNTPSources`) | Clock sync for certs / etcd | Cert skew; bootstrap failures | Lab 07–10 |

> **Why all ports, not only “port 1 and 2”?** Discovery and LACP care about the **exact**
> MACs you cable. Unused ports still have MACs — record them so nobody later plugs a
> “spare” into the wrong Po and hijacks the bond. Lab 05 shows the recommended 4-slave
> bond pattern; unused ports stay documented as spare.

#### Local disk (RHCOS)

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| RAID1 virtual disk | e.g. VD0 → `/dev/sda` | `rootDeviceHints` / Assisted disk selection | OS lands on wrong disk or install refused | Lab 05 + install |
| Disk size check | ≥ Red Hat minimum for compact | Capacity planning | Install fails disk validation | Pre-ISO |

#### Shared storage (optional — same lean team owns this function)

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| Protocol | iSCSI / FC / none (local only) | Day-2 StorageClass / VM disks | DNS/NTP VMs or workloads stay `Pending` | Post-install / Lab 13–14 |
| Node IQN or WWN | | SAN masking | Wrong mask → path down or stolen LUN | SAN + multipath |
| LUN ID / size | | Persistent volumes | Data loss risk if masked to wrong hosts | SAN |
| CHAP / secrets | (vault) | iSCSI login | Auth fail → no volumes | SAN |

---

## 4) Network function (addresses and switching)

Complete even though there is no separate “network team” — this is the **network
function** checklist for the lean crew.

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| Machine network | CIDR / “flat L2” + VLAN ID if any | `machineNetwork` / firewall allow-lists | Nodes on wrong VLAN → discovery fails | Design + Lab 02/07 |
| BMC network | CIDR / VLAN | Reach XCC from install laptop | Cannot attach virtual CD | Lab 05/10 |
| Storage network | VLAN or “same as machine” | iSCSI/FC paths | Storage flaps or shares machine congestion | Cabling / Day-2 |
| Switch A / B Po (MLAG) IDs | | Must match server `bond0` LACP | LACP down → no machine network | Lab 05 |
| Po member ports (switch side) | Map each server cable | Cable audit | Split-brain bonding | Lab 05 |
| **API VIP** | Unused IP on machine net | `api.<cluster>.<domain>` → this IP | `oc login` / console API broken | Lab 07 DNS + install |
| **Ingress VIP** | Different unused IP | `*.apps.<cluster>.<domain>` | Console / routes unreachable | Lab 07 DNS + install |
| **Bastion IP** | | Temp DNS/NTP; Kickstart; scripts | MVP DNS never comes up | Lab 04/07 |
| **Registry IP** (if using mirror-registry path) | ≠ bastion if bastion will leave | Image pulls for life of cluster | After bastion removal, pulls fail | Lab 04/06 — *skip if using OVE self-contained ISO only* |
| DNS VM IP (post-cutover) | | Lab 14 permanent DNS | Cutover has nowhere to land | Lab 14 |
| NTP VM IP (post-cutover) | | Lab 14 permanent NTP | Same | Lab 14 |
| MTU | e.g. 1500 or jumbo | nmstate + switch | Silent packet loss | Agent + switch |

---

## 5) Install media and credentials (OVE offline path)

This hands-on uses the **Assisted Installer offline / OpenShift Virtualization** ISO
(tech preview UI path). See [USB Transfer Kit](../USB-TRANSFER-KIT.md).

| Field | Value | Used how | If missing / wrong | Stage |
|---|---|---|---|---|
| Offline ISO filename | `agent.ove.x86_64` (or console name for **4.21.27** OVE) | Boot via XCC virtual CD / USB | Wrong media → not OVE bundle / wrong version | Connected download → Lab 10 |
| ISO version confirmed | **4.21.27** | Must match worksheet OCP version | Skew with docs/scripts expectations | Pre-departure |
| USB capacity | **≥ 65 GB** (ISO ~58 GB) | Carry ISO across air gap | Copy fails mid-way | Pre-departure |
| USB filesystem | **exFAT** (reformat from FAT/FAT32 if needed) | Single file > 4 GiB | FAT32 rejects the ~58 GB file | Pre-departure |
| **rendezvousIP** | = one of `mw01`/`mw02`/`mw03` node IPs | That node runs Assisted Service first | Bootstrap never forms | Lab 10 / Assisted UI |
| Pull secret | Path on secure media (never git) | Console / cluster pull | Image pull auth failures (path-dependent) | Download + install |
| SSH public key | | `core` user on RHCOS | No node SSH for debug | Install config / Assisted |

---

## 6) Sign-off (by function, same lean team)

| Function | Name | Date | OK? |
|---|---|---|---|
| Hardware / rack / BMC | | | |
| Network (L2, Po, VIPs, DNS plan) | | | |
| Storage (if used) | | | |
| Install media (4.21.27 OVE ISO on exFAT USB) | | | |
| Overall go / no-go | | | |

**All functions OK → proceed to** [02-physical-cabling-and-bmc.md](02-physical-cabling-and-bmc.md)
and [Lab 03](../labs/03-checklist.md).
