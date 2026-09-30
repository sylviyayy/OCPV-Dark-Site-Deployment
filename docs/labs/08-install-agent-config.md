# 08 — Generating Install and Agent Configuration

## Goal

Create `install-config.yaml`, `agent-config.yaml`, and the Agent discovery ISO.

## WHERE

Jumpbox.

```bash
cd OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export PATH="${MIRROR_DIR}/clients:${PATH}"
./scripts/03-generate-install-config.sh
vim install-config/install-config.yaml
vim install-config/agent-config.yaml
```

## WHY

Hard Way generates kubeconfigs by hand. Here you generate **Agent** configs: cluster
identity, registry CA, per-node MAC/IP/DNS (nmstate), and `rendezvousIP`.

For the 3-node Lenovo compact lab, ensure all three hosts are listed and roles match
your compact topology (see Red Hat Agent-based compact cluster notes for 4.22).

## DO — build ISO

```bash
openshift-install agent create cluster-manifests --dir=install-config/
openshift-install agent create image --dir=install-config/ --log-level=info
ls -lh install-config/agent.x86_64.iso
```

## VERIFY

- [ ] `additionalTrustBundle` is a real cert  
- [ ] MACs match Lab 03 / 05  
- [ ] `rendezvousIP` = one CP IP  
- [ ] ISO file exists  

## Next

→ [09 — Certificates, Encryption, and etcd](09-certificates-etcd.md)

**Next after verify:** Lab 09 explains certs/etcd concepts; Lab 10 boots the ISO.
