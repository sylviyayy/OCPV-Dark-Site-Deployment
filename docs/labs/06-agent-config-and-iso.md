# 06 — Generate Agent Configs and the Discovery ISO

## Goal

Create `install-config.yaml`, `agent-config.yaml`, and the Agent discovery ISO used to boot cluster nodes.

## WHERE

Bastion, with clients from the mirror directory on `PATH`.

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export PATH="${MIRROR_DIR}/clients:${PATH}"
./scripts/03-generate-install-config.sh
```

## WHY this lab exists

Agent-based install is driven by two files:

| File | Meaning |
|---|---|
| `install-config.yaml` | Cluster identity, VIPs, pull secret, registry CA trust |
| `agent-config.yaml` | Per-node MAC, IP, DNS, routes, disk hints, `rendezvousIP` |

Without correct MACs and static networking, nodes boot the ISO and never join.

## DO — review generated files with vim

```bash
vim install-config/install-config.yaml
vim install-config/agent-config.yaml
```

### Check these by hand

In `install-config.yaml`:

- `metadata.name` = your `CLUSTER_NAME`  
- `baseDomain` = your `BASE_DOMAIN`  
- `platform.baremetal.apiVIPs` / `ingressVIPs` match `.env`  
- `additionalTrustBundle` contains a real certificate (not the placeholder)  
- `pullSecret` is present (large JSON)  

In `agent-config.yaml`:

- `rendezvousIP` equals your chosen control-plane IP  
- Each host `macAddress` matches reality  
- `dns-resolver` server is `BASTION_IP`  
- IPs match `.env`  

## DO — create manifests and ISO

```bash
openshift-install agent create cluster-manifests --dir=install-config/
openshift-install agent create image --dir=install-config/ --log-level=info
ls -lh install-config/agent.x86_64.iso
```

## WHY Agent ISO (not PXE, not “install RHEL then kubeadm”)

Red Hat’s Agent-based Installer embeds the Assisted Installer service in the ISO. For disconnected bare metal this means:

- no DHCP requirement  
- no separate bootstrap VM  
- no external load balancer requirement  

You will mount this ISO on each node’s BMC (next lab).

## VERIFY

```bash
test -f install-config/agent.x86_64.iso && echo "ISO ready"
grep -n rendezvousIP install-config/agent-config.yaml
```

## FAILS IF

| Mistake | Result |
|---|---|
| Placeholder MACs left in place | No hosts discovered |
| Missing registry CA in install-config | TLS errors pulling images |
| ISO never created | Nothing to mount on BMC |

## Next

→ [07 — Boot nodes from the ISO](07-boot-nodes-bmc.md)
