# Changelog

All four skills share one version number. Dates are in day, month, year order.

## 0.1.0 (not released yet)

First version of the four skills.

### Added

- `vibe-code-pre-launch-check`: nine groups of checks, a verdict, findings ranked by reach, and `scripts/scan-secrets.sh`, which reports where secrets sit without printing them.
- `gitops-hygiene-check`: the 10-check safety net as a score out of 10, eleven extended checks, and ready-to-paste snippets. GitHub only.
- `handover-runbook-generator`: an eleven-section runbook with every statement tagged as found, assumed, or proposed.
- `guided-app-starter`: platform, comfort check, needs, one recommended stack, and a CI/CD baseline, with one confirmation per remote resource. It asks for the region, the United States or the EU, and the United States is the default.
- Fixtures and expected results for all four skills under `tests/`.
- `scripts/validate.mjs`, which checks every skill against the Agent Skills format and this repository's own rules.

### Verified for this release (13 November 2026)

- Third-party licences and authors, read from each project's LICENSE file: Superpowers (commit 22f0b46), Ponytail (96608e0), UI UX Pro Max (6ae86f6), and security-audit (c1c8a8c). All MIT.
- Install commands for the four third-party skills, read from each project's own instructions.
- The skills CLI: Node.js 22.20 or later, `npx skills add <owner>/<repo> --skill <name>`, and its anonymous telemetry with the `DISABLE_TELEMETRY` switch (commit b716f9d).
- The Agent Skills format: frontmatter fields and limits (agentskills/agentskills, commit 83021e2).
- Provider facts in the stack matrix that are marked "checked", including the US regions added on 13 November 2026. Facts marked "verify" were not confirmed.
- The ten checks and the score bands, against the published checklist on netninjas.eu.

### Changed (14 November 2026)

- Every skill's `homepage`, report footer, and guide link points to www.netninjas.us. The guided app starter still links the site for the region of the run.

### Tested

See `tests/RESULTS.md`. In short: the first three skills each passed one run against their fixture with Claude Code. The guided app starter has written scenarios and no passing run yet.

### Known limits

- Tested with one agent (Claude Code) on Linux. Other agents and macOS are untested.
- `scan-secrets.sh` was run with GNU grep, sed, and mawk. BSD tools are untested.
- The guided app starter's build and remote steps have not been run end to end.
- The GitOps hygiene check has not been run with `gh` access against a real repository.
