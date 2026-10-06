# Staging mirror (detail)

> Canonical lab: [06 — Mirroring Images](../06-mirroring-images.md). This page explains what
> `scripts/01-mirror-preparation.sh` does and how the transfer media are assembled.

## What script 01 does, in order

| Step | Mechanism | Fails loudly when |
|---|---|---|
| Tools | requires only `curl jq tar sha256sum skopeo python3`; `oc` is checked **after** it is downloaded (FR-B2) | a base tool is missing |
| Clients | reads `sha256sum.txt` for `OCP_VERSION`, picks the RHEL 9 installer, client and oc-mirror builds by pattern, downloads them and runs `sha256sum -c` (FR-B1) | the z-stream is not published, a pattern matches 0 or 2+ files, or a checksum differs |
| mirror-registry | downloads the archive the high side installs (FR-C2) | the download fails; the message names the console download page |
| Auth file | `${AUTH_FILE}` = your pull secret, mode 600; passed to every `oc mirror` with `--authfile` (FR-B3). The registry entry is added on the high side, so the registry password never crosses the air gap | the pull secret is missing or not JSON |
| ImageSet | `${IMAGESET_CONFIG}` from `mirror/imageset-config.yaml.template` + `mirror/imageset-profiles.yaml`: one exact z-stream, the operators every lab installs, the RHEL guest image pinned by digest (FR-B6) | an unknown profile, or a floating tag |
| `--mirror-to-disk` | `oc mirror -c ${IMAGESET_CONFIG} file://${MIRROR_ARCHIVE_DIR} --v2 --authfile ${AUTH_FILE}` (FR-B4) | no `mirror_*.tar` is produced |

The guest image digest is resolved once and reused on every re-run, so the image cannot silently
change after it was mirrored. Delete `${IMAGESET_CONFIG}` to re-resolve on purpose.

## What crosses the air gap

| Item | Why the high side needs it |
|---|---|
| `mirror_*.tar` | the images; disk-to-mirror reads only these |
| `clients/` | `openshift-install`, `oc`, `oc-mirror`, `mirror-registry` |
| `imageset-config.yaml` | disk-to-mirror needs the exact ImageSet that produced the archive |
| `rhel9-dvd.iso` | the bastion's dnf repo and the DNS/NTP VMs' package source (Lab 06 step 6.5) |
| `repo.tar.gz` | this repository with your `.env` (no passwords in it) |
| `pull-secret.json` | part of the cluster `pullSecret`; a secret, handle per site policy |
| `id_ed25519.pub` | public key only; the private key stays with the operator |
| `SHA256SUMS` | proof that every byte above arrived unchanged |

oc-mirror archives are already tarballs of compressed layers: re-compressing them with gzip costs
hours for almost no saving, so the media carry plain copies (FR-B7). Use exFAT, ext4 or XFS: FAT32
cannot hold a file larger than 4 GiB.

## Next

→ [Lab 06](../06-mirroring-images.md)
