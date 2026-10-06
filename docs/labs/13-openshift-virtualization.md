# 13 — Installing OpenShift Virtualization

> **Grade:** lab-grade storage. The hostpath provisioner keeps VM disks on each node's RAID1
> RHCOS disk: node-local, ReadWriteOnce, no live migration, and it shares the disk with etcd.
> Production adds data drives (LVMS) or a SAN CSI driver (ADR-05).

## Goal

Install OpenShift Virtualization and Kubernetes NMState from the mirrored catalog, prove KVM on
every node, and give the cluster a default StorageClass so DataVolumes can bind.

## Steps

### 13.1 Install the operators

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 06 subscribes to `kubevirt-hyperconverged` and `kubernetes-nmstate-operator` from
the CatalogSource whose name it reads from oc-mirror's output (oc-mirror v2 derives it from the
catalog image and tag, so a hard-coded name never resolves, FR-G1). Every wait ends in exit 1 with
diagnostics instead of falling through (FR-G4). The `HyperConverged` spec is left at defaults: no
host-passthrough CPU (it pins a VM to one CPU model) and no live-migration tuning (there is no live
migration on node-local disks, FR-G5). NMState is needed for the localnet bridge mapping and the DNS
cut-over in Lab 14. On a compact cluster all three nodes run VMs, so all three must expose `/dev/kvm`.
Consumed by: 13.2 and Lab 14. If skipped: no VM can be defined.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/06-deploy-cnv.sh
```

**VERIFY**

```bash
oc get csv -n openshift-cnv -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}'   # expect: kubevirt-hyperconverged-operator… Succeeded
oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{"\n"}'                            # expect: True
oc get nodes -o jsonpath='{range .items[*]}{.metadata.name} {.status.allocatable.devices\.kubevirt\.io/kvm}{"\n"}{end}'   # expect: three lines, each with a non-zero count
```

**FAILS IF** — "/dev/kvm missing on: mwNN" ← SVM disabled in UEFI (Lab 05 step 5.2);
Subscription never resolves ← Lab 12 not applied.

### 13.2 Give the cluster a default StorageClass

**WHERE** — Bastion, RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Every VM root disk is a DataVolume, and a DataVolume with no StorageClass stays `Pending`
forever (FR-G3). With `STORAGE_BACKEND=hpp`, script 06b creates the HostPathProvisioner, a
`hostpath-csi` StorageClass marked default, and proves it by binding a 1 GiB test DataVolume.
Consumed by: the DNS and NTP VM DataVolumes in Lab 14 (`storageClassName`).
If skipped: both DNS VMs wait for disks that never arrive.

**EDIT** — No edits in this step. (LVMS: set `STORAGE_BACKEND=lvms` in `.env` before Lab 06 so the
operator is mirrored, and add an empty data disk to each node.)

**DO**

```bash
./scripts/06b-configure-storage.sh
```

**VERIFY** (AT-09)

```bash
oc get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
# expect: hostpath-csi   (lvms-vg1 with LVMS)
```

The script's last line is `PASS: … a 1 GiB DataVolume reached Succeeded`.

**FAILS IF** — The test DataVolume stays `Pending` ← the HostPathProvisioner is not `Available`; read its status in the script's output.

### GPU node (later)

`mw03` (SR675 V3, 8× L40S) needs the NVIDIA GPU Operator, which is not in the default ImageSet
(a v2.0 non-goal). Add `gpu-operator-certified` to a profile in `mirror/imageset-profiles.yaml` and
re-mirror when you need it.

## Next

→ [14 — Production DNS and NTP on OCP-V](14-production-dns-ntp.md)
