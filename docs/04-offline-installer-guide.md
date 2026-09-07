# Offline Installer Guide (OpenShift 4.22 — Agent-Based, Disconnected)

Install OpenShift Container Platform **4.22** in a fully disconnected environment using
the **Agent-based Installer** and **oc-mirror plugin v2**.

## Official documentation

| Topic | Link |
|---|---|
| Disconnected environments overview | [OCP 4.22 Disconnected environments](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index) |
| oc-mirror plugin v2 | [About oc-mirror v2](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2) |
| Agent-based disconnected mirroring | [Understanding disconnected mirroring (ABI)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/understanding-disconnected-installation-mirroring) |
| Agent-based installation | [Installing with Agent-based Installer](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/installing_an_on-premise_cluster_with_the_agent-based_installer/index) |
| OpenShift Virtualization | [Installing virtualization](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/virtualization/installing) |

## Why Agent-based Installer for dark sites?

Per Red Hat, the Agent-based Installer is the **preferred** method for disconnected installs:

- No external load balancer required
- No bootstrap VM
- No DHCP required (static nmstate networking)
- Embeds Assisted Installer service in the discovery ISO
- Supports bare metal, vSphere, and `platform: none`

## Prerequisites

- [x] Bastion host operational with `openshift-install`, `oc`, `oc-mirror` (from staging)
- [x] Mirror registry running and loaded with oc-mirror v2 output
- [x] MVP DNS/NTP on bastion (`scripts/02-bootstrap-dns-ntp.sh`)
- [x] Cluster pull secret (not mirror-registry credentials)
- [x] `cluster-resources/` from oc-mirror workdir available
- [x] All node MAC addresses documented

## Step 1 — Generate install configuration

```bash
cd /home/installer/OCPV-Dark-Site-Deployment
cp .env.example .env   # if not done
vi .env                # set OCP_VERSION=4.22.2, MAC addresses, rendezvous IP

./scripts/03-generate-install-config.sh
```

Review generated files:

```
install-config/
├── install-config.yaml    # pullSecret, additionalTrustBundle, baremetal VIPs
├── agent-config.yaml      # rendezvousIP, per-node nmstate, MACs
└── mirror/                # registries.conf for agent ISO (if generated)
```

**Critical fields:**

```yaml
# install-config.yaml
additionalTrustBundle: |
  -----BEGIN CERTIFICATE-----
  ... mirror registry CA ...
  -----END CERTIFICATE-----

# agent-config.yaml
rendezvousIP: 10.10.1.11   # must match one control-plane node IP
```

## Step 2 — Validate manifests and create discovery ISO

```bash
openshift-install agent create cluster-manifests --dir=install-config/
openshift-install agent create image --dir=install-config/ --log-level=info
```

Output: `install-config/agent.x86_64.iso`

> The ISO embeds the Assisted Service. One node (rendezvousIP) runs the temporary
> bootstrap logic during installation.

Copy the ISO to USB/virtual media and boot **all** cluster nodes.

## Step 3 — Boot nodes and monitor

```bash
openshift-install agent wait-for install-complete \
  --dir=install-config/ \
  --log-level=info
```

Monitor from another terminal:

```bash
export KUBECONFIG=install-config/auth/kubeconfig
watch oc get nodes
oc get clusterversion
```

Expected duration: 60–90 minutes for 3 masters + 2 workers.

## Step 4 — Apply mirror registry cluster resources

oc-mirror v2 generates `ImageDigestMirrorSet`, `ImageTagMirrorSet`, and `CatalogSource`
in `${OC_MIRROR_WORKDIR}/cluster-resources/`:

```bash
oc apply -f "${OC_MIRROR_WORKDIR}/cluster-resources/"
```

Verify:

```bash
oc get imagedigestmirrorset,imagetagmirrorset,catalogsource -A
```

> **Do not use ImageContentSourcePolicy** for new 4.22 installs — it is superseded by
> IDMS/ITMS per Red Hat disconnected environments documentation.

## Step 5 — Deploy OpenShift Virtualization

```bash
./scripts/06-deploy-cnv.sh
```

Verify (expected CSV version aligns with OCP 4.22.z):

```bash
oc get csv -n openshift-cnv
oc get hyperconverged -n openshift-cnv \
  -o jsonpath='{.items[0].status.versions}' | jq .
```

## Disconnected configuration details

### Mirror registry CA trust

The registry CA must be in `install-config.yaml` `additionalTrustBundle` **before** ISO
generation. Post-install, also configure cluster-wide trust if needed:

```bash
oc create configmap registry-ca \
  --from-file="${MIRROR_REGISTRY_HOSTNAME}..${MIRROR_REGISTRY##*:}"="${MIRROR_DIR}/registry-ca.crt" \
  -n openshift-config
```

### registries.conf (TOML v2)

oc-mirror v2 generates `registries.conf` in TOML format. For GitOps ZTP or custom agent
ISO builds, mount under the agent ISO `mirror/` path per Red Hat ABI disconnected guide.

### Operator catalog

The mirrored catalog image must match your OCP minor version:

```
registry.<domain>:<port>/redhat/redhat-operator-index:v4.22
```

List mirrored operators:

```bash
oc mirror list operators --catalog=cs-redhat-operator-index -n openshift-marketplace --v2
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` | IDMS/ITMS not applied | `oc apply -f cluster-resources/` |
| ISO boots but no discovery | Wrong MAC in agent-config | Match `ip link` output |
| Install hangs at bootstrap | rendezvousIP unreachable | Verify IP, DNS, firewall |
| etcd clock skew | No NTP | MVP chronyd on bastion; all nodes sync |
| Registry TLS error | Missing CA in install-config | Regenerate ISO with `additionalTrustBundle` |
| CNV CSV stuck | Catalog not mirrored | Re-run oc-mirror with `kubevirt-hyperconverged` package |
| Version mismatch | Mixed 4.21/4.22 images | Re-mirror with single z-stream in ImageSet |

## Next steps

→ [MVP Network Services](05-mvp-network-services.md)
→ [Production Network Services](06-production-network-services.md)
→ [Post-Install Validation](07-post-install-validation.md)
