# 14 — Production DNS and NTP on OCP-V

> **Grade:** production-shaped service design (two anti-affine DNS VMs, one NTP VM, permanent
> bastion fallback). Availability during node maintenance follows `STORAGE_BACKEND`: with `ontap`
> the VMs live-migrate; with `hpp` or `lvms` a VM is down while its node reboots.

## Goal

Run the site's steady-state DNS and NTP as VMs, cut the nodes over to them, and **keep the bastion
serving** as the secondary.

## Why the bastion stays on

After a site-wide power loss, nodes need `registry.<domain>` and time **before** the VMs that serve
them can start. A cluster whose only resolver runs inside it has locked the spare key inside the
car; the bastion is the key in your pocket (ADR-07).

## Steps

### 14.1 Deploy the two DNS VMs

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 07, in order:

1. **Network** — an NMState policy maps the OVN-K localnet `vmnet` onto `br-ex`, so VMs reach the
   machine network over the existing LACP bond; it waits until the policy is Available on every node.
2. **Image access** — the registry CA (ConfigMap) and mirror credentials (Secret, via stdin) let the
   CDI importer pull the digest-pinned guest image over verified TLS.
3. **VMs** — renders `dns-a` and `dns-b` from one template: cloud-init in Secrets, static IP matched
   to the NIC by MAC, BIND from the bastion's DVD repo, forward and reverse zones generated from `.env`,
   `recursion no`, no passwords; **required** anti-affinity so one node loss leaves one resolver;
   `evictionStrategy` `LiveMigrate` on `ontap`, `None` otherwise (a node-local disk cannot migrate,
   and `LiveMigrate` there would block the node drain forever).
4. **Proof** — waits for each VM Ready, checks they landed on different nodes, then queries both for
   A, wildcard and PTR records and compares them with `.env`.

*Consumed by:* 14.2. *If skipped:* 14.2 refuses to cut over.

**EDIT** — None.

**DO** — `./scripts/07-deploy-dns-vm.sh`

**VERIFY** (AT-10) — Last line `PASS: dns-a (…) and dns-b (…) serve .env records`. By hand:

```bash
set -a && source .env && set +a
dig +short @"${DNS_VM_IPS%%,*}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}"     # expect: API_VIP
dig +short @"${DNS_VM_IPS##*,}" -x "${MW01_IP}"                          # expect: <MW01_HOSTNAME>.<BASE_DOMAIN>.
oc get vmi -n infrastructure -o custom-columns=NAME:.metadata.name,NODE:.status.nodeName   # expect: different nodes
```

**FAILS IF** — VM Ready but no answer ← cloud-init failed: `virtctl console dns-a -n infrastructure`,
then `sudo cloud-init status --long` (usual cause: DVD repo, Lab 06 step 6.5); DataVolume stuck
`ImportInProgress` ← guest image not mirrored or CA wrong; `both run on mwNN` ← anti-affinity not honoured.

### 14.2 Deploy the NTP VM and cut the nodes over

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 08, in order:

1. Starts the NTP VM (upstream `TIME_SOURCE`, or the bastion when orphan) and probes it with `chronyd -Q`.
2. Refuses to continue unless **both** DNS VMs answer.
3. Sets every node's resolvers through an NMState `dns-resolver` policy: `dns-a`, `dns-b`, then the
   bastion. NetworkManager owns `resolv.conf` on RHCOS, so writing the file directly is the wrong mechanism.
4. Applies MachineConfig `99-master-chrony-production`: node chrony uses the NTP VM **and**
   `TIME_SOURCE` (or the bastion) and selects the better one; the second keeps time flowing while
   the NTP VM's node reboots. Nodes drain and reboot **one at a time**; the script waits until every node runs the
   new rendered config (up to 90 min), not just until the pool says Updated.

*Consumed by:* every node. *If skipped:* nodes keep using only the bastion — which works, with no redundancy.

**EDIT** — None.

**DO** — `./scripts/08-deploy-ntp-vm.sh`

**VERIFY**

```bash
chronyd -Q "server ${NTP_VM_IP} iburst"               # expect: offset |x| < 1 s
oc get nnce | grep dns-cutover                        # expect: one line per node, Available
oc get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}{"\n"}'   # expect: True
oc debug "node/${MW01_HOSTNAME}" --quiet -- chroot /host chronyc -n sources
# expect: NTP_VM_IP and TIME_SOURCE (or BASTION_IP) both listed; one marked ^* (selected), the other ^+ or ^-
```

**FAILS IF** — `mcp/master` stuck `Updating` ← a pod blocks the drain; `oc get nodes` shows the
`SchedulingDisabled` node, `oc get pdb -A` the blocking budget. With `hpp`/`lvms`, check that no VM
carries `evictionStrategy: LiveMigrate`.

### 14.3 Keep the bastion services running

**WHERE** — Bastion, `installer`

**WHY** — The bastion is now the secondary resolver and time source, and the only one during a
cold start. Do **not** `systemctl disable dnsmasq chronyd`.

**EDIT** — None.

**DO / VERIFY** — `systemctl is-enabled dnsmasq chronyd; systemctl is-active dnsmasq chronyd` → `enabled` ×2, `active` ×2.

**FAILS IF** — `disabled` ← `sudo systemctl enable --now dnsmasq chronyd`.

## Next

→ [15 — Smoke Test](15-smoke-test.md)
