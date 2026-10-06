# Labs index

The tutorial entry point is the repository [README](../../README.md). These labs are the
**normative** path (ADR-01): where any other page disagrees, the lab wins.

Every step follows one contract:

```text
WHERE:    machine role (.env hostname), OS, user, working directory
WHY:      outcome because mechanism. Consumed by: … If skipped: symptom at lab/phase.
EDIT:     file → key, from: old value, to: new value (or "No edits in this step.")
DO:       copy-pasteable commands; the only variables are ${ENV_KEYS}
VERIFY:   command → expect: literal value
FAILS IF: symptom ← cause
```

Complete the labs **in order**:

1. [Prerequisites and Assumptions](01-prerequisites-assumptions.md)
2. [Architecture Overview and Network Design](02-architecture-network-design.md)
3. [Site Checklist](03-checklist.md)
4. [Setting up the Bastion](04-bastion.md)
5. [Provisioning Compute Resources](05-compute-resources.md)
6. [Mirroring Images for a Disconnected Install](06-mirroring-images.md)
7. [Bootstrapping MVP DNS and NTP](07-mvp-dns-ntp.md)
8. [Generating Install and Agent Configuration](08-install-agent-config.md)
9. [Certificates, Encryption, and etcd](09-certificates-etcd.md)
10. [Bootstrapping the Cluster with the Agent-based Installer](10-bootstrap-cluster.md)
11. [Configuring `oc` for Remote Access](11-oc-remote-access.md)
12. [Integrating the Mirror Registry and OperatorHub](12-mirror-operatorhub.md)
13. [Installing OpenShift Virtualization](13-openshift-virtualization.md)
14. [Production DNS and NTP on OCP-V](14-production-dns-ntp.md)
15. [Smoke Test](15-smoke-test.md)
16. [Cleaning Up](16-cleanup.md)

Appendices: [A — Adding workers later](appendix-a-adding-workers.md) ·
[B — Network boot](appendix-b-network-boot.md)

Detail pages: [field-by-field `.env` guide](detail/configure-site-env.md) ·
[bastion and registry media](detail/bastion-and-registry-usb.md) ·
[staging mirror](detail/staging-mirror.md) · [MVP DNS and NTP](detail/mvp-dns-ntp.md)
