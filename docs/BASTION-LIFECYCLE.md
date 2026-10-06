# Bastion Lifecycle: USB → Temporary DNS/NTP → Install → Permanent DNS/NTP → Disconnect

This page is the end-to-end runbook for the operating model this repo assumes:

1. A **USB drive** carries every artifact across the air gap and is plugged into the **bastion**.
2. The bastion starts **temporary DNS and NTP** and deploys the cluster.
3. Permanent DNS and NTP servers come up. During a cutover window the bastion serves as
   their **secondary** (make-before-break).
4. The bastion is **disconnected**. Permanent DNS/NTP servers that are not the bastion,
   plus a permanent mirror registry, carry the site from then on.

It also marks exactly **where the 24-hour limit applies**. Steps that must happen
inside a window are labelled **[WINDOW A]** or **[WINDOW B]**.

**What to put on the USB drive:** [USB Transfer Kit](USB-TRANSFER-KIT.md).

---

## 1. Roles over time

Analogy: the bastion is **scaffolding**. It goes up before the building, carries load
while the building can't carry itself, then comes down. Take it down too early and
something falls; leave it up forever and it becomes a load-bearing liability.

| Phase | Name | Bastion's role | Nodes' DNS | Nodes' NTP | Clock running? |
|---|---|---|---|---|---|
| 0 | Connected staging | Not on site (the staging host does the work) | n/a | n/a | No |
| 1 | Arrival: build helper hosts | Being installed from USB | n/a | n/a | No |
| 2 | Temporary services | **Sole** DNS and NTP authority for the site | n/a | n/a | No |
| 3 | Registry | Time source for the registry host. Pushes images | n/a | n/a | No |
| 4 | Compose and validate | Configuration workstation | n/a | n/a | No |
| 5 | **T-0**: install | Installer and sole DNS/NTP | Bastion | Bastion | **[WINDOW A]** |
| 6 | Post-install soak | Sole DNS/NTP | Bastion | Bastion | **[WINDOW B]** |
| 7 | Make-before-break | **Secondary** DNS/NTP | Permanent, then bastion | Permanent (`prefer`), then bastion | No |
| 8 | Break and disconnect | Drained, emptied, removed | Permanent only | Permanent only | No |

**Hard constraints** (the design fails without them):

- **The mirror registry is not on the bastion** (`MIRROR_REGISTRY_IP ≠ BASTION_IP`). The
  cluster pulls images from the registry for its whole life.
- **The bastion is not disconnected inside Window B** (the first 24 hours after install).
- **The bastion is removed from node configuration before it is unplugged.** Unplugging
  it first is break-before-make, and it causes a site-wide DNS/NTP outage if the
  permanent servers are unhealthy.

---

## 2. The two 24-hour windows, and what is not on a clock

### What is **not** on a clock

Nothing you download, and nothing on the USB drive, expires in 24 hours:

- CLI tools (`oc`, `openshift-install`, `oc-mirror`, `mirror-registry`, `butane`)
- The pull secret
- The mirror archive (release, RHCOS, operators, guest images)
- The RHEL DVD ISO

**Download them days ahead.** Mirror-to-disk alone can take hours. Give yourself time to
verify checksums and make a second copy.

### Window A: the agent ISO's shelf life

| | |
|---|---|
| **Starts** | **T-0**, the moment `openshift-install agent create image` runs |
| **Hard limit** | 24 hours. The installer-generated Ignition configs embedded in the ISO contain certificates that expire after 24 hours |
| **Red Hat recommendation** | Boot the nodes **within 12 hours**. The first 24-hour certificate rotation runs 16–22 hours after install, and starting within 12 hours keeps that rotation from overlapping the install |
| **Analogy** | A `kubeadm join` bootstrap token, whose default time-to-live (TTL) is also 24 hours. It is a short-lived credential that is meant to be used right away, not stockpiled |

**Consequence:** build the ISO **at the dark site, on the bastion**, as the last step
before booting the nodes. Do not build it on the connected side. If you do, transport,
helper-host builds and registry loading all consume a window that was only ever meant
to cover booting.

### Window B: the first certificate rotation

| | |
|---|---|
| **Starts** | When the installation starts (nodes boot the ISO) |
| **Lasts** | About 24 hours. The short-lived certificates rotate 16–22 hours after install |
| **Rule** | Keep the cluster **powered on** and its DNS/NTP (the bastion) **unchanged** until the rotation has completed. Do **not** start the cutover or disconnect the bastion inside this window |
| **If you must power off anyway** | When the cluster comes back after the 24 hours have elapsed, it recovers the expired certificates itself, **except** kubelet certificates. Approve the pending `node-bootstrapper` CSRs by hand (Phase 6, step 1) |

---

## 3. Runbook

Conventions follow the repo: **WHERE / WHY / DO / VERIFY / FAILS IF**. The values
(`10.10.0.5`, `ocp-v.local`, ...) are the `.env.example` defaults. Substitute your own.

### Phase 0: Connected staging (T-minus days)

**WHERE:** Staging host with internet.
**WHY:** This is the only phase with a supply line.
**DO:** Follow [USB Transfer Kit](USB-TRANSFER-KIT.md) end to end, including the storage
decision gate and the pre-departure checklist.
**VERIFY:** `SHA256SUMS` verifies on the data drive **and** its backup.
**FAILS IF:** An operator, tool or the RHEL DVD is missing. That costs a return trip.

### Phase 1: Arrival: install the bastion and registry host (no clock)

**WHERE:** Bastion and registry host consoles.
**WHY:** Both helper hosts must exist before any service does.

**DO:**

1. Boot the bastion from Drive A (RHEL DVD) with Drive B (data) attached. At the boot
   prompt, enter:

   ```text
   inst.ks=hd:LABEL=OCPV-DATA:/kickstart/ks-bastion.cfg
   ```

2. Boot the registry host the same way with `ks-registry-mirror.cfg`.
3. On the bastion, verify the drive, then copy it to local disk. That way a pulled USB
   drive can't interrupt a multi-hour push:

   ```bash
   sudo mkdir -p /mnt/ocpv-data && sudo mount LABEL=OCPV-DATA /mnt/ocpv-data
   (cd /mnt/ocpv-data && sha256sum -c --quiet SHA256SUMS) && echo "transport OK"

   sudo mkdir -p /opt/ocp-mirror/clients && sudo chown -R installer: /opt/ocp-mirror
   rsync -a /mnt/ocpv-data/mirror/oc-mirror-workdir/ /opt/ocp-mirror/oc-mirror-workdir/
   cp /mnt/ocpv-data/mirror/imageset-config.yaml /opt/ocp-mirror/
   install -m 0600 /mnt/ocpv-data/secrets/pull-secret.json /opt/ocp-mirror/pull-secret.json
   for t in openshift-client-linux openshift-install-linux oc-mirror; do
     tar -xzf "/mnt/ocpv-data/tools/${t}.tar.gz" -C /opt/ocp-mirror/clients
   done
   chmod +x /opt/ocp-mirror/clients/oc-mirror
   install -m 0755 /mnt/ocpv-data/tools/butane-amd64 /opt/ocp-mirror/clients/butane
   export PATH="/opt/ocp-mirror/clients:${PATH}"
   ```

4. Make the RHEL DVD a local `dnf` repository on the bastion:

   ```bash
   sudo mkdir -p /mnt/rhel9
   sudo mount -o loop,ro /mnt/ocpv-data/media/rhel-9.*-x86_64-dvd.iso /mnt/rhel9
   sudo tee /etc/yum.repos.d/rhel9-dvd.repo >/dev/null <<'EOF'
   [rhel9-dvd-baseos]
   name=RHEL 9 DVD BaseOS
   baseurl=file:///mnt/rhel9/BaseOS
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
   [rhel9-dvd-appstream]
   name=RHEL 9 DVD AppStream
   baseurl=file:///mnt/rhel9/AppStream
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
   EOF
   ```

**VERIFY:**

```bash
command -v oc openshift-install oc-mirror butane nmstatectl
oc version --client && openshift-install version
```

**FAILS IF:** `nmstatectl` is missing. ISO creation in Phase 5 fails. Install it with
`sudo dnf install -y nmstate` from the DVD repository.

### Phase 2: The bastion becomes the sole DNS and NTP authority (no clock)

**WHERE:** Bastion.
**WHY:** Nothing on site resolves names or keeps time yet. The bastion's clock becomes
the site's **time authority**, because chronyd serves its local clock with no upstream.
So set it correctly **before** it starts serving time.

**DO:**

```bash
cd ~/OCPV-Dark-Site-Deployment
date -u                                                         # is it right?
sudo ./scripts/02-bootstrap-dns-ntp.sh --set-time 'YYYY-MM-DD HH:MM:SS'   # UTC, from a trusted reference
# (omit --set-time if the clock is already correct)
```

The script refuses to run if `BASTION_IP` isn't on this host or port 53 is taken. It
writes dnsmasq and chrony configs from `.env`, opens the firewall, restarts both
services, and verifies them. Details are in [Lab 07](labs/07-mvp-dns-ntp.md).

During install the nodes list **only** the bastion: `dns-resolver` and
`additionalNTPSources` in `agent-config.yaml`. Don't pre-list the permanent servers. A
dead first nameserver adds a timeout to every lookup, and a half-built one answers
NXDOMAIN, which resolvers do not fall back from. See
[Lab 07, "Primary or secondary?"](labs/07-mvp-dns-ntp.md#primary-or-secondary-the-nodes-decide-not-the-bastion).

Also set every node's **BMC/UEFI clock to UTC**, within a minute of the bastion.
Certificates generated at T-0 carry the bastion's timestamp. A node whose clock lags
behind it sees them as "not yet valid" until it synchronizes.

**VERIFY:** `sudo ./scripts/02-bootstrap-dns-ntp.sh --verify`. Every line must say `[PASS]`.

### Phase 3: Permanent mirror registry (no clock)

**WHERE:** Registry host, plus the bastion for the push.
**WHY:** The registry outlives the bastion. Its TLS certificate is generated at install
time, so the registry host must already follow the bastion's clock.

**DO:**

1. On the registry host, confirm it follows the bastion's clock:

   ```bash
   chronyc tracking | grep 'Reference ID'           # must show the bastion's IP
   ```

2. Copy the mirror registry tarball and RHEL DVD from the bastion:

   ```bash
   # on the bastion
   scp /mnt/ocpv-data/tools/mirror-registry-amd64.tar.gz \
       /mnt/ocpv-data/media/rhel-9.*-x86_64-dvd.iso installer@10.10.0.10:/tmp/
   ```

3. Install the mirror registry on the registry host. Its default port is **8443**:

   ```bash
   sudo mkdir -p /opt/mirror-registry
   sudo tar -xzf /tmp/mirror-registry-amd64.tar.gz -C /opt/mirror-registry
   cd /opt/mirror-registry
   sudo ./mirror-registry install \
     --quayHostname registry.ocp-v.local:8443 \
     --quayRoot /opt/registry \
     --initUser init --initPassword '<MIRROR_REGISTRY_PASSWORD from .env>'
   sudo firewall-cmd --permanent --add-port=8443/tcp && sudo firewall-cmd --reload
   ```

4. Serve the RHEL DVD over HTTP from the registry host. The permanent DNS VM needs it in
   Phase 6, because BIND is not in the RHEL guest image:

   ```bash
   sudo mkdir -p /opt/media /var/www/html/rhel9
   sudo mv /tmp/rhel-9.*-x86_64-dvd.iso /opt/media/
   echo "$(ls /opt/media/rhel-9.*-x86_64-dvd.iso) /var/www/html/rhel9 iso9660 loop,ro,context=system_u:object_r:httpd_sys_content_t:s0 0 0" \
     | sudo tee -a /etc/fstab
   sudo systemctl daemon-reload && sudo mount /var/www/html/rhel9
   sudo systemctl enable --now httpd
   ```

5. On the bastion, trust the registry CA, log in, and push the archive (disk-to-mirror):

   ```bash
   scp installer@10.10.0.10:/opt/registry/quay-rootCA/rootCA.pem /opt/ocp-mirror/registry-ca.crt
   sudo cp /opt/ocp-mirror/registry-ca.crt /etc/pki/ca-trust/source/anchors/ && sudo update-ca-trust
   podman login registry.ocp-v.local:8443

   oc mirror -c /opt/ocp-mirror/imageset-config.yaml \
     --from file:///opt/ocp-mirror/oc-mirror-workdir \
     docker://registry.ocp-v.local:8443 --v2
   find /opt/ocp-mirror/oc-mirror-workdir -type d -name cluster-resources
   ```

**VERIFY:**

```bash
curl -s https://registry.ocp-v.local:8443/health/instance          # registry healthy
curl -sI http://10.10.0.10/rhel9/BaseOS/repodata/repomd.xml | head -1
# The release image must be resolvable from the mirror. This is the same call
# openshift-install makes to extract the RHCOS base ISO.
# Take the exact repository path from the generated idms-oc-mirror.yaml.
oc adm release info registry.ocp-v.local:8443/openshift/release-images:4.22.2-x86_64 | head -5
```

**FAILS IF:**

- The registry certificate was minted before the time sync. Nodes then report
  `certificate is not yet valid`.
- The archive was never pushed. You get mass `ImagePullBackOff`, and ISO creation hangs
  in Phase 5.

### Phase 4: Compose and validate the install configuration (no clock)

**WHERE:** Bastion.
**WHY:** Every mistake you catch here costs minutes. The same mistake caught after T-0
costs part of Window A.

**DO:**

```bash
./scripts/03-generate-install-config.sh
vim install-config/install-config.yaml
vim install-config/agent-config.yaml
```

In `install-config.yaml`, confirm:

- `pullSecret` contains the **mirror registry's** credentials. `podman login` wrote them
  to `${XDG_RUNTIME_DIR}/containers/auth.json`, so use `jq -c . <that file>`.
- `additionalTrustBundle` is `/opt/ocp-mirror/registry-ca.crt` (the mirror registry
  root CA).
- `imageDigestSources` exists. Copy the `mirrors`/`source` pairs from the generated
  `idms-oc-mirror.yaml`. Don't type them by hand. A typical result looks like this:

  ```yaml
  imageDigestSources:
    - mirrors: [registry.ocp-v.local:8443/openshift/release]
      source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
    - mirrors: [registry.ocp-v.local:8443/openshift/release-images]
      source: quay.io/openshift-release-dev/ocp-release
  ```

In `agent-config.yaml`, confirm:

- Real MACs and IPs (not the `00:50:56:…` samples), and `rendezvousIP` is one
  control-plane IP.
- `additionalNTPSources` lists the bastion. Without it, nodes use RHCOS's default
  internet pools during install, which are unreachable here.

Back up the two files. `openshift-install` **consumes** (deletes) them from `--dir`, and
you need them to regenerate the ISO if Window A lapses. Then validate in a disposable
copy:

```bash
mkdir -p ~/config-backup
cp install-config/install-config.yaml install-config/agent-config.yaml ~/config-backup/

rm -rf /tmp/abi-validate && mkdir /tmp/abi-validate && cp ~/config-backup/*.yaml /tmp/abi-validate/
openshift-install agent create cluster-manifests --dir /tmp/abi-validate --log-level info
```

`agent create cluster-manifests` writes manifests only: no Ignition, no certificates.
It does **not** start the clock.

**GO / NO-GO GATE.** Do not proceed to T-0 until every box is ticked:

- [ ] `dig @<BASTION_IP>` resolves `api`, `api-int`, `test.apps`, `registry` and every node correctly
- [ ] The bastion and registry host report a synchronized clock. Node BMC clocks are set to UTC
- [ ] `oc adm release info` against the mirror succeeds (Phase 3 VERIFY)
- [ ] `cluster-manifests` validation passed. Configs are backed up
- [ ] BMC virtual media has been tested on **every** node
- [ ] **You have at least 12 uninterrupted hours on site from T-0.** Never start T-0 at the end of a shift

### Phase 5: T-0, build the ISO and boot immediately [WINDOW A]

> **[WINDOW A] The clock starts here.** The agent ISO and the `auth/` directory created
> in this step carry certificates that expire 24 hours after creation. Boot all nodes
> **within 12 hours** (Red Hat recommendation).

**WHERE:** Bastion, plus each node's BMC.

**DO:**

```bash
./scripts/05-install-ocp-disconnected.sh
# creates the ISO (T-0), then pauses until you have booted the nodes, then waits for install-complete
```

In a second terminal, record the deadline:

```bash
T0=$(stat -c %Y install-config/agent.x86_64.iso)
echo "T-0:               $(date -u -d @"${T0}")"
echo "Boot by (12 h):    $(date -u -d @"$(( T0 + 12*3600 ))")"
echo "Hard limit (24 h): $(date -u -d @"$(( T0 + 24*3600 ))")"
```

Mount the ISO on every node's BMC and boot it ([Lab 10](labs/10-bootstrap-cluster.md)).

**If Window A lapses before the nodes boot:** do not reuse anything from that run.
Rename `install-config/` aside, restore the two YAML files from `~/config-backup/` into
a clean directory, and run `agent create image` again. That produces a **new** ISO
**and** a new `auth/`. Never mix an ISO and an `auth/kubeconfig` from different runs.

**VERIFY:** `openshift-install agent wait-for install-complete` exits successfully.
`oc get nodes` shows every node `Ready`.

### Phase 6: Post-install soak, then build the permanent services [WINDOW B]

> **[WINDOW B]** For at least the first 24 hours after install, keep the cluster
> powered on and leave the bastion's DNS/NTP **exactly as it is**. Building the
> permanent services during this window is fine. **Switching** to them is not.

**WHERE:** Bastion (with `KUBECONFIG`).

**DO:**

1. Check for pending CSRs. There should be none unless nodes were power-cycled:

   ```bash
   export KUBECONFIG=~/OCPV-Dark-Site-Deployment/install-config/auth/kubeconfig
   oc get csr | grep -i pending || echo "no pending CSRs"
   # if any: oc get csr -o name | xargs oc adm certificate approve
   ```

2. Mirror cluster resources (IDMS, ITMS, CatalogSource). `scripts/05` applies them.
   Confirm with `oc get catalogsource -n openshift-marketplace`.
3. Install OpenShift Virtualization: `./scripts/06-deploy-cnv.sh` ([Lab 13](labs/13-openshift-virtualization.md)).
4. Install the Kubernetes NMState operator from the mirrored catalog. It is needed for
   the VMs' bridge and for the DNS cutover:

   ```yaml
   # nmstate-operator.yaml — set `source` to the name shown by: oc get catalogsource -n openshift-marketplace
   apiVersion: v1
   kind: Namespace
   metadata:
     name: openshift-nmstate
   ---
   apiVersion: operators.coreos.com/v1
   kind: OperatorGroup
   metadata:
     name: openshift-nmstate
     namespace: openshift-nmstate
   spec:
     targetNamespaces: [openshift-nmstate]
   ---
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   metadata:
     name: kubernetes-nmstate-operator
     namespace: openshift-nmstate
   spec:
     channel: stable
     name: kubernetes-nmstate-operator
     source: <catalog-source-name>
     sourceNamespace: openshift-marketplace
   ```

   ```bash
   oc apply -f nmstate-operator.yaml
   oc get csv -n openshift-nmstate -w            # wait for Succeeded
   oc apply -f - <<'EOF'
   apiVersion: nmstate.io/v1
   kind: NMState
   metadata:
     name: nmstate
   EOF
   ```

5. Create the host bridge that `manifests/production/dns-vm/nad-flat-l2.yaml` expects
   (`br-flat`). The simplest option is a **spare NIC** cabled to the same L2. If the
   bond is your only uplink, use an OVN-Kubernetes `localnet` mapping on `br-ex`
   instead (see defect D13).

   ```yaml
   apiVersion: nmstate.io/v1
   kind: NodeNetworkConfigurationPolicy
   metadata:
     name: br-flat
   spec:
     desiredState:
       interfaces:
         - name: br-flat
           type: linux-bridge
           state: up
           ipv4:
             enabled: false
           bridge:
             options:
               stp:
                 enabled: false
             port:
               - name: <spare-nic>      # e.g. a Slot 1 / Slot 21 port on the flat L2
   ```

6. Deploy the permanent DNS and NTP VMs: `./scripts/07-deploy-dns-vm.sh`, then
   `./scripts/08-deploy-ntp-vm.sh`. Fix the open defects D13–D16 first. `scripts/08` no
   longer applies any cutover configuration. That is Phase 7's job.
7. Have the permanent NTP server **follow the bastion** for now, so the cutover causes no
   time step. Add `server <BASTION_IP> iburst` to the NTP VM's `/etc/chrony.conf`, keep
   its `local stratum … orphan` line, and restart chronyd.

**VERIFY:**

```bash
dig +short @10.10.0.50 api.ocpv-lab.ocp-v.local     # permanent DNS answers
chronyc -h 10.10.0.51 tracking                      # permanent NTP answers, tracking the bastion
oc get vmi -n infrastructure                         # both VMIs Running
```

### Phase 7: Make-before-break: permanent primary, bastion secondary (no clock)

**WHERE:** Bastion (with `KUBECONFIG`), the registry host, and the BMCs.
**WHY:** This is the user's design of the bastion as **secondary** DNS/NTP, and it is
technically necessary. Applying the chrony `MachineConfig` triggers a **rolling node
reboot**. Every drain evicts VMs, including the permanent DNS/NTP VMs themselves, and
on RWO storage they shut down until they restart elsewhere. While that happens, the
bastion is what keeps names resolving and time flowing.

Analogy: **make-before-break** switching in telecom, or adding the new backend to a
load-balancer pool before draining the old one.

**DO:**

1. **Zone parity check.** During the overlap either server may answer a query, so they
   must agree **exactly**. A record that exists on only one of them causes intermittent
   failures that are hard to diagnose.

   ```bash
   set -a && source .env && set +a
   for n in "api.${CLUSTER_NAME}.${BASE_DOMAIN}" "api-int.${CLUSTER_NAME}.${BASE_DOMAIN}" \
            "test.apps.${CLUSTER_NAME}.${BASE_DOMAIN}" "registry.${BASE_DOMAIN}" \
            "cp01.${BASE_DOMAIN}" "cp02.${BASE_DOMAIN}" "cp03.${BASE_DOMAIN}"; do
     a=$(dig +short @"${BASTION_IP}" "$n"); b=$(dig +short @"${DNS_VM_IP}" "$n")
     [[ "$a" == "$b" ]] && echo "OK   $n $a" || echo "DIFF $n bastion=$a permanent=$b"
   done
   ```

2. **DNS: permanent primary, bastion secondary** with a `NodeNetworkConfigurationPolicy`:

   ```yaml
   apiVersion: nmstate.io/v1
   kind: NodeNetworkConfigurationPolicy
   metadata:
     name: dns-resolvers
   spec:
     desiredState:
       dns-resolver:
         config:
           search:
             - ocp-v.local
           server:
             - 10.10.0.50   # permanent DNS (primary)
             - 10.10.0.5    # bastion (secondary; removed in Phase 8)
   ```

3. **NTP: permanent preferred, bastion fallback** with a Butane-generated `MachineConfig`.
   Repeat with `role: worker` and `name: 99-worker-chrony` if you have a worker pool.
   On a compact cluster all nodes are in the `master` pool.

   ```yaml
   # 99-master-chrony.bu
   variant: openshift
   version: 4.22.0
   metadata:
     name: 99-master-chrony
     labels:
       machineconfiguration.openshift.io/role: master
   storage:
     files:
       - path: /etc/chrony.conf
         mode: 0644
         overwrite: true
         contents:
           inline: |
             server 10.10.0.51 iburst prefer
             server 10.10.0.5 iburst
             driftfile /var/lib/chrony/drift
             makestep 1.0 3
             rtcsync
             logdir /var/log/chrony
   ```

   ```bash
   butane 99-master-chrony.bu -o 99-master-chrony.yaml
   oc apply -f 99-master-chrony.yaml
   oc get mcp -w        # wait until every pool shows UPDATED=True (rolling reboot)
   ```

4. **Re-point everything outside the cluster too.** Do the registry host (`nmcli`
   DNS servers and `/etc/chrony.conf`, same order as above), admin workstations, and
   each node's **XCC NTP/DNS settings**.
5. **Soak** for at least 24 hours, longer if you can.

**VERIFY:**

```bash
oc get nncp dns-resolvers                              # Available
oc get nnce | grep dns-resolvers                       # SuccessfullyConfigured on every node
oc debug node/<node> -- chroot /host chronyc sources   # both servers listed, permanent selected (*)
oc debug node/<node> -- chroot /host dig +short registry.ocp-v.local
```

### Phase 8: Break: remove the bastion, drain, empty it, disconnect (no clock)

**WHERE:** Bastion, cluster, registry host, BMCs.
**WHY:** Like draining a load-balancer backend: take it out of the pool, prove traffic
has stopped, and only then power it off.

**DO:**

1. Remove the bastion from the cluster's configuration. Edit the NNCP from Phase 7 so
   `server` lists only `10.10.0.50`. Remove the `server 10.10.0.5` line from the Butane
   file, regenerate it, apply it, and wait for `oc get mcp` to show `UPDATED=True`.
2. Remove the bastion from the registry host, workstations and XCC settings.
3. Let the permanent NTP server run independently. Remove `server <BASTION_IP>` from the
   NTP VM's `chrony.conf` and restart chronyd. It is now the site's time authority, in
   orphan mode.
4. **Drain verification on the bastion.** Wait at least one hour, then confirm nothing
   is still using it:

   ```bash
   sudo journalctl -u dnsmasq --since '-1h' | grep query   # no queries from node or registry IPs
   sudo chronyc clients                     # no client has polled recently (Last column keeps growing)
   ```

5. **Empty the bastion.** Work through the checklist in section 4.
6. Stop the services, then power the bastion off and unplug it:

   ```bash
   sudo systemctl disable --now dnsmasq chronyd
   ```

**VERIFY (after disconnect):**

```bash
oc get nodes && oc get co                              # all Ready / Available, none Degraded
oc debug node/<node> -- chroot /host chronyc sources   # only 10.10.0.51
oc debug node/<node> -- chroot /host dig +short registry.ocp-v.local
oc get vmi -A                                          # VMs still running; restart one as a test
```

Prove that the image path still works without the bastion: schedule a pod that uses a
mirrored image, referenced by its **original** name so IDMS/ITMS redirect it, on a node
where that image is not cached.

---

## 4. Bastion evacuation checklist

These items exist **only** on the bastion. Move them before Phase 8, step 6:

| Item | Path | Move to | Why |
|---|---|---|---|
| Admin kubeconfig and `kubeadmin` password | `install-config/auth/` | Sealed offline storage or a password vault | Break-glass cluster access. This is the only copy |
| As-built install configs | `~/config-backup/*.yaml` | Secure storage (they contain secrets) | Rebuild and audit record |
| oc-mirror workspace and the `ImageSetConfiguration` | `/opt/ocp-mirror/oc-mirror-workdir/working-dir/`, `imageset-config.yaml` | Registry host | Needed for future incremental (differential) mirroring |
| CLI tools | `/opt/ocp-mirror/clients/` | Registry host | The registry host becomes the Day-2 mirroring and admin host |
| Registry CA and credentials | `/opt/ocp-mirror/registry-ca.crt`, `auth.json` | Registry host or vault | Day-2 pushes |
| `.env` and dnsmasq config | repo root, `/etc/dnsmasq.d/ocp-v.conf` | Secure storage | Reference for zone parity and rebuilds |
| The USB drives | n/a | Secure storage | They carry the pull secret and passwords |

---

## 5. Risk register

| # | Risk | Effect | Mitigation |
|---|---|---|---|
| R1 | Registry co-located on the bastion | The bastion can never be disconnected. Losing it stops image pulls | Separate registry host (`MIRROR_REGISTRY_IP ≠ BASTION_IP`). This is a hard constraint |
| R2 | **The cluster hosts its own DNS/NTP** (circular dependency) | On a full cold start, the DNS/NTP VMs only start after OpenShift and Virtualization are up. Until then, names outside the cluster (e.g. `registry.<domain>`) don't resolve | Partly mitigated by design: on `platform: baremetal`, each node runs CoreDNS and keepalived static pods that resolve `api`, `api-int` and `*.apps` locally. **Recommended:** run a secondary authoritative DNS and NTP **outside** the cluster, for example on the registry host, which is permanent anyway |
| R3 | Free-running site clock (orphan mode, no GPS/upstream) | The site drifts from true UTC over time. Internal consistency, which is what etcd needs, is preserved | Accept and document it, or add a GPS/PTP reference if audit or compliance requires true UTC |
| R4 | USB media failure | Return trip | Two independently verified copies (`SHA256SUMS`) |
| R5 | Window A lapses | ISO unusable | Phase 4 backups, then the regeneration procedure in Phase 5 |
| R6 | Cluster powered off inside Window B | Kubelet certificates not recovered automatically | Approve pending CSRs (Phase 6, step 1) |
| R7 | Day-2 updates after the bastion is gone | Nobody can load new content | The registry host inherits the tools and the oc-mirror workspace (section 4) |

---

## 6. Known repo defects on this path

Found while writing this runbook. **Fixed** items are in this change. **Open** items
still need a patch. Until then, use the commands on this page.

| # | Phase | File | Defect | Effect | Status |
|---|---|---|---|---|---|
| D1 | 0 | `scripts/01-mirror-preparation.sh` | Downloads `oc.tar.gz`, `openshift-install.tar.gz`, `oc-mirror.tar.gz` from a version path. Real names are `openshift-client-linux.tar.gz`, `openshift-install-linux.tar.gz`, `oc-mirror.tar.gz` | `curl -f` gets a 404 and `set -e` exits | Open |
| D2 | 0 | `scripts/01-mirror-preparation.sh` | Pins oc-mirror to `OCP_VERSION`. Red Hat recommends the latest oc-mirror | Misses v2 fixes | Open |
| D3 | 0, 3 | `scripts/01`, `scripts/04` | Wrong oc-mirror v2 forms. Mirror-to-disk needs a `file://<dir>` destination. Disk-to-mirror needs `--from file://<dir> docker://<registry>`, not `--workspace` | Mirror fails, or tries to reach `registry.redhat.io` from the dark site | Open |
| D4 | 1 | `kickstart/ks-bastion.cfg` | Listed `openshift-clients`, which is not on the RHEL DVD | Kickstart halts on a missing package | **Fixed** |
| D5 | 3 | `.env.example`, `scripts/04`, `kickstart/ks-registry-mirror.cfg` | Assumes port 443. Mirror registry defaults to **8443**, `scripts/04` passes no port, and the Kickstart opens only `5000/tcp` | Registry unreachable at the configured address | Open |
| D6 | 3 | `scripts/04-mirror-ocp-images.sh` | Fallback pulls `docker.io/library/registry:2` | Impossible offline | Open |
| D7 | 3 | `scripts/04-mirror-ocp-images.sh` | Saves the Kickstart-generated `/opt/registry/certs/domain.crt` as the registry CA. Mirror registry serves a certificate signed by its own `<quayRoot>/quay-rootCA/rootCA.pem` | Wrong `additionalTrustBundle` | Open |
| D8 | 4 | `install-config/install-config.yaml.template` | No `imageDigestSources` | The installer looks for the release on `quay.io`. In a fully disconnected site it hangs without an error | Open |
| D9 | 4 | `install-config/install-config.yaml.template`, `mirror-config.yaml.template` | `pullSecret` lacks mirror registry credentials, and the template advises against adding them | Nodes can't pull from the authenticated mirror | Open |
| D10 | 4 | `scripts/03-generate-install-config.sh` | `envsubst` finds no `${VAR}` in the template (it has literal values), so it succeeds unchanged and the `sed` fallback never runs | `agent-config.yaml` keeps sample MACs and IPs. Edit it by hand ([Lab 08](labs/08-install-agent-config.md)) | Open |
| D11 | 4, 5 | `install-config/agent-config.yaml.template` | No `additionalNTPSources` | Nodes don't use the bastion for time during install | **Fixed** |
| D12 | 6 | `mirror/imageset-config.yaml.template` | No `kubernetes-nmstate-operator` | No bridge for the DNS/NTP VMs, and no DNS cutover | **Fixed** |
| D13 | 6 | `manifests/production/dns-vm/nad-flat-l2.yaml` | References a `br-flat` bridge that nothing creates. OVN-Kubernetes already owns the primary uplink through `br-ex` | VMs can't attach to the flat L2. Use the Phase 6 NNCP on a spare NIC, or an OVN `localnet` NAD | Open |
| D14 | 6 | `manifests/production/{dns,ntp}-vm/vm.yaml` | `cloudInitConfigDrive.sources[].secret` is not a KubeVirt field, and the cloud-init object is a ConfigMap referenced as a Secret | The VM is rejected, or boots without cloud-init | Open |
| D15 | 6 | `manifests/production/dns-vm/cloud-init.yaml` | `packages: [bind]` with no reachable repository | BIND is never installed. Add `yum_repos` that point at `http://<MIRROR_REGISTRY_IP>/rhel9/{BaseOS,AppStream}` (Phase 3). Use the IP, because the DNS VM can't resolve names before BIND runs | Open |
| D16 | 6 | `mirror/imageset-config.yaml.template` | No storage operator, so no `StorageClass` | DNS/NTP `DataVolume`s stay `Pending` | Open (decision: [USB Transfer Kit §3.2](USB-TRANSFER-KIT.md#32-the-mirror-archive-openshift-release-rhcos-operators-and-guest-images)) |
| D17 | 7 | `scripts/08-deploy-ntp-vm.sh` | Applied single-server DNS/NTP cutover `MachineConfig`s as soon as the NTP VM booted | Break-before-make, with no bastion fallback during the rolling reboots | **Fixed** (cutover moved to Phase 7) |
| D18 | 7 | `manifests/production/dns-vm/machineconfig-dns.yaml` | Encodes newlines as `%0E` (Shift Out) instead of `%0A`, and overwrites `/etc/resolv.conf`, which NetworkManager manages | Corrupt or overwritten resolver config. Use the Phase 7 NNCP instead | Open (no longer applied by any script) |
| D19 | 8 | `scripts/00-prerequisites-check.sh` | In `--post-install`, the pipes sit outside `check`'s arguments, so they filter `check`'s output rather than the command | PASS/FAIL results are meaningless | Open |
| D20 | all | `scripts/lib/common.sh` | Computed `REPO_ROOT` from its own directory (`scripts/lib/..` = `scripts/`), so `load_env` never found `.env` | **Every** numbered script exited at start-up | **Fixed** |
| D21 | 2 | `scripts/02-bootstrap-dns-ntp.sh` | Listened only on `BASTION_IP` (so the bastion's own `127.0.0.1` lookups failed). Used a version-dependent `*.apps` wildcard. `enable --now` never applied config changes on re-run. No pre-flight or real verification | Temporary DNS unreliable; re-runs silently ineffective | **Fixed** (rewritten and tested: dnsmasq 2.91, chrony 4.5) |
| D22 | 2, 6–8 | Labs 07/14, `docs/05`–`07`, `scripts/00`, `scripts/08` | Check NTP with `chronyc -h <remote-ip> tracking`. chronyd answers monitoring commands only from localhost by default | The check always fails remotely. Use `chronyd -Q 'port 0' 'cmdport 0' 'pidfile …' 'server <ip> iburst'` | **Fixed** for the bastion (Lab 07, `docs/03`, `docs/05`, `scripts/00` pre-install). Open for the NTP VM checks |

---

## Sources

- [Installation overview: Ignition certificates expire after 24 hours; use within 12 hours; recovery and CSR approval](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/installation_overview/ocp-installation-overview)
- [Agent-based Installer configuration parameters (`additionalNTPSources`)](https://docs.openshift.com/container-platform/4.14/installing/installing_with_agent_based_installer/installation-config-parameters-agent.html)
- [ABI hangs in a disconnected environment (base ISO extraction via `oc`)](https://access.redhat.com/solutions/7005191)
- [ABI ISO creation fails without `nmstatectl`](https://access.redhat.com/solutions/7020319)
- [Creating a mirror registry with mirror registry for Red Hat OpenShift (port 8443, RHEL 8/9)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/disconnected_environments/installing-mirroring-creating-registry)
- [oc-mirror plugin v2: use the latest version](https://docs.okd.io/latest/disconnected/about-installing-oc-mirror-v2.html)
- [Configuring chrony with Butane (`machine_configuration`)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/machine_configuration/machine-configs-configure)
