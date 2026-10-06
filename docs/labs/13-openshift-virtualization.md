# 13 — Installing OpenShift Virtualization

> **Grade:** set by `STORAGE_BACKEND`. `ontap` (Lenovo DM/DG) is production-grade shared storage.
> `hpp` is **interim, lab-grade**: VM disks share each node's RAID1 OS disk with etcd, and cannot
> live-migrate. `lvms` is production-grade local storage without live migration (ADR-05).

## Goal

Install OpenShift Virtualization, Kubernetes NMState and the storage operator from the mirrored
catalogs, prove KVM on every node, and give the cluster exactly one default StorageClass.

| `STORAGE_BACKEND` | Hardware | StorageClass | Access | VM on node drain |
|---|---|---|---|---|
| `ontap` (target) | Lenovo DM or DG array, NFS via NetApp Trident | `ontap-nas` | ReadWriteMany | **live-migrates** |
| `hpp` (interim) | directory on each node's OS disk | `hostpath-csi` | ReadWriteOnce, node-local | stops until the node returns |
| `lvms` | one empty disk per node, or one DS-series LUN per node | `lvms-vg1` | ReadWriteOnce, node-local | stops until the node returns |

Switching later (for example `hpp` → `ontap` when the array arrives) is supported: re-mirror (Lab 06),
re-run 13.1 and 13.2; script 06b demotes the old default. Existing VM disks stay where they are.

## Steps

### 13.1 Install the operators

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 06 subscribes, from the mirrored catalogs, to:

- `kubevirt-hyperconverged` — OpenShift Virtualization. One non-default: `enableCommonBootImageImport: false`,
  because the golden-image import pulls from `registry.redhat.io` and retries forever; VMs here use
  the digest-pinned guest image from the mirror.
- `kubernetes-nmstate-operator` — the localnet bridge mapping and the DNS cut-over in Lab 14.
- `trident-operator` (`ontap`, certified catalog) or `lvms-operator` (`lvms`); nothing extra for `hpp`.

Each wait ends in exit 1 with diagnostics, never a silent fall-through. Last, it proves `/dev/kvm` on
every node: on a compact cluster all three run VMs.
*Consumed by:* 13.2 and Lab 14. *If skipped:* no VM can be defined.

**EDIT** — None.

**DO** — `./scripts/06-deploy-cnv.sh`

**VERIFY**

```bash
oc get hyperconverged kubevirt-hyperconverged -n openshift-cnv \
  -o jsonpath='{.status.conditions[?(@.type=="Available")].status}{"\n"}'     # expect: True
oc get csv -A --no-headers | grep -E 'kubevirt-hyperconverged|kubernetes-nmstate' | awk '{print $NF}'   # expect: Succeeded ×2
```

**FAILS IF** — `/dev/kvm missing on: mwNN` ← SVM off in UEFI (Lab 05 step 5.2);
`CatalogSource … READY` times out ← Lab 12 not done, or `ontap` chosen after mirroring (re-run Lab 06).

### 13.2 Give the cluster one default StorageClass

**WHERE** — Bastion, `installer`, cwd `~/OCPV-Dark-Site-Deployment`; for `ontap`, the SVM password to hand

**WHY** — Every VM disk is a DataVolume; with no default StorageClass it stays `Pending` forever.
Script 06b, by backend:

- **`ontap`** — prompts the SVM password into Secret `ontap-svm-credentials` (stdin only, never stored
  in `.env` or argv); installs Trident with AutoSupport silenced (nothing to send it to); registers an
  `ontap-nas` backend on the SVM's data LIF with `autoExportPolicy` restricted to `MACHINE_NETWORK_CIDR`,
  so Trident maintains the NFS export rules; sets the StorageProfile to ReadWriteMany Filesystem,
  which live migration needs.
- **`hpp`** — creates a HostPathProvisioner pool at `/var/hpvolumes` on each node.
- **`lvms`** — creates an LVMCluster over every empty disk on each node.

It then demotes any other default, asserts exactly one, and binds a 1 GiB test DataVolume (AT-09).
*Consumed by:* the DNS and NTP VM disks in Lab 14.

**EDIT** — None (backend chosen by `STORAGE_BACKEND`, group G for `ontap`).

**DO** — `./scripts/06b-configure-storage.sh`

**VERIFY** — Last line `PASS: default StorageClass <name>; a 1 GiB DataVolume reached Succeeded`, and:

```bash
oc get sc | grep -c '(default)'          # expect: 1
```

**FAILS IF** — `ONTAP backend Bound` times out ← wrong G1/G3, wrong password, or management LIF
unreachable (the script prints Trident's message); Trident pods `ImagePullBackOff` ← its images are
not in the mirror (TODO verify list in ADR-05); `LVMCluster Ready` times out ← no empty disk or LUN
on some node; test DataVolume `Pending` ← provisioner not Available.

### GPU node (later)

`mw03` (8× L40S) needs the NVIDIA GPU Operator, which is out of scope for v2.0. Add
`gpu-operator-certified` from the certified catalog to a profile in `mirror/imageset-profiles.yaml`
and re-mirror when you need it.

## Next

→ [14 — Production DNS and NTP on OCP-V](14-production-dns-ntp.md)
