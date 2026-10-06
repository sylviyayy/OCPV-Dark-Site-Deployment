## Summary

<!-- What does this PR change and why? Name the PRD requirement IDs (FR-xx / NFR-x) it implements. -->

## Changelog

<!-- Copy the [Unreleased] bullets you added to CHANGELOG.md -->

- [ ] Updated `CHANGELOG.md` under `[Unreleased]`, one bullet per requirement ID

### Category

<!-- e.g. Added / Changed / Fixed / Removed / Security -->

-

## Test plan

- [ ] Tested on RHEL 9.x per the OS table in Lab 01 (PRD §4.1), where scripts are affected
- [ ] Every changed lab step has WHERE, WHY (mechanism, consumer, symptom if skipped) and EDIT
- [ ] Every changed VERIFY compares a literal expected value
- [ ] Only `.env.example` and templates edited; no rendered file committed
- [ ] CI green (`lint` workflow: shellcheck, render, docs, secrets)
- [ ] No secrets or `.env` files included
