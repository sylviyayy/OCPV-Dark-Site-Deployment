# Mirror configuration (oc-mirror plugin v2)

| File | Purpose |
|---|---|
| `imageset-config.yaml.template` | ImageSetConfiguration skeleton (`mirror.openshift.io/v2alpha1`), loaded as data |
| `imageset-profiles.yaml` | Operator sets: `default` (always), `lvms` (when `STORAGE_BACKEND=lvms`), `coe` (optional) |

`scripts/01-mirror-preparation.sh` renders `${IMAGESET_CONFIG}` from both files and `.env`:
one exact z-stream, the operators every lab installs, and the RHEL guest image pinned by
digest (resolved once with `skopeo`; no floating tag reaches the ImageSet).

## Flow (ADR-02: two machines, media in between)

```bash
# Low side — connected RHEL 9 staging host
./scripts/01-mirror-preparation.sh --mirror-to-disk            # add --profile coe for the CoE set
#   oc mirror -c ${IMAGESET_CONFIG} file://${MIRROR_ARCHIVE_DIR} --v2 --authfile ${AUTH_FILE}

# Approved removable media + SHA256SUMS (Lab 06 step 6.3)

# High side — bastion, uplink physically absent
sudo ./scripts/04-mirror-ocp-images.sh install-registry
./scripts/04-mirror-ocp-images.sh load
#   oc mirror -c ${IMAGESET_CONFIG} --from file://${MIRROR_ARCHIVE_DIR} docker://${MIRROR_REGISTRY} --v2 --authfile ${AUTH_FILE}
```

Disk-to-mirror writes `${CLUSTER_RESOURCES_DIR}` (`idms-oc-mirror.yaml`, `itms-oc-mirror.yaml`,
`cs-redhat-operator-index-v4-22.yaml`, …): Lab 08 reads the IDMS, Lab 12 applies the folder.

## Official documentation

- [About oc-mirror plugin v2](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2)
- [Disconnected environments (4.22)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index)
