# 14 — Production DNS and NTP on OCP-V

> **Grade:** production-shaped service design (two anti-affine DNS VMs, one NTP VM, permanent
> bastion fallback) on lab-grade storage (node-local disks: a VM is down while its node reboots).

## Goal

Run the site's steady-state DNS and NTP as VMs on OpenShift Virtualization, cut the nodes over
to them, and **keep the bastion serving** as the secondary.

## Why the bastion stays on

A cluster whose only resolver lives inside it has locked the spare key inside the car: after a
site-wide power loss, nodes need `registry.<domain>` and time before the VMs that serve them can
start. The bastion is the key in your pocket (ADR-07). Disabling `chronyd` there would also stop
the bastion disciplining its own clock.

## Steps

### 14.1 Deploy the two DNS VMs

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 07 maps an OVN-K **localnet** network (`vmnet`) onto `br-ex` with an NMState
policy, so VMs reach the machine network over the existing LACP bond (FR-H5); the old manifest named
a Linux bridge nothing built, so VMs booted on an island and nothing reported an error. It renders
two VMs from one template (FR-H4) with cloud-init in **Secrets** (FR-H1), a static address in a
network-config Secret (FR-H2), BIND from the bastion's DVD repo (FR-H3), forward and reverse zones
with `recursion no` (FR-H13), no passwords (FR-H10), a digest-pinned guest image pulled with the
registry CA and credentials (FR-H7), and required anti-affinity so one node loss leaves one resolver (FR-H8).
Consumed by: 14.2 and every node's resolver. If skipped: the cut-over in 14.2 refuses to run.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/07-deploy-dns-vm.sh
```

**VERIFY** (AT-10, run from the bastion)

```bash
set -a && source .env && set +a
for ip in "${DNS_VM_IPS%%,*}" "${DNS_VM_IPS##*,}"; do
  test "$(dig +short @"${ip}" "api.${CLUSTER_NAME}.${BASE_DOMAIN}")" = "${API_VIP}" && echo "PASS ${ip} A" || echo "FAIL ${ip} A"
  test "$(dig +short @"${ip}" -x "${CP01_IP}")" = "${CP01_HOSTNAME}.${BASE_DOMAIN}." && echo "PASS ${ip} PTR" || echo "FAIL ${ip} PTR"
done
oc get vmi -n infrastructure -o custom-columns=NAME:.metadata.name,NODE:.status.nodeName   # expect: dns-a and dns-b on different nodes
```

**FAILS IF** — The VMI is Ready but no answer ← cloud-init failed: `virtctl console dns-a -n infrastructure`,
then `sudo cloud-init status --long`; a common cause is the DVD repo (Lab 06 step 6.5).

### 14.2 Deploy the NTP VM and cut the nodes over

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 08 starts the NTP VM (time from `TIME_SOURCE`, or the bastion's orphan clock),
checks it with the `chronyd -Q` probe, then — only once both DNS VMs answer (FR-H9) — sets every
node's resolvers through an NMState `dns-resolver` policy: `dns-a`, `dns-b`, then the bastion. On the
baremetal platform NetworkManager and the node-local CoreDNS own `resolv.conf`, so overwriting the
file with a MachineConfig is the wrong mechanism (the old one also encoded line breaks as `%0E`,
FR-H6). Finally a MachineConfig sets node chrony to the NTP VM, then `TIME_SOURCE`. Nodes drain and
reboot one at a time; with `evictionStrategy: None` the VM on a rebooting node simply stops until
its node returns, because a node-local disk cannot live-migrate (FR-H9).
Consumed by: every node. If skipped: nodes keep using only the bastion, which still works.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/08-deploy-ntp-vm.sh
```

**VERIFY**

```bash
chronyd -Q "server ${NTP_VM_IP} iburst"                                          # expect: offset |x| < 1 s
oc get nncp -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[?(@.type=="Available")].status}{"\n"}{end}'
# expect: dns-cutover True, vmnet-bridge-mapping True
oc get mcp master -o jsonpath='{.status.conditions[?(@.type=="Updated")].status}{"\n"}'          # expect: True
oc debug "node/${CP01_HOSTNAME}" --quiet -- chroot /host cat /var/run/NetworkManager/resolv.conf
# expect: nameserver lines for both DNS VMs, then BASTION_IP (verify path on 4.22)
```

**FAILS IF** — `mcp/master` stays `Updating` ← a node cannot drain; check `oc get pods -A -o wide`
on that node for a pod with a PodDisruptionBudget of zero.

### 14.3 Keep the bastion services running

**WHERE** — Bastion, RHEL 9.x, as `installer`

**WHY** — The bastion is now the **secondary** resolver and time source and the only one available
during a cold start (FR-H12). Consumed by: the cold-start drill in Lab 15. If skipped (services
stopped): a site-wide power loss leaves nodes waiting for DNS VMs that need DNS to start.

**EDIT** — No edits in this step. Do **not** run `systemctl disable dnsmasq chronyd`.

**DO**

```bash
systemctl is-enabled dnsmasq chronyd
```

**VERIFY** — Output: `enabled` twice; `systemctl is-active dnsmasq chronyd` → `active` twice.

**FAILS IF** — `disabled` ← re-enable: `sudo systemctl enable --now dnsmasq chronyd`.

## Next

→ [15 — Smoke Test](15-smoke-test.md)
