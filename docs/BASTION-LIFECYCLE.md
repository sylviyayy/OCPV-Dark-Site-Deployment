# Bastion Lifecycle: USB → Temporary DNS/NTP → Install → Permanent DNS/NTP → (Optional) Retirement

The operating model, phase by phase, mapped to the lab steps that carry it out, with the two
24-hour windows marked **[WINDOW A]** and **[WINDOW B]**. The commands live in the labs (they are
normative, ADR-01); this page tells you which one runs when, and why the order matters.

What to carry: [USB Transfer Kit](USB-TRANSFER-KIT.md).

---

## 1. Roles over time

The bastion is **scaffolding**: it goes up before the building, carries load while the building
cannot carry itself, then either stays as a fire escape (the default) or comes down.

| Phase | What happens | Labs | Bastion's role | Nodes' DNS / NTP | Clock |
|---|---|---|---|---|---|
| 0 | Connected staging, media | 01, 03, 04.1–4.2, 06.1–6.3 | not on site | — | — |
| 1 | Arrival: install helper hosts, intake media | 04.3–4.5, 06.4–6.5 | being installed | — | — |
| 2 | Temporary services | **07** | **sole** DNS/NTP | — | — |
| 3 | Mirror registry, load archive | 06.6–6.8 | pushes images | — | — |
| 4 | Compose and validate | 08.1, 07.2 | workstation | — | — |
| 5 | **T-0**: ISO, boot, install | 08.2, 10 | installer, sole DNS/NTP | bastion | **[A]** |
| 6 | Soak; build platform and VMs | 11–13, 14.1 | sole DNS/NTP | bastion | **[B]** |
| 7 | Make-before-break cut-over | 14.2–14.3, 15 | **secondary** DNS/NTP | DNS VMs, then bastion | — |
| 8 | Optional retirement | section 4 | removed | DNS VMs | — |

**Default (ADR-07): stop after Phase 7.** The bastion stays as the secondary resolver and time
source, and is the only one available during a cold start: after a site-wide power loss the nodes
need `registry.<domain>` and time **before** the DNS/NTP VMs that run on them can start.

---

## 2. The two 24-hour windows

### Not on a clock

Everything on the drive: clients, pull secret, mirror archive, RHEL DVD. Prepare days ahead.

### Window A: the Agent ISO's shelf life

| | |
|---|---|
| **Starts** | T-0: `openshift-install agent create image` (script 05a, Lab 08 step 8.2) |
| **Hard limit** | 24 hours: the Ignition embedded in the ISO carries certificates that expire |
| **Recommendation** | Boot all nodes within **12 hours**, so the first rotation (16–22 h after install) does not overlap the install |
| **Consequence** | Build the ISO **on site**, last, when you can boot immediately. Never start T-0 at the end of a shift |
| **If it lapses** | Lab 08 step 8.2 shows how to regenerate the ISO **and** `auth/` together. Never mix artifacts from two runs |

Analogy: a `kubeadm join` bootstrap token, also 24 hours: a credential meant for immediate use.

### Window B: the first certificate rotation

| | |
|---|---|
| **Starts** | When the nodes first boot the ISO |
| **Rule** | For 24 hours keep the cluster powered on and the bastion's DNS/NTP unchanged. Building the VMs (14.1) is fine; **switching** to them (14.2) is not |
| **If the cluster was powered off inside it** | Approve pending kubelet CSRs when it returns: `oc get csr -o name \| xargs oc adm certificate approve` |

---

## 3. Phase notes (what the labs do, and the trap each avoids)

**Phase 1.** Boot `bastion-ks.iso` (Lab 04): kickstart from the DVD, repo and `.env` already in
`/home/installer`. Verify the media with `sha256sum -c` **before** copying anything (Lab 06 step 6.4).

**Phase 2.** Set the bastion clock to UTC first (Lab 07 step 7.0): with `orphan`, or until
`TIME_SOURCE` answers, this clock *is* the site's time, and every certificate minted later carries
it. Then `sudo ./scripts/02-bootstrap-dns-ntp.sh`. It runs with only names and addresses known
(`--scope services`), so this phase can happen on day 1, before any node MAC is known.

**Phase 3.** The registry certificate is minted at install time, so the registry host's clock must
already agree with the site's: its kickstart points chrony at `TIME_SOURCE`, or at the bastion when
`orphan`. Check `chronyc tracking` on it before step 6.6.

**Phase 4 — go/no-go gate.** Do not start T-0 until all are true:

- [ ] `./scripts/00-prerequisites-check.sh --bastion` → `0 failed` (DNS, time, clients, registry over TLS)
- [ ] `./scripts/lib/validate-env.sh --probe` → `PASS` (VIPs not yet in use)
- [ ] XCC virtual media tested on **every** node; node BMC clocks within a minute of the bastion (UTC)
- [ ] At least 12 uninterrupted hours on site ahead of you

**Phase 5.** Script 05a keeps `install-config.yaml` and `agent-config.yaml` as `*.orig` (the
installer deletes its inputs), so a lapsed Window A costs minutes, not a re-render.

**Phase 6.** Lab 12 applies the mirror resources; Lab 13 installs Virtualization, NMState, the
storage operator and the POC operators (06c); Lab 14 step 14.1 deploys the DNS VMs. All fine inside
Window B: none of it changes what the nodes resolve or sync with.

**Phase 7 — make-before-break** (after Window B). Script 08 refuses to cut over until both DNS
VMs answer, then:

1. Node resolvers, through NMState: `dns-a`, `dns-b`, then the **bastion**.
2. Node chrony, through a MachineConfig: the NTP VM **and** `TIME_SOURCE` (or the bastion when
   orphan); chrony selects the better. Nodes drain and reboot one at a time.

During each drain a DNS/NTP VM on that node stops or migrates; the bastion is what keeps names
resolving and time flowing — the reason it must still be there. Analogy: adding the new backend to
a load-balancer pool before draining the old one. Then run Lab 15 (post-install checks and the
cold-start drill).

---

## 4. Phase 8 (optional): retiring the bastion

Retire it only if site policy requires; ADR-07 recommends keeping it. Preconditions — all must hold:

| Precondition | Why |
|---|---|
| `MIRROR_REGISTRY_IP` ≠ `BASTION_IP` | The cluster pulls every image from the registry for its whole life |
| `TIME_SOURCE` is a real NTP server, not `orphan` | With `orphan` the bastion **is** the site clock: node chrony and the NTP VM both follow it |
| A secondary DNS outside the cluster exists (e.g. on the registry host) | Otherwise a cold start has no resolver until the DNS VMs boot (risk R2) |
| The DVD repo is served from a permanent host | Re-provisioning a DNS/NTP VM installs `bind`/`chrony` from it |
| Lab 15 passes, and at least 24 h of soak after Phase 7 | Proves the permanent servers carry the load |

Steps:

1. Remove the bastion from the node resolvers (it is the third entry):

   ```bash
   oc patch nncp dns-cutover --type json \
     -p '[{"op":"remove","path":"/spec/desiredState/dns-resolver/config/server/2"}]'
   oc wait nncp/dns-cutover --for=condition=Available --timeout=300s
   ```

2. Remove it from everything outside the cluster: registry host, workstations, XCC DNS/NTP settings.
3. **Prove the drain** before unplugging. For an hour, nothing should still ask it:

   ```bash
   sudo tcpdump -ni any 'udp port 53 or udp port 123' -c 50     # expect: no packets from node or registry IPs
   sudo chronyc clients                                         # expect: "Last" keeps growing for every client
   ```

4. Move what exists only on the bastion (section 5), then `sudo systemctl disable --now dnsmasq chronyd`
   and power it off.
5. Verify without it: `./scripts/00-prerequisites-check.sh --post-install` from another admin host
   (its bastion checks are expected to fail; everything else must pass).

## 5. What lives only on the bastion

| Item | Path | Move to |
|---|---|---|
| Admin kubeconfig, `kubeadmin` password | `${INSTALL_DIR}/auth/` | sealed offline storage / vault |
| As-built install inputs | `${INSTALL_DIR}/*.orig` | secure storage (they contain the pull secret) |
| oc-mirror workspace and ImageSet | `${MIRROR_ARCHIVE_DIR}/working-dir/`, `${IMAGESET_CONFIG}` | registry host (needed for incremental mirroring) |
| Clients | `${MIRROR_DIR}/clients/` | registry host (Day-2 admin host) |
| Registry CA and credentials | `${REGISTRY_CA_FILE}`, `${AUTH_FILE}` | registry host / vault |
| `.env`, rendered configs | repo, `/etc/dnsmasq.d/ocp-v.conf` | secure storage (zone-parity reference) |

## 6. Risk register

| # | Risk | Mitigation |
|---|---|---|
| R1 | Registry co-located on the bastion | Then never retire the bastion |
| R2 | The cluster hosts its own DNS/NTP (circular dependency on a cold start) | Keep the bastion (default) or another resolver outside the cluster; `platform: baremetal` CoreDNS still resolves `api`, `api-int`, `*.apps` on the nodes |
| R3 | Free-running site clock (`orphan`) | Lab-grade; point `TIME_SOURCE` at a reference clock (the POC sheet's `10.50.11.12`) |
| R4 | Media failure | Two independently verified copies |
| R5 | Window A lapses | `*.orig` inputs and the regeneration in Lab 08 step 8.2 |
| R6 | Cluster powered off inside Window B | Approve pending CSRs (section 2) |
| R7 | Day-2 content after the bastion is gone | Registry host inherits clients and the oc-mirror workspace (section 5) |

## 7. Defects PR #1 recorded on this path, and where they stand

PR #1 audited the previous scripts. This branch rewrote them; status against the current code:

| # | Defect (previous code) | Now |
|---|---|---|
| D1, D3 | Wrong client file names; wrong oc-mirror v2 forms | Fixed: script 01 picks files by pattern from `sha256sum.txt`; `file://` and `--from file:// docker://` (Lab 06) |
| D2 | oc-mirror pinned to `OCP_VERSION`; Red Hat recommends the latest | **Open**, low risk: script 01 still takes oc-mirror from the `OCP_VERSION` directory |
| D4 | `openshift-clients` in the bastion kickstart | Fixed: kickstart template lists only DVD packages; `ksvalidator` runs in CI |
| D5, D6, D7 | Port 443/5000, a Docker Hub registry image as fallback, wrong CA file | Fixed: 8443, no fallback, `quay-rootCA/rootCA.pem` (ADR-03) |
| D8, D9, D10, D11 | No `imageDigestSources`, no mirror credentials, `envsubst` no-op, no `additionalNTPSources` | Fixed: `render.py` builds both install files from `.env` and oc-mirror output (Lab 08) |
| D12, D16 | No NMState operator, no storage operator | Fixed: `default` profile and `STORAGE_BACKEND` (Lab 13) |
| D13, D14, D15 | Bridge nothing creates; invalid cloud-init source; no repo for `bind` | Fixed: localnet on `br-ex` (ADR-06), `cloudInitNoCloud` Secrets, DVD repo via script 04b |
| D17, D18 | Break-before-make cut-over; `%0E` resolv.conf MachineConfig | Fixed: script 08 orders DNS VMs then bastion through NMState, after both VMs answer |
| D19 | Post-install checks filtered `check`'s output, not the command | Fixed: each check is a function that compares a value (Lab 15) |

Sources: OpenShift 4.22 installation overview (Ignition certificates: 24 h, boot within 12 h,
CSR recovery); Agent-based Installer parameters (`additionalNTPSources`); Red Hat solutions
7005191 (ABI and `oc` in disconnected installs) and 7020319 (`nmstatectl`).
