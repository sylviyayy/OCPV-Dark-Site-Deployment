# 13 — Installing OpenShift Virtualization

## Goal

Install `kubevirt-hyperconverged` from the mirrored catalog and verify KVM (and GPU node readiness).

## WHERE

Bastion.

```bash
cd OCPV-Dark-Site-Deployment
set -a && source .env && set +a
export KUBECONFIG="${PWD}/install-config/auth/kubeconfig"
./scripts/06-deploy-cnv.sh
```

## WHY

Turns RHCOS workers into hypervisors for VMs (including Lab 14 DNS/NTP VMs).  
On **SR675**, GPU workloads need the NVIDIA GPU Operator later (not in default CoE ImageSet unless you add it — see `mirror/imageset-ocpv-coe.yaml` comments and eanylin’s broader ImageSet for `gpu-operator-certified`).

## VERIFY

```bash
oc get csv -n openshift-cnv
oc get hyperconverged -n openshift-cnv
# KVM on each node — especially confirm virt is enabled on all three
```

Label the GPU node when ready, for example:

```bash
oc label node <cp03-hostname> nvidia.com/gpu.present=true --overwrite
# exact labels depend on the GPU Operator you install later
```

## Next

→ [14 — Production DNS and NTP on OCP-V](14-production-dns-ntp.md)

