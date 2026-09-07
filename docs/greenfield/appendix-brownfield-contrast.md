# Appendix — Brownfield Contrast

This repository targets **greenfield** deployment. Use this page when stakeholders ask about brownfield or VMware.

---

## Common question

> “Our DNS is on VMware today. We’re exiting VMware. Where does DNS go?”

**Greenfield answer (this repo):** You design DNS from day one:

1. Temporary DNS on bastion during install  
2. Permanent DNS VM on **OpenShift Virtualization** after install  

There is no VMware VM to migrate — you **replace the function**, not the VM.

---

## Brownfield vs greenfield

| Topic | Brownfield | Greenfield (this repo) |
|---|---|---|
| DNS | Often VMware / Windows DNS | Built on OCP-V |
| VLANs | Usually exist | You define (or start flat L2) |
| IP plan | Change-controlled | New worksheet |
| Storage | Existing arrays / datastores | New LUN masking |
| Installer | May use existing LB/DHCP | Agent-based, static IPs |
| This guide | Partial overlap only | Full path |

---

## What we deliberately do not cover

- VMware workload migration (MTV is mirrored in CoE ImageSet but not documented here)
- AD DNS integration / conditional forwarders
- Existing F5/NetScaler fronting OpenShift
- In-place cluster adoption on foreign infrastructure

For brownfield disconnected installs, start from Red Hat 4.22 docs and adapt network/storage chapters where infrastructure already exists.

---

## Back to greenfield

→ [GREENFIELD-README.md](../GREENFIELD-README.md)
