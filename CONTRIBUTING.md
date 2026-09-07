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
- Keep changes focused — one logical change per PR when possible
- Test scripts on RHEL 9 where applicable
- Never commit secrets (`.env`, pull secrets, keys, certificates)

## Documentation

- Numbered guides in `docs/` should stay in execution order
- Update `README.md` if you add new top-level directories or change the quick-start flow
- Site-specific values belong in `.env.example`, not hardcoded in scripts

## Questions

Open a GitHub issue for design questions or environment-specific guidance.
