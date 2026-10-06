# Production DNS and NTP manifests (Lab 14)

`*.template` files hold `${KEY}` tokens and are rendered by `scripts/lib/render.py` into
`${INSTALL_DIR}/manifests/` (FR-H4); plain `*.yaml` files are applied as they are.

| File | Applied by | Purpose |
|---|---|---|
| `network/nncp-vmnet-bridge-mapping.yaml` | script 07 | OVN localnet `vmnet` mapped onto `br-ex` (ADR-06) |
| `network/nad-vmnet.yaml` | script 07 | Secondary network the VMs attach to |
| `network/priorityclass-infrastructure-vm.yaml` | script 07 | Dedicated priority for the service VMs |
| `dns-vm/dns-vm.yaml.template` | script 07 (twice: `dns-a`, `dns-b`) | cloud-init Secrets + anti-affine authoritative BIND VM |
| `dns-vm/nncp-dns-cutover.yaml.template` | script 08 | Node resolvers: both DNS VMs, then the bastion |
| `ntp-vm/ntp-vm.yaml.template` | script 08 | cloud-init Secrets + chrony VM |
| `ntp-vm/node-chrony.conf.template` | render.py (embedded) | Node `/etc/chrony.conf` body |
| `ntp-vm/machineconfig-chrony.yaml.template` | script 08 | Node time sources, base64-embedded |

Script 07 also creates two objects from secrets that never touch git: ConfigMap `registry-ca`
(from `${REGISTRY_CA_FILE}`) and Secret `registry-pull` (from `${AUTH_FILE}`), which the CDI
importer uses to pull the digest-pinned guest image from the mirror (FR-H7).
