# Post-Install Validation

> **Non-normative reference (ADR-01).** Background kept from v1. The normative procedure is
> [Lab 15 — Smoke Test](../labs/15-smoke-test.md); where this page and a lab disagree, the lab wins.

Run `./scripts/00-prerequisites-check.sh --post-install`. Every check compares a value, so a
broken cluster cannot pass; the script exits 1 and names each failed check.

## What it asserts

| Area | Assertion |
|---|---|
| Nodes | API answers; every node `Ready` (three on the compact rack) |
| ClusterOperators | every operator `Available=True` and `Degraded=False` |
| Catalogs | only the mirrored CatalogSource exists |
| DNS | both DNS VMs answer `api` → `API_VIP`, `registry` → `MIRROR_REGISTRY_IP`, PTR for `mw01` |
| Time | NTP VM and bastion both serve time with offset < 1 s (`chronyd -Q` probe) |
| Registry | `https://<MIRROR_REGISTRY>/v2/` answers 200/401 with TLS verified |
| Virtualization | `HyperConverged` Available |
| Storage | default StorageClass is the one `STORAGE_BACKEND` selects |
| Network | NNCPs `vmnet-bridge-mapping` and `dns-cutover` Available; `mcp/master` Updated |

## Connectivity matrix

| From | To | Port | Expected |
|---|---|---|---|
| Any node | DNS VMs, bastion | 53/TCP+UDP | DNS answers |
| Any node | NTP VM, `TIME_SOURCE`/bastion | 123/UDP | NTP sync |
| Any node | registry | 8443/TCP | Registry API with a trusted certificate |
| Bastion | API VIP | 6443/TCP | Kubernetes API |
| Admin network | Ingress VIP | 443/TCP | Console and routes |

## Sign-off checklist

- [ ] `00-prerequisites-check.sh --post-install` → `0 failed`
- [ ] `git status --ignored` in the repo shows only `.env`
- [ ] Cold-start drill passed (bastion first, then nodes; healthy within 30 minutes)
- [ ] Bastion `dnsmasq` and `chronyd` enabled and active (secondary)
- [ ] Grade recorded honestly: lab-grade if `TIME_SOURCE=orphan` or `STORAGE_BACKEND=hpp`
