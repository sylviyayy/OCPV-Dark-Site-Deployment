# 06 — Mirroring Images for a Disconnected Install

> **Grade:** production transfer pattern (two machines, checksummed media, TLS verified end to end).
> A registry co-located on the bastion is a lab simplification, and rules out ever retiring the bastion.
>
> **Nothing here is on a 24-hour clock**: mirror days ahead. Bill of materials and drive checklist:
> [USB Transfer Kit](../USB-TRANSFER-KIT.md).

## Goal

Mirror OpenShift 4.22 and the operators the labs install to disk on the low side, carry the bytes
across on approved media, and load them into the mirror registry — without any high-side host
reaching the internet.

```text
staging host ─oc mirror → file://─► archive ─cp + SHA256SUMS─► media ─sha256sum -c─► bastion
                                                                                      │
                   mirror registry ◄── oc mirror --from file:// → docker:// ──────────┘
```

The cargo crosses; the truck stays outside. No host moves between networks.

> **Decide `STORAGE_BACKEND` first.** It selects which operators are mirrored: `ontap` adds NetApp
> Trident from the certified catalog. Switching later works (re-run 6.1–6.3 and 6.8), but costs a
> second transfer.

## Steps

### 6.1 Clients, auth file, ImageSet (low side)

**WHERE** — Staging host (low side), RHEL 9.x, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Script 01 downloads `openshift-install`, `oc` and `oc-mirror` for exactly `OCP_VERSION`
and checks them against Red Hat's `sha256sum.txt`, so the bytes that cross are the bytes Red Hat
published. It writes `${AUTH_FILE}` (your pull secret) and the ImageSet: one z-stream, the operators
the labs install, and the RHEL guest image **pinned by digest** so a later re-run cannot change it.

**EDIT** — None (`--profile coe` adds the partner CoE operator set).

**DO**

```bash
set -a && source .env && set +a
./scripts/01-mirror-preparation.sh
```

**VERIFY**

```bash
"${MIRROR_DIR}/clients/openshift-install" version | grep -c "${OCP_VERSION}"   # expect: 1
grep -c '@sha256:' "${IMAGESET_CONFIG}"                                         # expect: 1
```

**FAILS IF** — "No sha256sum.txt for 4.22.z" ← A3 is not a published z-stream.

### 6.2 Mirror to disk (low side)

**WHERE** — Staging host, your user, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — Pulls every release and operator image and packs them into `mirror_*.tar` archives, the
only form that can cross removable media. oc-mirror's layer cache is kept in `${MIRROR_DIR}/cache`,
on the disk you sized, not in your home directory.

**EDIT** — None.

**DO** — `./scripts/01-mirror-preparation.sh --mirror-to-disk` (hours; resumable — re-run after an interruption).

**VERIFY** — `ls "${MIRROR_ARCHIVE_DIR}"/mirror_*.tar | wc -l` → 1 or more.

**FAILS IF** — `unauthorized` from `registry.redhat.io` ← pull secret expired or for another account.

### 6.3 Pack the media with checksums (low side)

**WHERE** — Staging host, your user, approved media mounted

**WHY** — The archives are already compressed layers, so they are copied, not re-zipped (hours saved).
`SHA256SUMS` lets the high side prove nothing changed in transit. Disk-to-mirror needs the **same**
ImageSet that produced the archive. Only the SSH **public** key crosses.

**EDIT** — None.

**DO**

```bash
MEDIA=/run/media/${USER}/TRANSFER/ocp-transfer        # your media's mount point
mkdir -p "${MEDIA}"
cp "${MIRROR_ARCHIVE_DIR}"/mirror_*.tar "${MEDIA}/"
cp -r "${MIRROR_DIR}/clients" "${MEDIA}/"
cp "${IMAGESET_CONFIG}" "${MEDIA}/imageset-config.yaml"
cp ~/Downloads/rhel-9.x-x86_64-dvd.iso "${MEDIA}/rhel9-dvd.iso"
tar -C ~ -czf "${MEDIA}/repo.tar.gz" OCPV-Dark-Site-Deployment      # repo + .env (no passwords)
install -m 600 "${PULL_SECRET_FILE}" "${MEDIA}/pull-secret.json"
cp "${SSH_PUBLIC_KEY_FILE}" "${MEDIA}/id_ed25519.pub"
(cd "${MEDIA}" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
```

**VERIFY** — `(cd "${MEDIA}" && sha256sum -c --quiet SHA256SUMS && echo PASS)` → `PASS`.

**FAILS IF** — `File too large` ← FAT32 media; reformat exFAT, ext4 or XFS. The media now carry the pull secret: handle per site policy.

### 6.4 Intake on the high side

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`, media mounted

**WHY** — Re-checking the sums on arrival turns "copied" into "proved". Files land at the same
derived paths the scripts use on both sides. *If skipped:* 6.5 finds no DVD, 6.8 no archive.

**EDIT** — None.

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

(If the repo changed after the bastion ISO was built, unpack `repo.tar.gz` over `~/OCPV-Dark-Site-Deployment`.)

**VERIFY** — `sha256sum -c` reports every file `OK` (AT-04); `./scripts/lib/validate-env.sh` → `PASS`.

**FAILS IF** — Any `FAILED` ← media changed in transit; do not load it, re-copy.

### 6.5 Serve the RHEL 9 DVD as a package repository

**WHERE** — Bastion, `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The bastion has no dnf repository, and the Lab 14 VMs need `bind` and `chrony`, which the
guest image lacks. One loop-mounted ISO serves both: `file://` repos for the bastion and
`http://<BASTION_IP>/rhel9/` for the VMs. *If skipped:* `named` never exists in the DNS VMs.

**EDIT** — None.

**DO** — `sudo ./scripts/04b-serve-dvd-repo.sh`

**VERIFY** — `curl -s -o /dev/null -w '%{http_code}\n' "http://${BASTION_IP}/rhel9/AppStream/repodata/repomd.xml"` → `200`.

**FAILS IF** — `403` ← SELinux label missing on the mount; re-run the script (it sets `context=` in `/etc/fstab`).

### 6.6 Install the mirror registry

**WHERE** — Registry host (the bastion when co-located), `installer` with `sudo`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — mirror registry for Red Hat OpenShift listens on `MIRROR_REGISTRY_PORT` (8443) with a
certificate for `MIRROR_REGISTRY_HOSTNAME`, issued by a CA it generates; script 04 copies that CA —
the real trust anchor — to `${REGISTRY_CA_FILE}`. You choose the registry password at the prompt; it
is never stored. *Consumed by:* 6.7, 6.8, Lab 08 `additionalTrustBundle`.

**EDIT** — None.

**DO** — Separate registry host only — first copy what script 04 needs from the bastion:

```bash
ssh installer@"${MIRROR_REGISTRY_IP}" mkdir -p /opt/ocp-mirror/clients
scp -r "${MIRROR_DIR}/clients/mirror-registry" installer@"${MIRROR_REGISTRY_IP}":/opt/ocp-mirror/clients/
scp "${PULL_SECRET_FILE}" installer@"${MIRROR_REGISTRY_IP}":/opt/ocp-mirror/pull-secret.json
scp "${SSH_PUBLIC_KEY_FILE}" installer@"${MIRROR_REGISTRY_IP}":.ssh/id_ed25519.pub
```

Then, on the registry host: `sudo ./scripts/04-mirror-ocp-images.sh install-registry`

**VERIFY** — On the registry host:

```bash
openssl s_client -connect "${MIRROR_REGISTRY}" -servername "${MIRROR_REGISTRY_HOSTNAME}" \
  -CAfile "${REGISTRY_CA_FILE}" </dev/null 2>/dev/null | grep -c 'Verify return code: 0 (ok)'   # expect: 1
```

**FAILS IF** — `hostname mismatch` ← addressed by IP; always use the hostname (ADR-03).

### 6.7 Trust the registry CA on the bastion

**WHERE** — Bastion, `installer` with `sudo`

**WHY** — `openshift-install agent create image` (Lab 08) and oc-mirror (6.8) pull and push over TLS
**from the bastion**, using its system trust store. Trusting the CA here is what lets every check run
without `-k`, which would train you to ignore exactly the error that matters.

**EDIT** — None.

**DO** — Separate registry: `scp installer@"${MIRROR_REGISTRY_IP}":"${REGISTRY_CA_FILE}" "${REGISTRY_CA_FILE}"`. Then:

```bash
sudo cp "${REGISTRY_CA_FILE}" /etc/pki/ca-trust/source/anchors/ocpv-mirror-registry.crt && sudo update-ca-trust
```

**VERIFY** — `curl -s -o /dev/null -w '%{http_code}\n' "https://${MIRROR_REGISTRY}/v2/"` → `200` or `401`.

**FAILS IF** — `000` ← the name does not resolve (bastion `/etc/hosts` until Lab 07) or the CA is wrong.

### 6.8 Load the archive (disk to mirror)

**WHERE** — Bastion, `installer` (not root), cwd `~/OCPV-Dark-Site-Deployment`, uplink unplugged

**WHY** — `oc mirror --from file://… docker://…` reads only the archive. First the script adds the
registry entry to `${AUTH_FILE}` with `podman login --password-stdin`, which also proves password,
hostname and CA in one step. oc-mirror then writes `${CLUSTER_RESOURCES_DIR}`: the mirror mappings
Lab 08 puts in `install-config.yaml`, and the CatalogSources Lab 12 applies.
*If skipped:* every node stalls at its first image pull in Lab 10.

**EDIT** — None.

**DO** — `./scripts/04-mirror-ocp-images.sh load`

**VERIFY** (AT-05)

```bash
ls "${CLUSTER_RESOURCES_DIR}" | grep -cE '^(idms-oc-mirror|cs-redhat-operator-index.*)\.yaml$'   # expect: 2
jq -e --arg r "${MIRROR_REGISTRY}" '.auths[$r] != null' "${AUTH_FILE}"                           # expect: true
```

**FAILS IF** — oc-mirror tries to reach `registry.redhat.io` ← archive and ImageSet do not match; copy `imageset-config.yaml` from the media again.

Detail: [staging mirror](detail/staging-mirror.md) · [bastion and registry media](detail/bastion-and-registry-usb.md)

## Next

→ [07 — Bootstrapping MVP DNS and NTP](07-mvp-dns-ntp.md)
