# 03 — Site Checklist

> **Grade:** production-grade discipline. The values are yours; the rules that check them are
> the same for a lab and a customer site.

## Goal

Decide and sign the 31 pre-defined fields, write them to `.env`, and prove them with
`validate-env.sh` — before anyone cables a server.

## Why these fields are fixed first

The Agent ISO freezes node identity (MAC → IP → hostname → role), the VIPs and the registry
mirrors into its Ignition at build time. Change one afterwards and you rebuild the ISO and
re-boot every node; change `CLUSTER_NAME` or `BASE_DOMAIN` after install and you reinstall.
Treat this table as the **bill of materials**: a production line does not start with parts
unordered.

`.env.example` lists the same keys in the same order, and `scripts/lib/validate-env.sh`
enforces the **Rule** column before any script proceeds. You edit `.env` only; every other file
is generated from it (rule E2).

## Field register

| # | `.env` key | Owner | Example | Lands in (file → key) | Rule enforced | v2 change |
|---|---|---|---|---|---|---|
| A1 | `CLUSTER_NAME` | OpenShift lead | `coe01` | install-config → `metadata.name`; agent-config → `metadata.name` | Lowercase RFC 1123 label | Keep |
| A2 | `BASE_DOMAIN` | DNS owner | `lab.example.com` | install-config → `baseDomain` | Not `.local` (reserved for mDNS, RFC 6762); a site-owned domain or `.internal` | New default |
| A3 | `OCP_VERSION` | OpenShift lead | `4.22.z` | ImageSet `minVersion`/`maxVersion`; client download path | Exact z-stream present in `stable-4.22` at mirror time | Keep |
| A4 | `OCP_CHANNEL` | OpenShift lead | `stable-4.22` | ImageSet `channels[0].name` | Minor equals `OCP_VERSION` minor | Keep |
| B1 | `MACHINE_NETWORK_CIDR` | Network | `10.10.0.0/16` | install-config → `networking.machineNetwork[0].cidr`; chrony `allow` | Contains every node, VIP, bastion, registry and VM IP | Renamed from `NETWORK_CIDR` |
| B2 | `NETWORK_GATEWAY` | Network | `10.10.0.1` | agent-config → default route `next-hop-address` | Inside B1 | Keep |
| B3 | `CLUSTER_NETWORK_CIDR`, `SERVICE_NETWORK_CIDR` | Network | `10.128.0.0/14`, `172.30.0.0/16` | install-config → `networking.clusterNetwork`, `serviceNetwork` | No overlap with B1, any routed site range, or OVN-K internal `100.64.0.0/16` and `100.88.0.0/16` | New |
| B4 | `MTU` | Network | `1500` | agent-config → `bond0.mtu` | Equals switch MTU end to end | New |
| B5 | `API_VIP` | Network | `10.10.0.100` | install-config → `platform.baremetal.apiVIPs[0]`; DNS `api`, `api-int` | Inside B1, unused, not pingable before install | Keep |
| B6 | `INGRESS_VIP` | Network | `10.10.0.101` | install-config → `platform.baremetal.ingressVIPs[0]`; DNS `*.apps` | Same as B5; differs from B5 | Keep |
| C1 | `CP01_HOSTNAME` … `CP03_HOSTNAME` | Hardware | `cp01` | agent-config → `hosts[n].hostname`; DNS A + PTR | Short name; the README role table uses the same names | Short name, not FQDN |
| C2 | `CP01_IP` … `CP03_IP` | Network | `10.10.1.11` | agent-config → `hosts[n].networkConfig` bond0 IPv4 | Unique; inside B1 | Keep |
| C3 | `CP01_NICS` … `CP03_NICS` | Hardware | `ens1f0=aa:bb:cc:00:01:01,…` (4 pairs) | agent-config → `hosts[n].interfaces[]` and bond0 port list | Exactly the 4 bond members; no `00:50:56` (VMware OUI); names as RHCOS enumerates them | New; replaces `CPn_MAC` and global `NETWORK_INTERFACE` |
| C4 | `CP01_ROOT_DEVICE` … `CP03_ROOT_DEVICE` | Hardware | `/dev/disk/by-path/pci-0000:…` | agent-config → `hosts[n].rootDeviceHints.deviceName` | A stable path to the RAID1 virtual disk; never `/dev/sdX` | New |
| C5 | `CP01_BMC_IP` … `CP03_BMC_IP` | Hardware | `10.20.0.11` | Checklist; XCC virtual media | Reachable from admin workstation | New |
| C6 | `RENDEZVOUS_IP` | OpenShift lead | `${CP01_IP}` | agent-config → `rendezvousIP` | Equals one of C2 | Keep |
| D1 | `BASTION_HOSTNAME`, `BASTION_IP` | Infrastructure | `bastion`, `10.10.0.5` | Kickstart network; DNS | Inside B1 | Keep |
| D2 | `BASTION_IFNAME` | Infrastructure | `eno1` | Kickstart `network --device` | From `ip -br link` on the bastion | New |
| D3 | `MIRROR_REGISTRY_HOSTNAME` | Infrastructure | `registry.lab.example.com` | mirror-registry `--quayHostname`; `imageDigestSources`; DNS | FQDN; resolves via bastion DNS | Keep |
| D4 | `MIRROR_REGISTRY_PORT` | Infrastructure | `8443` | Derived `MIRROR_REGISTRY=${D3}:${D4}`; firewall rule | `8443` (tool default) unless site policy mandates `443` | New |
| D5 | `MIRROR_REGISTRY_IP` | Infrastructure | `10.10.0.10` | DNS A record only | May equal `BASTION_IP` | Keep |
| D6 | `MIRROR_REGISTRY_USER` | Infrastructure | `init` | mirror-registry `--initUser`; merged auth file | — | Keep; password leaves `.env` |
| E1 | `TIME_SOURCE` | Site / security | `10.10.0.2` or `orphan` | Bastion chrony; agent-config `additionalNTPSources`; NTP VM | Explicit; `orphan` marks the run lab-only | New |
| E2 | `DNS_VM_IPS` | Network | `10.10.0.50,10.10.0.52` | cloud-init network-config; NNCP `dns-resolver` | Two unused IPs | Renamed; now two VMs |
| E3 | `NTP_VM_IP` | Network | `10.10.0.51` | cloud-init; chrony MachineConfig | Unused | Keep |
| E4 | `VM_NETWORK_MODEL` | OpenShift lead | `localnet` | NNCP + NetworkAttachmentDefinition | `localnet` or `linux-bridge` (ADR-06) | New |
| E5 | `STORAGE_BACKEND` | OpenShift lead | `hpp` | Storage script; DataVolume `storageClassName` | `hpp` or `lvms` (ADR-05) | New |
| F1 | `PULL_SECRET_FILE` | OpenShift lead | `/opt/ocp-mirror/pull-secret.json` | oc-mirror auth; merged `pullSecret` | Valid JSON with `auths`; outside repo | Keep |
| F2 | `SSH_PUBLIC_KEY_FILE` | OpenShift lead | `~/.ssh/id_ed25519.pub` | install-config `sshKey`; kickstart `sshkey`; cloud-init | File exists | New; replaces hard-coded `~/.ssh/id_rsa.pub` |
| F3 | `MIRROR_DIR` | Infrastructure | `/opt/ocp-mirror` | Clients, archives, auth, CA | Owned by the installer user; free space ≥ 2× archive size | Keep |
| F4 | `INSTALL_DIR` | OpenShift lead | `~/ocp-install/coe01` | `openshift-install --dir` | Outside the git working tree | New |

**Removed from `.env.example`:** `NETWORK_INTERFACE`, `NETWORK_NETMASK` (derived from B1),
`CPn_MAC`, all `WK01_*`/`WK02_*`, `DNS_SERVER`, `NTP_SERVER`, `MIRROR_REGISTRY_PASSWORD`.
`ENV_SCHEMA_VERSION=2` is the first line, so scripts refuse a v1 file. A **derived** block at the
end (`MIRROR_REGISTRY`, `MIRROR_ARCHIVE_DIR`, `IMAGESET_CONFIG`, `AUTH_FILE`, `REGISTRY_CA_FILE`,
`CLUSTER_RESOURCES_DIR`) is checked against its formula and must not be edited.

How to obtain each value: [field-by-field guide](detail/configure-site-env.md).

## Steps

### 3.1 Create `.env`

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Every script reads `.env` and nothing else for site facts, so one file drives the
kickstarts, DNS records, `install-config.yaml`, `agent-config.yaml` and the VM manifests.
Consumed by: `scripts/lib/common.sh:load_env`. If skipped: every script exits 1 with
"`.env` not found" — there is no fallback to sample values.

**EDIT** — No edits in this step.

**DO**

```bash
cp .env.example .env
```

**VERIFY**

```bash
head -n1 .env      # expect: ENV_SCHEMA_VERSION=2
```

**FAILS IF** — First line differs ← you copied a v1 `.env`; start again from `.env.example`.

### 3.2 Fill groups A–F

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The sample values are deliberately rejected (all-zero MACs, `…` root devices,
`4.22.z`, a documentation domain), so nothing reaches an ISO until a person has decided it.
Consumed by: `scripts/lib/render.py` (see the **Lands in** column).
If skipped: Lab 03 step 3.3 prints one `[FAIL]` line per undecided key.

**EDIT** — `.env` → every key in groups A–F, top to bottom, with `vim .env`. The node identity
fields follow this worked example (C3; repeat for `CP02_NICS`, `CP03_NICS`):

```text
WHERE:    Staging host, RHEL 9.x, as your user, cwd ~/OCPV-Dark-Site-Deployment
WHY:      The Agent ISO matches each server by the MACs of its NICs, then applies that
          host's bond, static IP and role. Consumed by: agent-config.yaml → hosts[n].interfaces[].
          If skipped: the server boots the ISO but matches no hosts[] entry, and
          `openshift-install agent wait-for` waits for 3 hosts forever (Lab 10).
EDIT:     .env → CP01_NICS
          from: CP01_NICS="ens1f0=00:00:00:00:00:00,ens1f1=00:00:00:00:00:00,..."
          to:   CP01_NICS="<ifname>=<MAC>,..."   (4 pairs, read from the XCC hardware inventory)
DO:       ./scripts/03-generate-install-config.sh            (in Lab 08)
VERIFY:   grep -c macAddress "${INSTALL_DIR}/agent-config.yaml"   →  expect: 12
          grep -c 00:50:56 "${INSTALL_DIR}/agent-config.yaml"     →  expect: 0
FAILS IF: "waiting for hosts" never advances ← a MAC typo or a non-bond NIC listed
```

C3 and C4 come from the XCC inventory now and are **confirmed** on the hardware in Lab 05
step 5.4, which tells you to edit them if the live names differ.

**DO**

```bash
vim .env
```

**VERIFY** — the next step.

**FAILS IF** — You leave a group "for later" ← the ISO built in Lab 08 carries the sample.

### 3.3 Prove the register

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — A bad value today surfaces 60–90 minutes into an install as a stalled bootstrap;
the validator moves that failure to second zero, the way a pre-flight checklist catches a
missing fuel cap on the ground. Consumed by: every script, which runs the same check first.
If skipped: the first script you run stops with the same messages.

**EDIT** — No edits in this step (fix any `[FAIL]` key in `.env` and re-run).

**DO**

```bash
./scripts/lib/validate-env.sh
./scripts/00-prerequisites-check.sh --staging
```

**VERIFY**

```bash
./scripts/lib/validate-env.sh && echo PASS     # expect: validate-env: PASS ... then PASS
# 00 --staging expect: "Results: N passed, 0 failed"
```

**FAILS IF** — `[FAIL] C3 CP01_NICS: still holds the sample MAC` ← C3 not filled;
`[WARN] E1 TIME_SOURCE: orphan` is a warning, not a failure: it labels the run lab-grade.

### 3.4 Sign off

**WHERE** — Printed checklist or ticket, signed by each owner in the **Owner** column

**WHY** — Hardware, network and DNS owners each hold facts you cannot verify alone (MLAG pairing,
routed ranges, domain ownership). Consumed by: change control. If skipped: a disagreement
surfaces after cabling, when changing a value means rebuilding the ISO.

**EDIT** — No edits in this step.

**DO** — Record: switch port-channel and MLAG/vPC IDs per node (four members each, two per switch),
the BMC network, and a signature per owner.

**VERIFY** — Every owner in the register has signed; `validate-env.sh` still passes on the signed `.env`.

**FAILS IF** — An owner signs a different value than `.env` holds ← re-run 3.3 after correcting.

## Next

→ [04 — Setting up the Bastion](04-bastion.md)
