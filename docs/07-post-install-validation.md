# Post-Install Validation

Run these checks after completing all deployment phases to confirm the dark site OCP-V cluster is healthy.

## Cluster Health

```bash
export KUBECONFIG=install-config/auth/kubeconfig

# All nodes Ready
oc get nodes -o wide

# All ClusterOperators Available
oc get co

# No failing pods in core namespaces
oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
```

Expected: 3 masters + 2+ workers, all `Ready`. All ClusterOperators `Available=True`.

## DNS Validation

```bash
# From bastion or any node
for host in api.ocpv-lab.ocp-v.local \
            registry.ocp-v.local \
            dns.ocp-v.local \
            ntp.ocp-v.local \
            cp01.ocp-v.local; do
  echo -n "$host → "
  dig @10.10.0.50 $host +short
done
```

All should resolve to the correct IPs from the addressing plan.

## NTP Validation

```bash
# On each node
for node in cp01 cp02 cp03 wk01 wk02; do
  echo "=== $node ==="
  ssh core@${node}.ocp-v.local chronyc tracking
done
```

Expected: all nodes synced to `10.10.0.51`, offset < 50ms.

## Mirror Registry

```bash
# Registry reachable
curl -sk https://registry.ocp-v.local:5000/v2/_catalog | jq .

# Cluster pulling from mirror (no ImagePullBackOff)
oc get pods -A | grep -i imagepull
```

## OpenShift Virtualization

```bash
# CNV operator healthy
oc get hyperconverged -n openshift-cnv -o yaml | grep -A2 conditions

# KubeVirt control plane
oc get kvih -n openshift-cnv

# Test VM creation
cat <<EOF | oc apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: test-vm
  namespace: default
spec:
  running: true
  template:
    spec:
      domain:
        devices:
          disks:
            - name: disk0
              disk:
                bus: virtio
          interfaces:
            - name: default
              masquerade: {}
        resources:
          requests:
            memory: 1Gi
      networks:
        - name: default
          pod: {}
      volumes:
        - name: disk0
          containerDisk:
            image: registry.ocp-v.local:5000/kubevirt/cirros-container-disk-demo
EOF

oc get vm test-vm
oc get vmi test-vm
```

## Infrastructure VMs

```bash
# DNS and NTP VMs running
oc get vm -n infrastructure
oc get vmi -n infrastructure

# DNS VM serving queries
dig @10.10.0.50 ocp-v.local SOA +short

# NTP VM serving time
chronyc -h 10.10.0.51 sources
```

## Network Connectivity Matrix

| From | To | Port | Expected |
|---|---|---|---|
| Any node | `10.10.0.50` | 53/TCP+UDP | DNS response |
| Any node | `10.10.0.51` | 123/UDP | NTP sync |
| Any node | `10.10.0.10` | 5000/TCP | Registry catalog |
| Any node | `10.10.0.100` | 6443/TCP | API server |
| Any node | `10.10.0.101` | 443/TCP | Ingress router |
| Bastion | All nodes | 22/TCP | SSH access |

Run the connectivity check script:

```bash
./scripts/00-prerequisites-check.sh --post-install
```

## MVP Decommission Verification

Confirm bastion DNS/NTP are no longer in use:

```bash
# On bastion — should be stopped
ssh root@10.10.0.5 systemctl is-active dnsmasq chronyd
# Expected: inactive

# No DNS queries hitting bastion
ssh root@10.10.0.5 "timeout 30 tcpdump -i ens192 port 53 -c 1"
# Expected: no packets captured
```

## Sign-Off Checklist

- [ ] All nodes `Ready`
- [ ] All ClusterOperators `Available`
- [ ] DNS resolves all cluster hostnames via production DNS VM
- [ ] NTP synced on all nodes via production NTP VM
- [ ] Mirror registry serving images (no pull errors)
- [ ] CNV / HyperConverged operator healthy
- [ ] Test VM created and running
- [ ] DNS VM and NTP VM running in `infrastructure` namespace
- [ ] Bastion MVP services decommissioned
- [ ] No internet dependency for cluster operations

## Next Steps

- Configure backup for etcd and VM snapshots
- Plan VLAN segmentation per [Network Design](02-network-design.md)
- Add monitoring (Prometheus is built into OCP)
- Document your site-specific runbook based on this reference
