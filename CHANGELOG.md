# Changelog

Every skill carries the same version number. Dates are in day, month, year order.

## 0.2.0 (15 November 2026)

Three new skills. The four skills from 0.1.0 keep their checks.

### Added

- `agent-permissions-check`: what the AI coding agents on a repository can do, and what stops them. Part A is the nine rows of the published policy. Part B covers agents at a developer's desk.
- `ai-feature-architecture-check`: a score out of 12 for an AI feature from what the code shows, the path personal data takes through it, and whether its cost per action can be measured.
- `serverless-deploy-check`: whether a deploy to AWS Lambda, Vercel, Cloudflare Workers, or Supabase is sized on purpose and safe to expose. It scores eight efficiency checks and ten security checks from what the repository shows, maps what each function can reach, and gives a verdict and the first three things to change. It reads configuration through `scripts/read-serverless-config.sh`, which hides values, and it gives no memory size, saving, or cost.

### Changed

- `scripts/validate.mjs` accepts GitHub's product name "audit log", and nothing else that holds the word "audit". It also skips the scratch folder of the planning tools, which `.gitignore` now lists.
- `scripts/validate.mjs` pins the twelve checks, the three score bands with their ranges, the ten stops, the eight leak paths, the seven cost columns, and the cost query of the AI feature architecture check to their published wording. It matches whole lines, so a check with a wrong number fails.
- `scripts/validate.mjs` pins the nine rows of the agent permissions check to their published wording.
- `scripts/validate.mjs` pins the eighteen checks of the serverless deploy check in `SKILL.md` and `references/checks.md`, its status table, its verdict table, and the order of the first three. `tests/validate.test.mjs` gains twelve mutation cases for them, so 26 run in CI.
- CI runs `tests/read-serverless-config.test.sh`, which fails when a planted value appears in any output of the reader.
- `handover-runbook-generator` reads env files through a stricter filter. The old one printed comments and the later lines of a value that spans lines. `tests/names-filter.test.sh` runs the filter of both skills that use it, in CI.
- Every skill carries version 0.2.0. The four skills from 0.1.0 have one other change: the guided app starter now says "three other skills" where it said "the other three", because the kit has grown. What it runs is the same.

### Verified for this release (15 November 2026)

- The nine policy rows, against the source of the published page in the website repository (commit 544c46a).
- Claude Code settings, permissions, and MCP facts marked "checked" in `skills/agent-permissions-check/references/agent-files.md`, read from code.claude.com on 15 November 2026.
- Codex configuration facts marked "checked" in the same file, read from learn.chatgpt.com on 15 November 2026. Facts marked "verify" were not confirmed.
- The twelve checks, the score bands, the ten stops, the eight leak paths, and the cost query, against the source of the published pages in the website repository (commit 544c46a). The skill carries the wording of netninjas.us in UK spelling, so four words differ in spelling from that site: pseudonymises, pseudonymised, pseudonymisation, and anonymised.
- The names in `skills/ai-feature-architecture-check/references/signals.md`, each read on 15 November 2026 from the vendor's package on npm or PyPI, from its source code, or from its documentation. The file names the source and the version in every row. The reads changed the list: Sentry's JavaScript SDK now uses `dataCollection` where it used `sendDefaultPii`, Together's default host is `api.together.ai`, two Google packages and one Langfuse package are deprecated, and pgvector has a fourth operator.
- The rule that a local settings file tracked by Git waits for trust, read from code.claude.com on 15 November 2026.
- Provider facts in `skills/serverless-deploy-check/references/platforms.md`, read from each provider's documentation on 15 November 2026. Rows marked "verify" were not confirmed on that date.

### Tested

See `tests/RESULTS.md`. In short: `agent-permissions-check` passed two runs against its fixture and one scenario with Claude Code, after a first pair of runs found two misses that are now fixed. A review of the branch then found five ways to make the reader print a credential, and ten other problems. All fifteen are fixed, each with a test that failed first, and the fixture was run again. `tests/list-agent-config.test.sh` runs in CI. The twelve minor findings of that review are fixed as well. Six were fixed with the review, and six after it: the reader shows a server that carries the name of a hidden block, the fixture has an `open-rows` variant with a scenario for the open rules of rows 3, 4, and 6, and the validator pins the nine rows. The first two runs of that scenario gave a wrong count in the headline, which is now fixed, and a third run passed. `ai-feature-architecture-check` passed two runs against its fixture and one scenario, after the runs corrected one status in the expected result. A review of that branch found nine important problems and no critical one. Seven were fixed with the review. The other two are settled: the skill keeps UK spelling, and the names in `signals.md` were read from the vendors. The nine minor findings are fixed as well: the status rules have no gap inside a check, the order of the first three follows the design, and the fixture's error tracker, components, and documents table are wired in. `serverless-deploy-check` passed both runs against its quickship fixture and its four scenarios with Claude Code subagents. The runs led to changes in several rules. Run 2, scenario 2, and scenario 3 were run again after those changes, and they passed. Run 1, scenario 1, and scenario 4 were not run again. The model provider's safeguards stopped two attempts before they finished, and neither counts. A final review of that branch then found no critical problem, five important ones, and eleven minor ones. The fixes changed the reader and four rules: a function, resource, job, or environment whose name holds a word such as `token` now shows its settings; the credentials setting of a cross-origin rule shows as a boolean; a hidden value in `vercel.json` `env` is "ask the team" under S3, while a credential-like name in Wrangler `vars` stays a fail; a Lambda function with no role in the repository is "ask the team" under S2; and "Ready after the first three" now covers a warn in S1 to S5. The fixture was not run again before this entry was written.

### Branch B independent review corrections (15 November 2026)

- Make scoring and leak-path statuses disjoint, require code owner approval enforcement, and require useful fallback behaviour.
- Correct OpenSearch import names and legacy OpenTelemetry capture guidance, and add vLLM signals.
- Replace the env names filter with stateful quote tracking so assignment-shaped lines inside multiline values remain hidden.
- Reject reordered and duplicate published structures, hidden wording decoys, and SQL appended to the pinned query. Fourteen mutation cases run in CI.
- Correct the fixture explanations for the Anthropic SDK timeout and Sentry user data; aggregate statuses remain unchanged.

### Independent review corrections (15 November 2026)

- Correct hidden JSON arrays, escaped keys and values, and quoted or flow YAML credential handling. Escaped strings and the remainder of escaped text are now hidden conservatively.
- Tighten evidence for enforced permissions, clarify status precedence, and update Claude Code and Codex facts from vendor documentation. A self-hosted label alone leaves the runner unconfirmed.
- The plain fixture remains 1 of 9 enforced (1 not checked). The open-rows variant is now 0 of 9 enforced (1 not checked).

### Known limits

- `agent-permissions-check` has not been run with `gh` access, against a real home folder, or with a yes to the policy file.
- The fixture runs gave the user's answers in advance, so the order "ask, then read" was not observed.
- The reader script is tested on Linux and macOS with BSD awk and sed, under sh and dash. BusyBox remains untested.
- The masked view works line by line. A file on one line prints as one long masked line.
- The reader hides a credential that it can recognise by its key, its shape, its flag, or its place in an address. It cannot recognise a credential typed as an unlabelled plain word: a positional argument, a word in a command, a host name of fewer than 8 characters, or prose in an instruction file. This includes arbitrarily long alphabetic values, not only short words. This heuristic reader cannot guarantee that arbitrary input is free of credentials. The skill tells the agent not to repeat such a value.
- A fresh agent sometimes cites a line number that is off by one. Two of the last five runs did so, each on one line.
- The reader hides some harmless text: a word of 20 or more characters that mixes letters and digits, and comments in settings and env files.
- Tool-specific settings of agents other than Claude Code and Codex are not read.
- `ai-feature-architecture-check` has one fixture, in TypeScript, that fails most checks on purpose. It has not been run on a real product or on a feature that passes.
- The second pass of `ai-feature-architecture-check` was run with one question. The fixture has no second check that ends in "ask the team".
- The published cost query prices in euros, and the skill prints it as published.
- The serverless configuration reader works by line and does not parse. Some valid layouts are hidden, and the skill reports their settings as "not found in what the reader shows". A secret written where a setting name belongs, or used as a key name, can appear in its output.
- `serverless-deploy-check` has not been run with SAM, SST, Pulumi, `wrangler.jsonc`, Vercel `schedules`, or a framework app with no `vercel.json`.

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
