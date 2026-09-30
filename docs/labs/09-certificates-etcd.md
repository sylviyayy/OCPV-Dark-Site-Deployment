# 09 — Certificates, Encryption, and etcd (what OpenShift creates for you)

## Goal

Understand the Hard Way topics (CA, kubeconfig crypto, etcd) **without** installing them
by hand — Agent-based OpenShift does this during bootstrap.

## WHERE

Reading on the jumpbox. Optional inspection **after** Lab 10 succeeds.

## WHY

Kubernetes The Hard Way spends several labs on TLS and etcd so you learn the control
plane. On OpenShift those components still exist; the installer and operators own them.
Skipping the *concepts* leaves you blind when `etcd` or cert rotation breaks later.

## What maps from Hard Way → OpenShift

| Hard Way lab | OpenShift equivalent |
|---|---|
| Provision CA / node certs | Cluster bootstrap creates the cluster CA; machine config / operators renew |
| kubeconfig files | `install-config/auth/kubeconfig` + `oc` login contexts (Lab 11) |
| Data encryption config | Automatically configured for etcd at rest (platform managed) |
| Bootstrap etcd | Static pods on control-plane nodes; quorum of 3 on this rack |
| Control plane components | `kube-apiserver`, `kube-controller-manager`, `kube-scheduler` as static/operand pods |
| containerd | **CRI-O** on RHCOS |

## DO — after the cluster is up (Lab 10+), inspect

```bash
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
oc get nodes
oc get pods -n openshift-etcd
oc get clusteroperators etcd kube-apiserver
```

## VERIFY

You can explain: three control-plane nodes ⇒ etcd quorum; why clock skew (Lab 07) matters.

## Next

→ [10 — Bootstrapping the Cluster with the Agent-based Installer](10-bootstrap-cluster.md)
