# Appendix — Optional KVM Practice Lab

## When to use

- Partner engineer training **before** customer hardware arrives
- Validating `oc mirror` v2 and agent ISO workflow in isolation

## When not to use

- Customer greenfield delivery
- Production or production-shaped CoE on Lenovo rack
- OCP-V performance testing (use bare-metal workers)

---

## Reference implementation

Excellent step-by-step lab using RHEL KVM:

**[eanylin/openshift-lab — disconnected install on KVM host](https://github.com/eanylin/openshift-lab/tree/main/agent-based-install/disconnected-install-on-kvm-host)**

### What to reuse from that repo

| Asset | Use in Track B |
|---|---|
| `imageset-config-4.22.yaml` | Operator mirror list (see our `mirror/imageset-ocpv-coe.yaml`) |
| Bastion BIND/chrony steps | Same logic on **physical** bastion in Track A |
| `mirror-registry install` | Same on physical registry host |
| `oc mirror --v2` workspace flow | Same commands |
| Sample `agent-config` / `install-config` | Adapt MACs/IPs from worksheet |

### What not to reuse

| Asset | Why |
|---|---|
| KVM VM cluster nodes | Track A uses bare metal + BMC |
| libvirt networks | Track A uses physical switches |
| `/etc/hosts` on KVM host | Track A uses bastion DNS + proper zones |

---

## After KVM lab

1. Document lessons learned in worksheet format  
2. Repeat full flow on **Track A** hardware  
3. Do not present KVM architecture to customer as final design  

---

## Related

- [DEPLOYMENT-TRACKS.md](../DEPLOYMENT-TRACKS.md)
- [aba](https://github.com/sjbylo/aba) — optional automation wrapper (community, not Red Hat product)
