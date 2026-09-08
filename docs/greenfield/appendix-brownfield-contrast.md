# Appendix — Does this repo apply to my customer?

Use this page when a stakeholder asks about brownfield or VMware.

**Greenfield here means the cluster, not the customer.** A customer exiting
VMware is normally still building a greenfield cluster: new bare metal, new
install, nothing inherited. This repo applies to them. What it does not cover
is the source side and any pre-existing services around it.

## Qualify with one question: what does their DNS actually serve?

| Their DNS today | Where it goes | This repo |
|---|---|---|
| Serves only the vSphere estate | Rebuild: temp DNS on bastion during install → DNS VM on OCP-V after | **Yes** — full path |
| AD-integrated or Infoblox, serves the wider enterprise | Stays. Add cluster records or delegate a subzone to it | No — see [scope](00-assumptions-and-scope.md#out-of-scope) |
| Standalone VM, nothing else depends on it | Migrate the VM with MTV | No — see [scope](00-assumptions-and-scope.md#out-of-scope) |

Row 1 is what this repo assumes. Confirm the row before using
[05-bootstrap-services.md](05-bootstrap-services.md).

Note the harder filter is **disconnected**, not greenfield. If the site has
outbound access, most of the mirroring and bootstrap work here is unnecessary
regardless of which row above applies.

## Also not covered

- VMware workload migration — **MTV is not in `imageset-ocpv-coe.yaml`**; add it
  before mirroring if the customer needs it
- Existing F5/NetScaler fronting OpenShift
- In-place cluster adoption on foreign infrastructure
- Reuse of existing VLANs, IP plans, or storage arrays

For those, start from the [OpenShift 4.22 disconnected install docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index)
and adapt the network and storage chapters.

→ Back to [GREENFIELD-README.md](../GREENFIELD-README.md)
