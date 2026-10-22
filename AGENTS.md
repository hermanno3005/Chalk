# Chalk

## Build and test

`scripts/check` builds the app and runs the tests; extra arguments such as `-only-testing:…` pass through to `xcodebuild`. CI runs the same script on every PR.

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its name. See `docs/agents/triage-labels.md`.

### Branch lifecycle

Branch to `task/<slug>` before the first edit; every change reaches `main` through a PR. Merged branches are deleted; prototypes land as docs plus a tag. See `docs/agents/branch-lifecycle.md`.

### Domain docs

Single-context — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
