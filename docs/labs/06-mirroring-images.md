# 06 — Mirroring Images for a Disconnected Install

> **Grade:** production-grade transfer pattern (two machines, checksummed media, TLS verified
> end to end). Co-locating the registry on the bastion is a lab simplification.

## Goal

Mirror OpenShift 4.22 and the operators the labs install to disk on the low side, carry the
bytes across the air gap on approved media, and load them into the mirror registry on the high
side — with no high-side host ever reaching the internet.

## The route the bytes take

```text
staging host ──oc mirror file://──► archive ──cp + SHA256SUMS──► media ──sha256sum -c──► bastion
                                                                                           │
                         mirror registry ◄──oc mirror --from file:// docker://────────────┘
```

No host is moved between networks (FR-B8). The cargo crosses; the truck stays outside.

## Steps

### 6.1 Clients, auth file and ImageSet (low side)

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 01 downloads `openshift-install`, `oc` and `oc-mirror` for exactly `OCP_VERSION`
and proves them against Red Hat's published `sha256sum.txt`, so the bytes that cross the air gap are
the bytes Red Hat published. It writes `${AUTH_FILE}` (your pull secret) for oc-mirror and renders
`${IMAGESET_CONFIG}` with the RHEL guest image pinned by digest. Consumed by: 6.2, and on the high
side by Labs 08–14. If skipped: 6.2 has no client, no credentials and no ImageSet.

**EDIT** — No edits in this step. (Optional operator set: add `--profile coe`.)

**DO**

```bash
set -a && source .env && set +a
./scripts/01-mirror-preparation.sh
```

**VERIFY**

```bash
"${MIRROR_DIR}/clients/openshift-install" version | grep -c "${OCP_VERSION}"   # expect: 1
grep -c '@sha256:' "${IMAGESET_CONFIG}"                                         # expect: 1
grep -c ':latest' "${IMAGESET_CONFIG}"                                          # expect: 0
```

**FAILS IF** — "No sha256sum.txt for 4.22.z" ← A3 is not a published z-stream; pick one from
`https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/`.

### 6.2 Mirror to disk (low side)

**WHERE** — Staging host (low side), RHEL 9.x, as your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — `oc mirror -c <isc> file://<dir> --v2` pulls the release and operator images and packs
them into `mirror_*.tar` archives, the only form that can cross removable media. Consumed by: 6.3,
then 6.8. If skipped: there is nothing to carry.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/01-mirror-preparation.sh --mirror-to-disk
```

**VERIFY**

```bash
ls "${MIRROR_ARCHIVE_DIR}"/mirror_*.tar | wc -l      # expect: 1 or more
```

**FAILS IF** — `unauthorized` from `registry.redhat.io` ← the pull secret is expired or for another account.

### 6.3 Pack the approved media with checksums (low side)

**WHERE** — Staging host (low side), RHEL 9.x, as your user, approved media mounted

**WHY** — oc-mirror archives are already tarballs of compressed layers, so re-compressing the
whole mirror directory costs hours for almost no saving; copying is enough. `SHA256SUMS` lets the
high side prove nothing changed in transit. Disk-to-mirror needs the **same** ImageSet file that
produced the archive (FR-B7). Consumed by: 6.4. If skipped: a corrupted archive surfaces as a
half-loaded registry in 6.8, hours later.

**EDIT** — No edits in this step.

**DO**

```bash
MEDIA=/run/media/${USER}/TRANSFER/ocp-transfer        # your approved media's mount point
mkdir -p "${MEDIA}"
cp "${MIRROR_ARCHIVE_DIR}"/mirror_*.tar "${MEDIA}/"
cp -r "${MIRROR_DIR}/clients" "${MEDIA}/"
cp "${IMAGESET_CONFIG}" "${MEDIA}/imageset-config.yaml"
cp ~/Downloads/rhel-9.x-x86_64-dvd.iso "${MEDIA}/rhel9-dvd.iso"
tar -C ~ -czf "${MEDIA}/repo.tar.gz" OCPV-Dark-Site-Deployment     # repo + .env (no secrets)
install -m 600 "${PULL_SECRET_FILE}" "${MEDIA}/pull-secret.json"
cp "${SSH_PUBLIC_KEY_FILE}" "${MEDIA}/id_ed25519.pub"              # public key only
(cd "${MEDIA}" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
```

The media now carries the pull secret: handle and wipe it per site policy.

**VERIFY**

```bash
(cd "${MEDIA}" && sha256sum -c --quiet SHA256SUMS && echo PASS)   # expect: PASS
```

**FAILS IF** — `File too large` ← the media is FAT32; reformat as exFAT, ext4 or XFS.

### 6.4 Intake on the high side

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`, media mounted

**WHY** — Re-checking the sums on the receiving side is what turns "copied" into "proved". The
files land at the same derived paths the scripts use on both sides. Consumed by: 6.5–6.8 and
`validate-env` (F1, F2). If skipped: 6.5 finds no DVD and 6.8 finds no archive.

**EDIT** — No edits in this step.

**DO**

```bash
set -a && source .env && set +a
MEDIA=/run/media/${USER}/TRANSFER/ocp-transfer
(cd "${MEDIA}" && sha256sum -c SHA256SUMS)
mkdir -p "${MIRROR_ARCHIVE_DIR}"
cp "${MEDIA}"/mirror_*.tar "${MIRROR_ARCHIVE_DIR}/"
cp -r "${MEDIA}/clients" "${MIRROR_DIR}/"
cp "${MEDIA}/imageset-config.yaml" "${IMAGESET_CONFIG}"
cp "${MEDIA}/rhel9-dvd.iso" "${MIRROR_DIR}/rhel9-dvd.iso"
install -m 600 "${MEDIA}/pull-secret.json" "${PULL_SECRET_FILE}"
install -D -m 644 "${MEDIA}/id_ed25519.pub" "${SSH_PUBLIC_KEY_FILE}"
```

If you changed the repo after building the bastion ISO, also unpack `repo.tar.gz` over
`~/OCPV-Dark-Site-Deployment`.

**VERIFY**

```bash
(cd "${MEDIA}" && sha256sum -c --quiet SHA256SUMS && echo PASS)   # expect: PASS (AT-04)
./scripts/lib/validate-env.sh                                     # expect: validate-env: PASS
```

**FAILS IF** — `FAILED` against a file ← the media changed in transit; do not load it, re-copy from the low side.

### 6.5 Serve the RHEL 9 DVD repository

**WHERE** — Bastion, RHEL 9.x, as `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The bastion was installed offline and has no dnf repository; the DNS and NTP VMs in
Lab 14 need `bind` and `chrony`, which the guest image lacks, and a dark site has no CDN. One
loop-mounted ISO serves both: `file://` repos for the bastion, `http://${BASTION_IP}/rhel9/` for the
VMs (FR-H3). Consumed by: Lab 14 cloud-init `yum_repos`. If skipped: `named` never exists in the DNS VMs.

**EDIT** — No edits in this step.

**DO**

```bash
sudo ./scripts/04b-serve-dvd-repo.sh
```

**VERIFY**

```bash
curl -s -o /dev/null -w '%{http_code}\n' "http://${BASTION_IP}/rhel9/AppStream/repodata/repomd.xml"   # expect: 200
```

**FAILS IF** — `403` ← SELinux label missing on the mount; re-run the script (it sets `context=` in `/etc/fstab`).

### 6.6 Install the mirror registry

**WHERE** — Registry host (`MIRROR_REGISTRY_IP`; the bastion in a co-located lab), RHEL 9.x, as `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — mirror registry for Red Hat OpenShift listens on `MIRROR_REGISTRY_PORT` (8443 by default)
with a certificate whose SAN is `MIRROR_REGISTRY_HOSTNAME`, issued by a CA it generates. Script 04
copies that CA — the real trust anchor, not a scraped leaf certificate — to `${REGISTRY_CA_FILE}`
(FR-C3). You choose the registry password at the prompt; it is never stored in `.env`.
Consumed by: 6.7, 6.8, `additionalTrustBundle` in Lab 08. If skipped: there is no registry.

**EDIT** — No edits in this step.

**DO** — If the registry host is **separate**, first copy what script 04 needs onto it from the bastion:

```bash
ssh installer@"${MIRROR_REGISTRY_IP}" mkdir -p /opt/ocp-mirror/clients
scp -r "${MIRROR_DIR}/clients/mirror-registry" installer@"${MIRROR_REGISTRY_IP}":/opt/ocp-mirror/clients/
scp "${PULL_SECRET_FILE}" installer@"${MIRROR_REGISTRY_IP}":/opt/ocp-mirror/pull-secret.json
scp "${SSH_PUBLIC_KEY_FILE}" installer@"${MIRROR_REGISTRY_IP}":.ssh/id_ed25519.pub
```

Then, on the registry host:

```bash
sudo ./scripts/04-mirror-ocp-images.sh install-registry
```

**VERIFY** — On the registry host:

```bash
openssl s_client -connect "${MIRROR_REGISTRY}" -servername "${MIRROR_REGISTRY_HOSTNAME}" \
  -CAfile "${REGISTRY_CA_FILE}" </dev/null 2>/dev/null | grep -c 'Verify return code: 0 (ok)'   # expect: 1
```

**FAILS IF** — `Verify return code: 62 (hostname mismatch)` ← you addressed the registry by IP; use the hostname (ADR-03).

### 6.7 Trust the registry CA on the bastion

**WHERE** — Bastion, RHEL 9.x, as `installer` with `sudo`

**WHY** — `openshift-install agent create image` (Lab 08) pulls the release payload from the mirror
over TLS **from the bastion itself**, and oc-mirror pushes over TLS in 6.8; both use the system trust
store. Trusting the CA here is what lets every check in these labs run without `-k`, which would train
you to ignore exactly the error that matters (FR-C4). Consumed by: 6.8, Lab 08. If skipped:
`x509: certificate signed by unknown authority` in 6.8.

**EDIT** — No edits in this step.

**DO** — If the registry is separate, first fetch its CA:
`scp installer@"${MIRROR_REGISTRY_IP}":"${REGISTRY_CA_FILE}" "${REGISTRY_CA_FILE}"`. Then:

```bash
sudo cp "${REGISTRY_CA_FILE}" /etc/pki/ca-trust/source/anchors/ocpv-mirror-registry.crt
sudo update-ca-trust
```

**VERIFY**

```bash
curl -s -o /dev/null -w '%{http_code}\n' "https://${MIRROR_REGISTRY}/v2/"     # expect: 200 or 401
```

**FAILS IF** — `000` ← DNS for `MIRROR_REGISTRY_HOSTNAME` (bastion `/etc/hosts` until Lab 07) or the CA is wrong.

### 6.8 Load the archive into the registry (disk to mirror)

**WHERE** — Bastion, RHEL 9.x, as `installer` (not root), cwd `~/OCPV-Dark-Site-Deployment`, uplink physically absent

**WHY** — `oc mirror --from file://… docker://<registry>` reads only the archive; the older
`--workspace` form told oc-mirror to pull from Red Hat registries the dark site cannot reach (FR-B5).
The script first adds the registry entry to `${AUTH_FILE}` with `podman login --password-stdin`,
which also proves the password, the hostname and the CA in one step (FR-B3). oc-mirror then writes
`${CLUSTER_RESOURCES_DIR}`: the IDMS Lab 08 renders into `install-config.yaml`, and the
CatalogSource Lab 12 applies. Consumed by: Labs 08, 12, 13, 14. If skipped: every node stalls at
its first image pull in Lab 10.

**EDIT** — No edits in this step.

**DO**

```bash
./scripts/04-mirror-ocp-images.sh load
```

**VERIFY** (AT-05: run with the bastion's uplink unplugged)

```bash
ls "${CLUSTER_RESOURCES_DIR}" | grep -cE '^(idms-oc-mirror|cs-redhat-operator-index.*)\.yaml$'   # expect: 2
jq -e --arg r "${MIRROR_REGISTRY}" '.auths[$r] != null' "${AUTH_FILE}"                           # expect: true
```

**FAILS IF** — oc-mirror tries to reach `registry.redhat.io` ← the archive and the ImageSet do not
match; copy the exact `imageset-config.yaml` from the media again.

Detail: [staging mirror](detail/staging-mirror.md) · [bastion and registry media](detail/bastion-and-registry-usb.md)

## Next

→ [07 — Bootstrapping MVP DNS and NTP](07-mvp-dns-ntp.md)
