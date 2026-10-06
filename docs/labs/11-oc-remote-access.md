# 11 — Configuring `oc` for Remote Access

> **Grade:** lab-grade access. `kubeadmin` and the installer kubeconfig are break-glass credentials;
> production adds an identity provider and removes `kubeadmin`.

## Goal

Use `oc` against the API by name, with TLS verified, from the bastion and optionally a workstation.

## Steps

### 11.1 Point `oc` at the installer kubeconfig

**WHERE** — Bastion, RHEL 9.x, `installer`, cwd `~/OCPV-Dark-Site-Deployment`

**WHY** — The installer wrote a `system:admin` client-certificate kubeconfig into `${INSTALL_DIR}/auth/`,
outside the repo so it can never be committed (ADR-08). Mode 600 at `~/.kube/config` makes it your
shell's default. Scripts 06–08 read `${INSTALL_DIR}/auth/kubeconfig` directly.

**EDIT** — None.

**DO**

```bash
set -a && source .env && set +a
install -D -m 600 "${INSTALL_DIR}/auth/kubeconfig" ~/.kube/config
```

**VERIFY**

```bash
oc whoami                          # expect: system:admin
oc whoami --show-server            # expect: https://api.<CLUSTER_NAME>.<BASE_DOMAIN>:6443
oc get nodes --no-headers | wc -l  # expect: 3
```

**FAILS IF** — `x509: certificate is valid for api…, not <IP>` ← you addressed the VIP by IP; the
certificate names `api.<cluster>.<domain>`.

### 11.2 Another workstation (optional)

**WHERE** — An admin workstation that reaches `API_VIP`

**WHY** — The kubeconfig is a credential: it travels over SSH, never through git, chat or tickets.

**EDIT** — None.

**DO** — `scp installer@<BASTION_IP>:.kube/config ~/.kube/config-<CLUSTER_NAME> && chmod 600 ~/.kube/config-<CLUSTER_NAME>`;
point the workstation's DNS at `BASTION_IP` (or the DNS VMs after Lab 14).

**VERIFY** — `KUBECONFIG=~/.kube/config-<CLUSTER_NAME> oc whoami` → `system:admin`.

**FAILS IF** — `no such host` ← the workstation does not use the site DNS.

## Next

→ [12 — Integrating the Mirror Registry and OperatorHub](12-mirror-operatorhub.md)
