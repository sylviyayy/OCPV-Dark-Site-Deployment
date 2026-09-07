# Mirror configuration (oc-mirror plugin v2)

Templates and output for disconnected image mirroring on OpenShift **4.22**.

| File | Purpose |
|---|---|
| `imageset-config.yaml.template` | ImageSetConfiguration (`mirror.openshift.io/v2alpha1`) |

## Official documentation

- [About oc-mirror plugin v2](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/about-installing-oc-mirror-v2)
- [Creating a mirror registry](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/index) (Chapter 4)

## Workflow

```bash
# Connected staging host
./scripts/01-mirror-preparation.sh --mirror-to-disk

# Dark site — load into registry
./scripts/04-mirror-ocp-images.sh disk-to-mirror
```

Output lands in `${OC_MIRROR_WORKDIR}/cluster-resources/` for use during install.
