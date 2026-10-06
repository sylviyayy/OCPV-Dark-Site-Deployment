# 15 — Smoke Test

## Goal

Prove the cluster works offline and Virtualization is usable.

## WHERE

Bastion.

```bash
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
./scripts/00-prerequisites-check.sh --post-install
oc get nodes
oc get co
oc get csv -n openshift-cnv
```

Optional deeper checks: [07-post-install-validation.md](../07-post-install-validation.md)

## VERIFY checklist

- [ ] Three nodes `Ready` (compact)  
- [ ] ClusterOperators available  
- [ ] Registry reachable; no mass `ImagePullBackOff`  
- [ ] OpenShift Virtualization CSV `Succeeded`  
- [ ] DNS/NTP on production VMs if Lab 14 done  
- [ ] Secrets not in git  

## Next

→ [16 — Cleaning Up](16-cleanup.md)
