# Configure `.env` (field-by-field detail)

> Used from [Lab 03 — Site Checklist](../03-checklist.md). The register there is normative;
> this page says **where each value comes from** and how to check it before `validate-env.sh` does.

## Before you start

```bash
cd ~/OCPV-Dark-Site-Deployment
sudo mkdir -p /opt/ocp-mirror
sudo chown -R "$USER:$USER" /opt/ocp-mirror      # the whole tree, not just the pull secret (FR-B9)
cp .env.example .env
vim .env
```

In `vim`: `i` to insert, `Esc` then `:wq` to save. No spaces around `=`. Quote values that contain
commas (`CP01_NICS="…"`).

## A — Cluster identity

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| A1 | `CLUSTER_NAME` | Your naming standard; becomes `api.<CLUSTER_NAME>.<BASE_DOMAIN>` | `[[ $CLUSTER_NAME =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] && echo ok` |
| A2 | `BASE_DOMAIN` | The DNS owner; a domain the site controls, or `<site>.internal`. Never `.local` (mDNS) and never `example.com` (documentation only) | `echo "$BASE_DOMAIN"` |
| A3 | `OCP_VERSION` | The newest z-stream in `stable-4.22` at mirror time: `https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/` | `curl -sfI https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${OCP_VERSION}/sha256sum.txt` (staging host) |
| A4 | `OCP_CHANNEL` | `stable-` + the minor of A3 | minor matches A3 |

## B — Machine network

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| B1 | `MACHINE_NETWORK_CIDR` | Network team: the subnet holding every node, VIP, bastion, registry and VM | every IP below falls inside it |
| B2 | `NETWORK_GATEWAY` | Network team | inside B1 |
| B3 | `CLUSTER_NETWORK_CIDR`, `SERVICE_NETWORK_CIDR` | Defaults `10.128.0.0/14`, `172.30.0.0/16`; change only if a routed site range overlaps | no overlap with B1, site routes, `100.64.0.0/16`, `100.88.0.0/16` |
| B4 | `MTU` | Network team: the switch MTU on the machine network, end to end | same value on both switches' port-channels |
| B5 | `API_VIP` | Network team: one unused address in B1 | `ping -c1 -W1 $API_VIP` gets **no** reply before install |
| B6 | `INGRESS_VIP` | Network team: a second unused address | same; differs from B5 |

## C — Control-plane nodes

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| C1 | `CP01_HOSTNAME` … | Short names (`cp01`…); the README role table uses the same names | no dots |
| C2 | `CP01_IP` … | Network team, inside B1 | unique |
| C3 | `CP01_NICS` … | XCC → Inventory → Network adapters gives MACs per port; Lab 05 step 5.4 confirms names and MACs in a RHEL 9 rescue shell (`ip -br link`) | exactly 4 `name=MAC` pairs; real MACs |
| C4 | `CP01_ROOT_DEVICE` … | Lab 05 step 5.4: `ls -l /dev/disk/by-path/` → the link to the RAID1 virtual disk | starts with `/dev/disk/by-path/` |
| C5 | `CP01_BMC_IP` … | Hardware team: XCC addresses on the management network | reachable from the admin workstation |
| C6 | `RENDEZVOUS_IP` | Leave `${CP01_IP}` unless `cp01` is unavailable | equals one C2 value |

## D — Bastion and mirror registry

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| D1 | `BASTION_HOSTNAME`, `BASTION_IP` | Infrastructure team | IP inside B1 |
| D2 | `BASTION_IFNAME` | The bastion's cabled NIC as RHEL 9 names it: XCC inventory, or `ip -br link` from a rescue shell | not a VMware-style name on bare metal |
| D3 | `MIRROR_REGISTRY_HOSTNAME` | Leave `registry.${BASE_DOMAIN}` unless policy says otherwise | under `BASE_DOMAIN` |
| D4 | `MIRROR_REGISTRY_PORT` | `8443` (mirror-registry default) unless site policy mandates `443` | firewall plan agrees |
| D5 | `MIRROR_REGISTRY_IP` | The registry host, or `BASTION_IP` when co-located | inside B1 |
| D6 | `MIRROR_REGISTRY_USER` | Leave `init`; the password is chosen at Lab 06 step 6.6 and never stored here | — |

## E — Site services

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| E1 | `TIME_SOURCE` | Security/site team: the IP of a reference clock (GPS/PTP-disciplined NTP), or `orphan` for a lab | `chronyd -Q "server $TIME_SOURCE iburst"` from the bastion later |
| E2 | `DNS_VM_IPS` | Network team: two unused addresses in B1 | two values, comma-separated |
| E3 | `NTP_VM_IP` | Network team: one unused address in B1 | unique |
| E4 | `VM_NETWORK_MODEL` | Leave `localnet` (ADR-06) | — |
| E5 | `STORAGE_BACKEND` | `hpp` unless every node has an empty data disk (then `lvms`, ADR-05) | — |

## F — Files and directories

| ID | Key | Where the value comes from | Check it yourself |
|---|---|---|---|
| F1 | `PULL_SECRET_FILE` | `console.redhat.com/openshift/install/pull-secret`, saved outside the repo | `jq -e '.auths' "$PULL_SECRET_FILE"` |
| F2 | `SSH_PUBLIC_KEY_FILE` | `ssh-keygen -t ed25519` on the staging host; only the `.pub` crosses the air gap | file exists |
| F3 | `MIRROR_DIR` | Leave `/opt/ocp-mirror` | `test -O /opt/ocp-mirror && echo owned` |
| F4 | `INSTALL_DIR` | Leave `${HOME}/ocp-install/${CLUSTER_NAME}` | not inside the repo |

## Verify

```bash
./scripts/lib/validate-env.sh      # expect: validate-env: PASS — .env satisfies every field-register rule
```

Each failure names its field ID and key, for example
`[FAIL] C3 CP01_NICS: still holds the sample MAC 00:00:00:00:00:00`.

## Next

→ [Lab 03 — Site Checklist](../03-checklist.md) · [Lab 04 — Setting up the Bastion](../04-bastion.md)
