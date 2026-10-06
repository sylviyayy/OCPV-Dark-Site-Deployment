# 03 — Site Checklist

> **Grade:** production discipline: the same rules check a lab and a customer site.

## Goal

Decide and sign the pre-defined fields, write them to `.env`, and prove them with `validate-env.sh`
before anyone cables a server.

## Why fix these first

The Agent ISO freezes node identity (MAC → IP → hostname → role), the VIPs and the registry
mirrors at build time. Change one later and you rebuild the ISO and re-boot every node; change
`CLUSTER_NAME` or `BASE_DOMAIN` after install and you reinstall. Treat the register as the **bill
of materials**: a production line does not start with parts unordered. You edit `.env` only;
every other file is generated from it.

## Field register

| # | `.env` key | Owner | Example | Lands in (file → key) | Rule enforced | v2 change |
|---|---|---|---|---|---|---|
| A1 | `CLUSTER_NAME` | OpenShift lead | `ocpv-poc` | install-config → `metadata.name`; agent-config → `metadata.name` | Lowercase RFC 1123 label | Keep |
| A2 | `BASE_DOMAIN` | DNS owner | `example.com` | install-config → `baseDomain` | Not `.local` (reserved for mDNS, RFC 6762). `example.com` is accepted with a warning: it cannot change after install | New default |
| A3 | `OCP_VERSION` | OpenShift lead | `4.22.z` | ImageSet `minVersion`/`maxVersion`; client download path | Exact z-stream present in `stable-4.22` at mirror time | Keep |
| A4 | `OCP_CHANNEL` | OpenShift lead | `stable-4.22` | ImageSet `channels[0].name` | Minor equals `OCP_VERSION` minor | Keep |
| B1 | `MACHINE_NETWORK_CIDR` | Network | `10.10.10.0/24` | install-config → `networking.machineNetwork[0].cidr`; chrony `allow` | Contains every node, VIP, bastion, registry and VM IP | Renamed from `NETWORK_CIDR` |
| B2 | `NETWORK_GATEWAY` | Network | `10.10.10.1` | agent-config → default route `next-hop-address` | Inside B1 | Keep |
| B3 | `CLUSTER_NETWORK_CIDR`, `SERVICE_NETWORK_CIDR` | Network | `10.128.0.0/14`, `172.30.0.0/16` | install-config → `networking.clusterNetwork`, `serviceNetwork` | No overlap with B1, any routed site range, or OVN-K internal `100.64.0.0/16` and `100.88.0.0/16` | New |
| B4 | `MTU` | Network | `1500` | agent-config → `bond0.mtu` | Equals switch MTU end to end | New |
| B5 | `API_VIP` | Network | `10.10.10.140` | install-config → `platform.baremetal.apiVIPs[0]`; DNS `api`, `api-int` | Inside B1, unused, not pingable before install | Keep |
| B6 | `INGRESS_VIP` | Network | `10.10.10.141` *(placeholder)* | install-config → `platform.baremetal.ingressVIPs[0]`; DNS `*.apps` | Same as B5; differs from B5 | Keep |
| C1 | `MW01_HOSTNAME` … `MW03_HOSTNAME` | Hardware | `mw01` | agent-config → `hosts[n].hostname`; DNS A + PTR | Short name; the README role table uses the same names | Short name, not FQDN |
| C2 | `MW01_IP` … `MW03_IP` | Network | `10.10.10.137` (`.138`, `.139` placeholders) | agent-config → `hosts[n].networkConfig` bond0 IPv4 | Unique; inside B1 | Keep |
| C3 | `MW01_NICS` … `MW03_NICS` | Hardware | `ens1f0=aa:bb:cc:00:01:01,…` (4 pairs) | agent-config → `hosts[n].interfaces[]` and bond0 port list | Exactly the 4 bond members; no `00:50:56` (VMware OUI); names as RHCOS enumerates them | New; replaces `MWn_MAC` and global `NETWORK_INTERFACE` |
| C4 | `MW01_ROOT_DEVICE` … `MW03_ROOT_DEVICE` | Hardware | `/dev/disk/by-path/pci-0000:…` | agent-config → `hosts[n].rootDeviceHints.deviceName` | A stable path to the RAID1 virtual disk; never `/dev/sdX` | New |
| C5 | `MW01_BMC_IP` … `MW03_BMC_IP` | Hardware | `10.10.20.11` *(placeholder)* | Checklist; XCC virtual media | Reachable from admin workstation | New |
| C6 | `RENDEZVOUS_IP` | OpenShift lead | `${MW01_IP}` | agent-config → `rendezvousIP` | Equals one of C2 | Keep |
| D1 | `BASTION_HOSTNAME`, `BASTION_IP` | Infrastructure | `bastion`, `10.10.10.135` *(placeholder)* | Kickstart network; DNS | Inside B1 | Keep |
| D2 | `BASTION_IFNAME` | Infrastructure | `eno1` | Kickstart `network --device` | From `ip -br link` on the bastion | New |
| D3 | `MIRROR_REGISTRY_HOSTNAME` | Infrastructure | `registry.example.com` | mirror-registry `--quayHostname`; `imageDigestSources`; DNS | FQDN; resolves via bastion DNS | Keep |
| D4 | `MIRROR_REGISTRY_PORT` | Infrastructure | `8443` | Derived `MIRROR_REGISTRY=${D3}:${D4}`; firewall rule | `8443` (tool default) unless site policy mandates `443` | New |
| D5 | `MIRROR_REGISTRY_IP` | Infrastructure | `10.10.10.136` *(placeholder)* | DNS A record only | May equal `BASTION_IP` only if the bastion is never retired ([Bastion Lifecycle](../BASTION-LIFECYCLE.md)) | Keep |
| D6 | `MIRROR_REGISTRY_USER` | Infrastructure | `init` | mirror-registry `--initUser`; merged auth file | — | Keep; password leaves `.env` |
| E1 | `TIME_SOURCE` | Site / security | `10.50.11.12` (site NTP) or `orphan` | Bastion chrony; agent-config `additionalNTPSources`; NTP VM | Explicit; `orphan` marks the run lab-only | New |
| E2 | `DNS_VM_IPS` | Network | `10.10.10.145,10.10.10.146` *(placeholders)* | cloud-init network-config; NNCP `dns-resolver` | Two unused IPs | Renamed; now two VMs |
| E3 | `NTP_VM_IP` | Network | `10.10.10.147` *(placeholder)* | cloud-init; chrony MachineConfig | Unused | Keep |
| E4 | `VM_NETWORK_MODEL` | OpenShift lead | `localnet` | NNCP + NetworkAttachmentDefinition | `localnet` or `linux-bridge` (ADR-06) | New |
| E5 | `STORAGE_BACKEND` | OpenShift lead | `hpp` | Storage script; DataVolume `storageClassName`; ImageSet operators | `hpp` (interim, node-local), `ontap` (Lenovo DM/DG array) or `lvms` (DS-array LUN per node) — ADR-05 | New |
| F1 | `PULL_SECRET_FILE` | OpenShift lead | `/opt/ocp-mirror/pull-secret.json` | oc-mirror auth; merged `pullSecret` | Valid JSON with `auths`; outside repo | Keep |
| F2 | `SSH_PUBLIC_KEY_FILE` | OpenShift lead | `~/.ssh/id_ed25519.pub` | install-config `sshKey`; kickstart `sshkey`; cloud-init | File exists | New; replaces hard-coded `~/.ssh/id_rsa.pub` |
| F3 | `MIRROR_DIR` | Infrastructure | `/opt/ocp-mirror` | Clients, archives, auth, CA | Owned by the installer user; free space ≥ 2× archive size | Keep |
| F4 | `INSTALL_DIR` | OpenShift lead | `~/ocp-install/ocpv-poc` | `openshift-install --dir` | Outside the git working tree | New |
| G1 | `ONTAP_MGMT_IP` | Storage | `10.10.10.160` *(placeholder)* | Trident backend `managementLIF` | IPv4 SVM management LIF, reachable from every node; enforced only when E5 = `ontap` | New |
| G2 | `ONTAP_DATA_IP` | Storage | `10.10.10.161` *(placeholder)* | Trident backend `dataLIF` (NFS) | IPv4 NFS data LIF, reachable from every node (machine network or routed storage VLAN) | New |
| G3 | `ONTAP_SVM` | Storage | `svm_ocpv` | Trident backend `svm` | Existing SVM with NFS enabled | New |
| G4 | `ONTAP_USER` | Storage | `vsadmin` | Trident credentials Secret | SVM account with the `vsadmin` role; password prompted, never in `.env` | New |

**Removed from `.env.example`:** `NETWORK_INTERFACE`, `NETWORK_NETMASK` (derived from B1),
`MWn_MAC`, all `WK01_*`/`WK02_*`, `DNS_SERVER`, `NTP_SERVER`, `MIRROR_REGISTRY_PASSWORD`.
`ENV_SCHEMA_VERSION=2` is the first line, so scripts refuse a v1 file. A **derived** block at the
end (`MIRROR_REGISTRY`, `MIRROR_ARCHIVE_DIR`, `IMAGESET_CONFIG`, `AUTH_FILE`, `REGISTRY_CA_FILE`,
`CLUSTER_RESOURCES_DIR`) is checked against its formula and must not be edited.

Where each value comes from: [field-by-field guide](detail/configure-site-env.md). Group G applies only
when `STORAGE_BACKEND=ontap`; leave its sample values while the array is not yet specified.

## Steps

### 3.1 Create `.env`

**WHERE** — Staging host (low side), RHEL 9.x, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Every script reads site facts from `.env` and nowhere else; there is no fallback to
sample values. *If skipped:* every script exits with "`.env` not found".

**EDIT** — None.

**DO / VERIFY**

```bash
cp .env.example .env && head -n1 .env      # expect: ENV_SCHEMA_VERSION=2
```

**FAILS IF** — First line differs ← an old v1 `.env`; start again from `.env.example`.

### 3.2 Fill groups A–G

**WHERE** — Staging host, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `.env.example` already holds the POC sheet values. Values the sheet does not give are
placeholders marked `>>> UPDATE` (`grep -n UPDATE .env`); the install-only samples (all-zero MACs,
`…` disk paths, `4.22.z`) are rejected, so nothing reaches an ISO until a person decides it.
*Consumed by:* `scripts/lib/render.py` (column **Lands in**).

**EDIT** — `.env` → every key, top to bottom (`vim .env`). Node identity follows this pattern
(repeat for `MW02_NICS`, `MW03_NICS`):

```text
EDIT:     .env → MW01_NICS
          from: MW01_NICS="ens1f0=00:00:00:00:00:00,ens1f1=00:00:00:00:00:00,..."
          to:   MW01_NICS="<ifname>=<MAC>,..."   (the 4 bond members, from the XCC inventory)
WHY:      The Agent ISO matches each server by these MACs, then applies its bond, IP and role.
          If wrong: the server boots the ISO, matches no host, and the install waits forever (Lab 10).
VERIFY:   in Lab 08 — grep -c macAddress agent-config.yaml → 12; grep -c 00:50:56 → 0
```

C3 and C4 are confirmed on the hardware in Lab 05 step 5.4. Group G can keep its placeholders until
the array is specified; set `STORAGE_BACKEND=ontap` only when it is.

**Changed a value after it was used?** Edit `.env`, then re-run what consumed it:

| Changed | Re-run |
|---|---|
| Any name or IP served by DNS, `TIME_SOURCE` | `sudo ./scripts/02-bootstrap-dns-ntp.sh` (Lab 07) |
| `BASTION_IP` itself | the bastion NIC (`nmcli con mod … ipv4.addresses`), then script 02 |
| Groups A–C, VIPs, registry (before install) | Lab 08 (re-render and rebuild the ISO) |
| `CLUSTER_NAME`, `BASE_DOMAIN`, VIPs, node IPs (after install) | reinstall: they are baked into certificates and Ignition |

**DO** — `vim .env`

**VERIFY** — Step 3.3.

**FAILS IF** — A group is left "for later" ← the Lab 08 ISO carries the sample.

### 3.3 Prove the register

**WHERE** — Staging host, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — A bad value otherwise surfaces 60–90 minutes into an install as a stalled bootstrap; the
validator moves that failure to second zero, like a pre-flight checklist catching a missing fuel
cap on the ground. Every script runs the same check first.

**EDIT** — Fix each `[FAIL]` key in `.env`, then re-run.

**DO / VERIFY**

```bash
./scripts/lib/validate-env.sh --scope services    # bastion DNS/NTP only (day 1): expect PASS for scope 'services'
./scripts/lib/validate-env.sh                     # everything (before Lab 06): expect validate-env: PASS
./scripts/00-prerequisites-check.sh --staging     # expect: Results: N passed, 0 failed
```

`--scope services` checks only what Lab 07 uses (names, VIPs, node/bastion/registry/VM IPs,
`TIME_SOURCE`) and lists the keys it deferred.

**FAILS IF** — `[FAIL] C3 MW01_NICS: still holds the sample MAC` ← C3 not filled.
`[WARN] E1 TIME_SOURCE: orphan` is a warning: it labels the run lab-grade.

### 3.4 Sign off

**WHERE** — Printed checklist or ticket

**WHY** — Hardware, network, DNS and storage owners each hold facts you cannot verify alone (MLAG
pairing, routed ranges, domain ownership, SVM and LIFs). Disagreement found after cabling costs an ISO rebuild.

**EDIT** — None.

**DO** — Record per node the port-channel / vPC ID (four members, two per switch) and the BMC
network; collect one signature per owner in the **Owner** column.

**VERIFY** — Every owner signed; `validate-env.sh` still passes on the signed `.env`.

**FAILS IF** — A signed value differs from `.env` ← correct `.env`, re-run 3.3.

## Next

→ [04 — Setting up the Bastion](04-bastion.md)
