# Release Process

How to publish a new version of this repository.

## Versioning

We use [Semantic Versioning](https://semver.org/):

| Bump | When |
|---|---|
| **MAJOR** (`2.0.0`) | Breaking changes to scripts, IP plans, or install flow |
| **MINOR** (`1.1.0`) | New features, docs, or manifests (backward compatible) |
| **PATCH** (`1.0.1`) | Bug fixes and clarifications only |

## Checklist

### 1. Finalize changelog

Edit [CHANGELOG.md](../CHANGELOG.md):

1. Ensure all changes since the last release are listed under `[Unreleased]`
2. Rename `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`
3. Add a fresh empty `[Unreleased]` section at the top
4. Update compare links at the bottom:

```markdown
[Unreleased]: https://github.com/sylviyayy/OCPV-Dark-Site-Deployment/compare/vX.Y.Z...HEAD
[X.Y.Z]: https://github.com/sylviyayy/OCPV-Dark-Site-Deployment/compare/vPREVIOUS...vX.Y.Z
```

### 2. Commit and tag

```bash
git add CHANGELOG.md
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "vX.Y.Z"
git push origin main
git push origin vX.Y.Z
```

### 3. GitHub Release (optional)

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file CHANGELOG.md
```

Or create the release manually on GitHub and paste the version section from the changelog.

## Agent / automation note

When making edits via Cursor or other automation:

1. Always add changelog bullets under `[Unreleased]` in the same change set
2. Do not bump version numbers unless explicitly asked to cut a release
3. Group related bullets; avoid one bullet per file touched
