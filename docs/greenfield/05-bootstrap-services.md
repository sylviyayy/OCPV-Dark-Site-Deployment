# Bootstrap Services (DNS and NTP)

## The greenfield DNS problem

**Brownfield:** DNS often lives on VMware.  
**Greenfield:** Nothing exists until you build it.

This repo uses a **two-stage** approach:

| Stage | WHERE | WHAT | WHEN |
|---|---|---|---|
| **MVP** | Bastion `10.10.0.5` | dnsmasq + chronyd (orphan) | Install only |
| **Production** | OCP-V VMs `.50` / `.51` | BIND + chrony | Steady state |

---

## Stage 1 — MVP on bastion

**WHERE:** Physical bastion (Track A)  
**RUN:** `sudo ./scripts/02-bootstrap-dns-ntp.sh`

**WHY:**

- Nodes must resolve `api.<cluster>.<domain>` and `registry.<domain>`
- etcd requires time sync (≤500 ms skew)

**FAILS IF:** Skipped → agent install hangs on image pull or etcd health.

Detail: [05-mvp-network-services.md](../05-mvp-network-services.md)

### Alternative: BIND on bastion

The [eanylin/openshift-lab](https://github.com/eanylin/openshift-lab/tree/main/agent-based-install/disconnected-install-on-kvm-host) guide uses full BIND on the bastion. That is valid for install. This repo defaults to **dnsmasq** for simplicity; partners may use BIND for forward/reverse zones matching production.

---

## Stage 2 — Production on OCP-V

**WHERE:** `infrastructure` namespace VMs on cluster workers  
**RUN:** `scripts/07-deploy-dns-vm.sh`, `scripts/08-deploy-ntp-vm.sh`

**WHY:** Customer-owned DNS/NTP that survives bastion decommission — **this is where VMware DNS “goes”** in a VMware-exit greenfield story.

Detail: [06-production-network-services.md](../06-production-network-services.md)

---

## Cutover

1. Deploy DNS/NTP VMs on OCP-V  
2. Apply MachineConfigs (scripts 07/08)  
3. Verify resolution/time on all nodes  
4. Stop dnsmasq/chronyd on bastion  

**FAILS IF:** Cutover before VMs healthy → cluster-wide DNS outage.

---

## Next

→ [Kickstart procedure](../03-kickstart-procedure.md)
