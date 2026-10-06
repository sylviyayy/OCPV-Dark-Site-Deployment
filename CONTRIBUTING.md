# Contributing

Thank you for improving this OCP-V dark site deployment reference.

## Changelog (required)

Every change that affects users must update [CHANGELOG.md](CHANGELOG.md).

We follow [Keep a Changelog](https://keepachangelog.com/) and [Semantic Versioning](https://semver.org/).

### Where to write

Add entries under the **`[Unreleased]`** section at the top of `CHANGELOG.md`. Do not edit past release sections except to fix typos.

### Categories

Use these headings under `[Unreleased]` (omit empty sections):

| Category | Use when |
|---|---|
| **Added** | New docs, scripts, manifests, or features |
| **Changed** | Updates to existing behavior or documentation |
| **Deprecated** | Features marked for future removal |
| **Removed** | Deleted files, scripts, or supported paths |
| **Fixed** | Bug fixes in scripts, templates, or docs |
| **Security** | Vulnerability or hardening changes |

### Entry style

- One bullet per logical change
- Write for operators reading the changelog, not for git history
- Reference paths when helpful: `` `scripts/02-bootstrap-dns-ntp.sh` ``
- Imperative, past tense optional — be consistent within a release

**Good:**

```markdown
### Fixed
- Correct API VIP placeholder in `install-config/install-config.yaml.template`
```

**Avoid:**

```markdown
### Fixed
- fixed stuff
- WIP updates
```

### Releases

When cutting a release:

1. Move `[Unreleased]` items into a new version section, e.g. `## [1.1.0] - 2026-09-15`
2. Add compare links at the bottom of `CHANGELOG.md`
3. Tag in git: `git tag -a v1.1.0 -m "v1.1.0"`
4. Create a GitHub Release from the tag (optional but recommended)

See [docs/RELEASE.md](docs/RELEASE.md) for the full release checklist.

## Pull requests

- Fill in the PR template changelog section
- Keep changes focused — one logical change per PR when possible; name the requirement IDs
  (`FR-xx`, `NFR-x`) in the commit subject and the changelog bullet
- Test scripts on RHEL 9.x per the OS table in [Lab 01](docs/labs/01-prerequisites-assumptions.md)
- Run the CI checks locally before pushing:
  `shellcheck -S warning scripts/*.sh scripts/lib/*.sh tests/*.sh`, `tests/render-all.sh`,
  `python3 tests/check-links.py`, `python3 tests/check-register.py`, `tests/check-repo-hygiene.sh`
- CI must be green
- Never commit secrets (`.env`, pull secrets, keys, certificates, kubeconfigs)

## Documentation

- `docs/labs/` is normative; `docs/reference/` is background (ADR-01, [docs/DECISIONS.md](docs/DECISIONS.md))
- Every lab step carries WHERE / WHY / EDIT / DO / VERIFY / FAILS IF: WHY names the mechanism, its
  consumer and the symptom if skipped; EDIT names file, key, old and new value; VERIFY compares a
  literal expected value
- One term per concept: bastion, checklist, control-plane node (`master` only as an API value)
- Update `README.md` if you add new top-level directories or change the lab list

## Site values and templates

- Site-specific values belong in `.env.example` (field register, in register order) and are rendered
  into templates by `scripts/lib/render.py`; never hard-code an IP, interface name or domain in a script
- A new `.env` key needs: a rule in `render.py` (`REGISTER` + `validate`), a row in the Lab 03 register,
  and a line in `.env.example` — `tests/check-register.py` fails until all three agree
- Never hand-edit a rendered file; generated files live outside the repo in `INSTALL_DIR` (ADR-08)

## Questions

Open a GitHub issue for design questions or environment-specific guidance.
