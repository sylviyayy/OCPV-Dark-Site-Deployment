# Staging mirror (detail)

> Canonical lab: [06 — Mirroring Images](../06-mirroring-images.md).

## Goal

On a machine **with internet**, download OpenShift clients and mirror release + operator images to disk.

## WHERE

**Staging** = Fedora laptop **or** RHEL 10 KVM VM with:

- internet access  
- Red Hat pull secret in place (Lab 02)  
- lots of free disk under `MIRROR_DIR` (often `/opt/ocp-mirror`)

```bash
cd ~/OCPV-Dark-Site-Deployment   # or your clone path
set -a && source .env && set +a
```

## WHY this lab exists

The dark site cannot reach `quay.io` or `registry.redhat.io`.  
`oc mirror` (plugin v2) copies the exact images your cluster will need onto removable media.

## DO — run mirror preparation

```bash
# Install/download clients + write ImageSet config
./scripts/01-mirror-preparation.sh

# Actually mirror to disk (large download — can take hours)
./scripts/01-mirror-preparation.sh --mirror-to-disk
```

### WHAT the script is doing (rationale)

1. Downloads `oc`, `openshift-install`, and `oc-mirror` for your `OCP_VERSION` from Red Hat’s public mirror  
2. Builds an ImageSetConfiguration for `stable-4.22` + `kubevirt-hyperconverged`  
3. With `--mirror-to-disk`, runs `oc mirror --v2` into `OC_MIRROR_WORKDIR`  

For a richer CoE operator set later, you can point at `mirror/imageset-ocpv-coe.yaml` (still **no MTV** unless you add it).

## DO — pack for USB

```bash
sudo tar -C "$(dirname "${MIRROR_DIR}")" -czf /tmp/ocp-mirror.tar.gz "$(basename "${MIRROR_DIR}")"
ls -lh /tmp/ocp-mirror.tar.gz
# Copy /tmp/ocp-mirror.tar.gz + this git repo + RHEL ISO + pull-secret.json onto USB
```

## VERIFY

```bash
ls "${MIRROR_DIR}/clients/oc" "${MIRROR_DIR}/clients/openshift-install" "${MIRROR_DIR}/clients/oc-mirror"
"${MIRROR_DIR}/clients/oc-mirror" --v2 --help | head
# After mirror-to-disk, cluster-resources should exist under the workdir:
find "${OC_MIRROR_WORKDIR}" -type d -name cluster-resources 2>/dev/null
```

## FAILS IF

| Problem | Result |
|---|---|
| No pull secret | Auth errors from Red Hat registries |
| Disk full mid-mirror | Incomplete archive; install later fails randomly |
| Mixed versions in ImageSet | Operators stuck `Pending` |

## Next

→ [Lab 06 — Mirroring Images](../06-mirroring-images.md)
