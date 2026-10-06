# 11 — Configuring `oc` for Remote Access

> **Grade:** lab-grade access. `kubeadmin` and the installer kubeconfig are break-glass
> credentials; production sites add an identity provider and remove `kubeadmin`.

## Goal

Use `oc` against the API VIP from the bastion, by name, with TLS verified.

## Steps

### 11.1 Point `oc` at the installer kubeconfig

**WHERE** — Bastion (`${BASTION_HOSTNAME}`), RHEL 9.x, as `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The installer wrote a kubeconfig with a client certificate for `system:admin` into
`${INSTALL_DIR}/auth/` — outside the repo, so it can never be committed (ADR-08). Copying it to
`~/.kube/config` with mode 600 makes it the default for your shell.
Consumed by: Labs 12–16 and scripts 06–08 (which read `${INSTALL_DIR}/auth/kubeconfig` directly).
If skipped: `oc` talks to nothing.

**EDIT** — No edits in this step.

**DO**

```bash
set -a && source .env && set +a
install -D -m 600 "${INSTALL_DIR}/auth/kubeconfig" ~/.kube/config
```

**VERIFY**

```bash
oc whoami                                     # expect: system:admin
oc get nodes --no-headers | wc -l             # expect: 3
oc whoami --show-server                       # expect: https://api.<CLUSTER_NAME>.<BASE_DOMAIN>:6443
```

**FAILS IF** — `x509: certificate is valid for api…, not 10.10.0.100` ← you used the VIP by IP;
the API certificate names `api.<cluster>.<domain>`, so resolve the name through the bastion DNS.

### 11.2 Other workstations

**WHERE** — Any admin workstation that can reach `API_VIP`

**WHY** — The kubeconfig is a credential; it travels over SSH, never through git, chat or tickets.
Consumed by: remote administration. If skipped: nothing breaks; you administer from the bastion.

**EDIT** — No edits in this step.

**DO** — `scp installer@<BASTION_IP>:.kube/config ~/.kube/config-coe01 && chmod 600 ~/.kube/config-coe01`,
and make `api.<CLUSTER_NAME>.<BASE_DOMAIN>` resolve (point the workstation at `BASTION_IP` or the DNS VMs).

**VERIFY** — `KUBECONFIG=~/.kube/config-coe01 oc whoami` → expect: `system:admin`.

**FAILS IF** — `no such host` ← the workstation does not use the site DNS.

## Next

→ [12 — Integrating the Mirror Registry and OperatorHub](12-mirror-operatorhub.md)
