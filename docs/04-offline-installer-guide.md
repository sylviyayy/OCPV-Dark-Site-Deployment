# Offline Installer Guide

Install OpenShift in a fully disconnected environment using a local mirror registry.

## Prerequisites

- [x] Bastion host kickstarted and reachable
- [x] Mirror registry loaded with OCP images
- [x] MVP DNS/NTP running on bastion
- [x] Pull secret at `/opt/ocp-mirror/pull-secret.json`
- [x] Bare-metal nodes (or VMs) ready with static IPs

## Installation Method: Agent-Based

Agent-based install is recommended for dark sites because:

- No bootstrap VM required
- Each node boots from a discovery ISO
- Works entirely offline once the ISO is generated

## Step 1 — Generate install configuration

On the bastion:

```bash
cd /home/installer/OCPV-Dark-Site-Deployment
source .env

./scripts/03-generate-install-config.sh
```

This creates:

```
install-config/
├── install-config.yaml      # Cluster configuration
├── agent-config.yaml        # Per-node agent config
└── auth/
    ├── kubeconfig           # (generated after install)
    └── k8s-local.json       # (generated after install)
```

Review the generated files before proceeding.

## Step 2 — Generate discovery ISO

```bash
openshift-install agent create cluster-manifests --dir=install-config/
openshift-install agent create image --dir=install-config/ --log-level=info
```

Output: `install-config/agent.x86_64.iso`

Copy this ISO to USB and boot each node (control plane first, then workers).

## Step 3 — Boot nodes from discovery ISO

For each node:

1. Boot from `agent.x86_64.iso` (USB or virtual media)
2. The agent discovers the node and registers with the installer service on the bastion
3. Monitor progress:

```bash
openshift-install agent wait-for bootstrap-complete --dir=install-config/ --log-level=info
```

Expected timeline:
- Bootstrap: 30–45 minutes
- Control plane: 20–30 minutes per node
- Workers join: 10–15 minutes each

## Step 4 — Monitor installation

```bash
# Watch agent logs
openshift-install agent wait-for install-complete --dir=install-config/ --log-level=info

# Or monitor from another terminal
export KUBECONFIG=install-config/auth/kubeconfig
watch oc get nodes
```

## Step 5 — Post-install configuration

After `install-complete`:

```bash
export KUBECONFIG=install-config/auth/kubeconfig

# Verify cluster
oc get nodes
oc get co    # ClusterOperators — all should be Available

# Configure mirror registry in cluster
oc apply -f install-config/mirror-config-generated.yaml
```

## Step 6 — Deploy OpenShift Virtualization (CNV)

```bash
./scripts/06-deploy-cnv.sh
```

This script:
1. Creates `openshift-cnv` namespace
2. Applies the HyperConverged operator from the mirrored catalog
3. Waits for CNV to become available
4. Verifies KVM is enabled on worker nodes

Verify:

```bash
oc get hyperconverged -n openshift-cnv
oc get kvih -n openshift-cnv    # KubeVirt control plane
```

## Disconnected Install Configuration Details

### ImageContentSourcePolicy

The mirror registry redirect is configured via `ImageContentSourcePolicy`:

```yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: ocp-mirror
spec:
  repositoryDigestMirrors:
    - source: quay.io/openshift-release-dev/ocp-release
      mirrors:
        - registry.ocp-v.local:5000/openshift/release
    - source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
      mirrors:
        - registry.ocp-v.local:5000/openshift/release
```

### CatalogSource for Operators

CNV and other operators require a mirrored catalog source:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cs-redhat-operator-index
  namespace: openshift-marketplace
spec:
  image: registry.ocp-v.local:5000/redhat/redhat-operator-index:v4.14
  sourceType: grpc
  displayName: Red Hat Operator Index (Mirrored)
  publisher: Red Hat
  updateStrategy:
    registryPoll:
      interval: 30m
```

### Registry CA Trust

Every node must trust the mirror registry's self-signed CA:

```bash
# On bastion — extract CA cert
openssl s_client -connect 10.10.0.10:5000 -showcerts </dev/null 2>/dev/null \
  | openssl x509 -outform PEM > /tmp/registry-ca.crt

# Apply to cluster
oc create configmap registry-ca \
  --from-file=registry.ocp-v.local..5000=/tmp/registry-ca.crt \
  -n openshift-config

oc patch image config.imageregistrycluster -p \
  '{"spec":{"additionalTrustedCA":{"registry.ocp-v.local..5000":"registry-ca"}}}' \
  --type=merge
```

## Alternative: IPI with Static IPs

If you prefer installer-provisioned infrastructure with static IPs, use the templates in `install-config/install-config.yaml.template` with `platform: baremetal` and configure `bootstrapOSImage` to point to your mirror.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff` on operators | Mirror not configured | Apply `ImageContentSourcePolicy` and `CatalogSource` |
| Bootstrap timeout | DNS not resolving API | Check dnsmasq, verify `api.<cluster>.<domain>` resolves |
| etcd health check fails | Clock skew > 500ms | Verify chronyd on all nodes: `chronyc tracking` |
| Agent not discovering | Firewall between nodes and bastion | Open ports 80, 443, 8080 on bastion during install |
| CNV install fails | Workers lack KVM | Enable VT-x/AMD-V in BIOS; check `ls /dev/kvm` |

## Next Steps

→ [MVP Network Services](05-mvp-network-services.md) (if not already done)
→ [Production Network Services](06-production-network-services.md)
