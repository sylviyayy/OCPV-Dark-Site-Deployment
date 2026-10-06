# 09 — Certificates, Encryption, and etcd (what OpenShift creates for you)

> **Grade:** concepts, with one production-relevant finding: etcd encryption at rest is **opt-in**.

## Goal

Map the Kubernetes-the-Hard-Way topics (CA, kubeconfig, etcd, encryption) onto what the
Agent-based installer creates, so you know what exists, who owns it, and what is **not** on by default.

## What maps from the Hard Way to OpenShift

| Hard Way lab | OpenShift equivalent |
|---|---|
| Provision a CA and node certificates | The installer creates the cluster CAs; operators rotate the certificates |
| kubeconfig files | `${INSTALL_DIR}/auth/kubeconfig` plus `oc login` contexts (Lab 11) |
| Data encryption config | **Opt-in:** set `apiserver.spec.encryption.type` to `aescbc` or `aesgcm` (verify on 4.22). Not enabled by the install. |
| Bootstrap etcd | Static pods on the three control-plane nodes; quorum of 3 on this rack |
| Control plane components | `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` as operator-managed static pods |
| containerd | **CRI-O** on RHCOS |

Assuming encryption at rest is automatic plants a false security assumption that surfaces later
in an audit (FR-J5).

## Steps

### 9.1 Inspect what the installer created (after Lab 10)

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`, after Lab 10 completes

**WHY** — Seeing the etcd members, the API server operator and the encryption setting makes the
table above observable rather than asserted. Consumed by: your threat model and the site's
security sign-off. If skipped: encryption at rest stays off without anyone deciding so.

**EDIT** — No edits in this step. (Enabling encryption is a site decision: `oc patch apiserver cluster
--type merge -p '{"spec":{"encryption":{"type":"aescbc"}}}'`, then wait for the rollout.)

**DO**

```bash
set -a && source .env && set +a
export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
oc get pods -n openshift-etcd -l app=etcd -o wide
oc get clusteroperators etcd kube-apiserver
```

**VERIFY**

```bash
oc get pods -n openshift-etcd -l app=etcd --no-headers | grep -c Running        # expect: 3
oc get apiserver cluster -o jsonpath='{.spec.encryption.type}{"\n"}'             # expect: empty (identity) unless you opted in
```

**FAILS IF** — Fewer than 3 etcd pods Running ← a control-plane node is down; quorum survives one loss, not two.

Clock skew between members breaks etcd and TLS — the reason Lab 07 exists.

## Next

→ [10 — Bootstrapping the Cluster with the Agent-based Installer](10-bootstrap-cluster.md)
