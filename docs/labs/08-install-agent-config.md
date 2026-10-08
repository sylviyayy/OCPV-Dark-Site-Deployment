# 08 — Generating Install and Agent Configuration

> **Primary hands-on path:** If you already have `agent.ove.x86_64` from the Hybrid Cloud
> Console ([USB Transfer Kit](../USB-TRANSFER-KIT.md)), you configure the cluster in the
> Assisted UI after Lab 10 boots — treat this lab as **optional / advanced** (classic
> `openshift-install agent create image` + oc-mirror). Lab **09** after this is conceptual.

## Goal

Create `install-config.yaml`, `agent-config.yaml`, and the Agent discovery ISO
(classic ABI path).

## WHERE

Bastion.

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
your compact topology (see Red Hat Agent-based compact cluster notes for 4.21.27).

## DO — back up and validate (no clock yet)

`openshift-install` consumes (deletes) both YAML files. Back them up first, then validate
in a throwaway copy. `cluster-manifests` creates no certificates, so it starts no clock.

```bash
mkdir -p ~/config-backup
cp install-config/install-config.yaml install-config/agent-config.yaml ~/config-backup/
rm -rf /tmp/abi-validate && mkdir /tmp/abi-validate && cp ~/config-backup/*.yaml /tmp/abi-validate/
openshift-install agent create cluster-manifests --dir=/tmp/abi-validate
```

## DO — build ISO (T-0)

> **[WINDOW A] The 24-hour clock starts when this command runs.** The ISO embeds
> certificates that expire 24 hours after creation, and Red Hat recommends booting within
> **12 hours**. Build it **on site**, only after the
> [go/no-go gate](../BASTION-LIFECYCLE.md#phase-4-compose-and-validate-the-install-configuration-no-clock)
> passes, and only when you can boot the nodes right away (Lab 10).
> `scripts/05-install-ocp-disconnected.sh` runs this step and then waits for you to boot.

```bash
openshift-install agent create image --dir=install-config/ --log-level=info
ls -lh install-config/agent.x86_64.iso
```

## VERIFY

- [ ] `additionalTrustBundle` is a real cert  
- [ ] MACs match Lab 03 / 05  
- [ ] `rendezvousIP` = one CP IP  
- [ ] `additionalNTPSources` lists `BASTION_IP`  
- [ ] Configs backed up to `~/config-backup/` (needed to regenerate if Window A lapses)  
- [ ] ISO file exists  

## Next

→ [09 — Certificates, Encryption, and etcd](09-certificates-etcd.md)

**Next after verify:** Lab 09 explains certs/etcd concepts; Lab 10 boots the ISO.
