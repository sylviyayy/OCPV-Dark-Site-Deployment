# MVP Network Services

> **Non-normative reference (ADR-01).** Background kept from v1. The normative procedure is
> [Lab 07](../labs/07-mvp-dns-ntp.md); where this page and a lab disagree, the lab wins.

DNS and NTP on the **bastion**, started before the cluster exists and kept running after it.

## Why the bastion serves DNS and NTP

| Service | Required by | Without it |
|---|---|---|
| DNS | the Agent ISO (registry name), every node (`api`, `api-int`, `*.apps`) | discovery stalls at the first image pull |
| NTP | etcd membership, TLS validation | members disagree on time; etcd and certificates fail |

## Architecture

```text
┌──────────────────────────────────────────────┐
│ Bastion (BASTION_IP)                         │
│  dnsmasq :53 on 127.0.0.1 and BASTION_IP     │
│    host-record = A + PTR per host            │
│    address=/apps.<cluster>.<domain>/ = *.apps│
│  chronyd :123                                │
│    server TIME_SOURCE (or orphan, lab-grade) │
│  httpd :80   RHEL 9 DVD repo for the VMs     │
└──────────────────────────────────────────────┘
          │ DNS              │ NTP
   all nodes and VMs (primary until Lab 14, secondary afterwards)
```

## Lifecycle

| Phase | DNS source | NTP source | Bastion |
|---|---|---|---|
| Install | bastion | `TIME_SOURCE` or bastion | primary |
| After Lab 14 | `dns-a`, `dns-b`, then bastion | NTP VM, then `TIME_SOURCE`/bastion | **secondary, permanently** |
| Cold start | bastion | bastion / `TIME_SOURCE` | the only service up until the VMs start |

The bastion is never decommissioned: a cluster whose only resolver lives inside it cannot start
after a site-wide power loss (ADR-07).

Detail: [MVP DNS and NTP (detail)](../labs/detail/mvp-dns-ntp.md).
