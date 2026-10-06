# Offline Installer Guide (OpenShift 4.22 — Agent-Based, Disconnected)

> **Non-normative reference (ADR-01).** Background kept from v1. The normative procedure is
> Labs [08](../labs/08-install-agent-config.md), [10](../labs/10-bootstrap-cluster.md) and
> [12](../labs/12-mirror-operatorhub.md); where this page and a lab disagree, the lab wins.

## Official documentation

| Topic | Link |
|---|---|
| Disconnected environments overview | [OCP 4.22 Disconnected environments](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index) |
| oc-mirror plugin v2 | [About oc-mirror v2](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2) |
| Agent-based disconnected mirroring | [Understanding disconnected mirroring (ABI)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/understanding-disconnected-installation-mirroring) |
| Agent-based installation | [Installing with the Agent-based Installer](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/index) |
| OpenShift Virtualization | [Installing virtualization](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/installing) |

## Why the Agent-based Installer for dark sites

- No external load balancer, bootstrap VM or DHCP (static nmstate per host).
- The Assisted Service runs inside the Agent ISO; one node (`rendezvousIP`) hosts the temporary control plane.
- Supports bare metal with `platform: baremetal` and API/Ingress VIPs.

## The three facts the Agent ISO needs from the mirror

| `install-config.yaml` key | Content | Failure without it |
|---|---|---|
| `imageDigestSources` | copied from oc-mirror's `idms-oc-mirror.yaml` | every node pulls from `quay.io` and stalls |
| `pullSecret` | the merged auth file: Red Hat pull secret **plus** the mirror registry entry | pulls from the mirror return 401 |
| `additionalTrustBundle` | mirror-registry's root CA, every PEM line indented | TLS errors; or YAML that does not parse |

All three are rendered by `scripts/03-generate-install-config.sh` into `${INSTALL_DIR}`, outside the
repository, because `openshift-install` writes the kubeconfig and its state file (with the pull
secret) beside its inputs.

## Install duration

Typically 60–90 minutes for the three-node compact cluster, from the first ISO boot to
`install-complete`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| ISO boots, node never discovered | a MAC in `CPn_NICS` is wrong or not a bond member | fix C3; re-run Lab 08 |
| Waiting for five hosts on a three-server rack | worker hosts in the inputs | compact topology: compute replicas 0 |
| `ImagePullBackOff` during install | `imageDigestSources` or `pullSecret` incomplete | re-run Lab 06 step 6.8, then Lab 08 |
| `x509: unknown authority` building the ISO | registry CA not trusted on the bastion | Lab 06 step 6.7 |
| etcd clock skew | nodes cannot reach `TIME_SOURCE`/bastion on UDP 123 | Lab 07; check `additionalNTPSources` |
| Operator Subscription never resolves | wrong CatalogSource name | script 06 reads it from oc-mirror output |
