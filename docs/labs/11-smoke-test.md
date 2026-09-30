# 11 — Smoke Test and Sign-off

## Goal

Prove the cluster is usable offline and that Virtualization works.

## WHERE

Bastion with kubeconfig.

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
./scripts/00-prerequisites-check.sh --post-install
```

## WHY this lab exists

Partners need a short, repeatable exit checklist before handing a CoE rack to a customer.

## DO — manual checks

```bash
oc get nodes
oc get co
oc get csv -n openshift-cnv
dig @"${DNS_VM_IP}" "registry.${BASE_DOMAIN}" +short
# Confirm no node still depends on bastion DNS if you decommissioned it:
# dig @"${BASTION_IP}" ... should fail or be unused
```

Optional: create a tiny test VM per [docs/07-post-install-validation.md](../07-post-install-validation.md).

## VERIFY checklist

- [ ] All nodes `Ready`  
- [ ] ClusterOperators available  
- [ ] Mirror registry still reachable from nodes  
- [ ] OpenShift Virtualization CSV `Succeeded`  
- [ ] DNS/NTP answered by production VMs (if Lab 10 done)  
- [ ] Bastion DNS/NTP stopped (if Lab 10 done)  
- [ ] Pull secret and registry passwords stored in a vault — not in git  

## You finished the labs

For rack/cabling depth, return to [GREENFIELD-README.md](../GREENFIELD-README.md).  
For Red Hat task mapping, see [00-disconnected-install-task-flow.md](../00-disconnected-install-task-flow.md).
