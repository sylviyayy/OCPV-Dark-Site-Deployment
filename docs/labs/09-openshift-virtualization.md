# 09 — Install OpenShift Virtualization

## Goal

Install the OpenShift Virtualization operator (`kubevirt-hyperconverged`) from your mirrored catalog.

## WHERE

Bastion (with kubeconfig), against the live cluster.

```bash
cd /path/to/OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
./scripts/06-deploy-cnv.sh
```

## WHY this lab exists

OpenShift alone schedules containers. **OpenShift Virtualization** adds KubeVirt so the same cluster can run VMs (including your future DNS/NTP VMs). The operator must come from the **mirrored** catalog in a dark site.

## WHAT the script does

1. Ensures mirrored CatalogSource is present  
2. Creates `openshift-cnv` namespace + OperatorGroup + Subscription  
3. Creates the `HyperConverged` custom resource  
4. Checks `/dev/kvm` on workers  

## VERIFY

```bash
oc get csv -n openshift-cnv
# PHASE should become Succeeded

oc get hyperconverged -n openshift-cnv
oc get pods -n openshift-cnv
```

On a worker (debug node) you need `/dev/kvm`. If missing, enable virtualization in BIOS and reboot.

## FAILS IF

| Problem | Symptom |
|---|---|
| `kubevirt-hyperconverged` not in ImageSet | Subscription never resolves |
| Nested virt disabled / no KVM | Operator may install; VMs will not start |
| Default catalogs still trying internet | Re-apply Lab 08 mirror resources |

## Next

→ [10 — Production DNS/NTP on OCP-V](10-production-dns-ntp.md)
