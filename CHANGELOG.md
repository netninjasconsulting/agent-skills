# Changelog

All four skills share one version number. Dates are in day, month, year order.

## 0.2.0 (15 November 2026)

Two new skills. The four existing skills are unchanged apart from the version number.

### Added

- `agent-permissions-check`: what the AI coding agents on a repository can do, and what stops them. Part A is the nine rows of the published policy. Part B covers agents at a developer's desk.

### Changed

- `scripts/validate.mjs` accepts GitHub's product name "audit log", and nothing else that holds the word "audit". It also skips the scratch folder of the planning tools.
- Every skill carries version 0.2.0. The four skills from 0.1.0 have one other change: the guided app starter now says "three other skills" where it said "the other three", because the kit has grown. What it runs is the same.

### Verified for this release (15 November 2026)

- The nine policy rows, against the source of the published page in the website repository (commit 544c46a).
- Claude Code settings, permissions, and MCP facts marked "checked" in `skills/agent-permissions-check/references/agent-files.md`, read from code.claude.com on 15 November 2026.
- Codex configuration facts marked "checked" in the same file, read from learn.chatgpt.com on 15 November 2026. Facts marked "verify" were not confirmed.

### Tested

See `tests/RESULTS.md`. In short: `agent-permissions-check` passed two runs against its fixture and one scenario with Claude Code, after a first pair of runs found two misses that are now fixed. `tests/list-agent-config.test.sh` runs in CI.

### Known limits

- `agent-permissions-check` has not been run with `gh` access, against a real home folder, or with a yes to the policy file.
- The fixture runs gave the user's answers in advance, so the order "ask, then read" was not observed.
- The reader script is tested on Linux. It is written for POSIX `sh` and `awk`, and it has not been run with BSD tools.
- The masked view works line by line. A file on one line prints as one long masked line. A token inside the path of an address is hidden only when the path segment is 20 characters or longer.
- Tool-specific settings of agents other than Claude Code and Codex are not read.

## 0.1.0 (14 November 2026)

First version of the four skills.

### Fixes included before release

Changes from the Net Ninjas original:

- Mask env credentials before keeping readable flag values, including numeric passwords.
- Include env-style credentials in Git history checks, even after their file is deleted.
- Add regression coverage for both scanner fixes.
- Describe Net Ninjas Consulting's cloud, DevOps, and AI work in all four skill READMEs and closing chat attributions, outside findings and without a booking request.

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

- Full skill fixture runs used Claude Code on Linux. Other agents and full skill runs on macOS are untested.
- Scanner regression tests pass on Linux in CI and on macOS with BSD tools. Fresh-agent fixture runs after the latest changes remain outstanding.
- The guided app starter's build and remote steps have not been run end to end.
- The GitOps hygiene check has not been run with `gh` access against a real repository.
