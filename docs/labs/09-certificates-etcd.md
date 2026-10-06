# 09 — Certificates, Encryption, and etcd (what OpenShift creates for you)

> **Grade:** concepts, with one production finding: etcd encryption at rest is **opt-in**.

## Goal

Map the Kubernetes-the-Hard-Way topics onto what the Agent-based installer creates, so you know
what exists, who rotates it, and what is **not** on by default.

| Hard Way lab | OpenShift equivalent |
|---|---|
| CA and node certificates | Installer creates the cluster CAs; operators rotate certificates |
| kubeconfig files | `${INSTALL_DIR}/auth/kubeconfig`, then `oc login` contexts (Lab 11) |
| Data encryption config | **Opt-in:** `apiserver.spec.encryption.type` = `aescbc` or `aesgcm` (verify on 4.22) |
| Bootstrap etcd | Static pods on the three masters; quorum 2 of 3 |
| Control plane | `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` as operator-managed static pods |
| containerd | **CRI-O** on RHCOS |

Assuming encryption at rest is automatic is a false assumption an auditor finds before you do.

## Steps

### 9.1 Inspect etcd and the encryption setting (after Lab 10)

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`, after Lab 10

**WHY** — Observing the three etcd members and the encryption type turns the table into evidence.
*Consumed by:* the site's security sign-off. *If skipped:* encryption stays off without anyone deciding so.

**EDIT** — None. Enabling encryption is a site decision:
`oc patch apiserver cluster --type merge -p '{"spec":{"encryption":{"type":"aescbc"}}}'`, then wait
for `oc get kubeapiserver -o jsonpath='{.items[0].status.conditions[?(@.type=="Encrypted")].reason}'` → `EncryptionCompleted`.

**DO / VERIFY**

```bash
set -a && source .env && set +a
export KUBECONFIG="${INSTALL_DIR}/auth/kubeconfig"
oc get pods -n openshift-etcd -l app=etcd --no-headers | grep -c Running         # expect: 3
oc get apiserver cluster -o jsonpath='{.spec.encryption.type}{"\n"}'              # expect: empty, unless you opted in
```

**FAILS IF** — Fewer than 3 etcd pods Running ← a master is down; quorum survives one loss, not two.
Clock skew between members breaks etcd — the reason Lab 07 exists.

## Next

→ [10 — Bootstrapping the Cluster with the Agent-based Installer](10-bootstrap-cluster.md)
