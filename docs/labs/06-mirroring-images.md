# 06 — Mirroring Images for a Disconnected Install

## Goal

On a machine **with internet**, download clients and mirror OpenShift 4.22 + Virtualization
images to disk, then carry them into the dark site.

## WHERE

Jumpbox **while connected**, or a separate staging Fedora/RHEL VM with internet.  
Same machine can later move to the dark VLAN with the USB archive.

## WHY

Cluster nodes cannot reach `quay.io` / `registry.redhat.io`. oc-mirror v2 builds the
offline image set (Hard Way equivalent of “download the right binaries”).

## DO

```bash
cd OCPV-Dark-Site-Deployment
set -a && source .env && set +a
./scripts/01-mirror-preparation.sh
./scripts/01-mirror-preparation.sh --mirror-to-disk
```

Pack for USB:

```bash
sudo tar -C "$(dirname "${MIRROR_DIR}")" -czf /tmp/ocp-mirror.tar.gz "$(basename "${MIRROR_DIR}")"
```

Copy tarball + this repo + pull secret + RHEL ISO to removable media.

On the dark-site registry host (or jumpbox if co-located):

```bash
./scripts/04-mirror-ocp-images.sh disk-to-mirror
```

Detail: [detail/staging-mirror.md](detail/staging-mirror.md).

## VERIFY

```bash
ls "${MIRROR_DIR}/clients/oc" "${MIRROR_DIR}/clients/openshift-install" "${MIRROR_DIR}/clients/oc-mirror"
find "${OC_MIRROR_WORKDIR}" -type d -name cluster-resources
curl -sk "https://${MIRROR_REGISTRY}/v2/" && echo registry-ok
```

## Next

→ [07 — Bootstrapping MVP DNS and NTP](07-mvp-dns-ntp.md)
