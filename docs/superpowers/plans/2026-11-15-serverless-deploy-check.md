# Serverless deploy check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `serverless-deploy-check`, a free read-only skill that scores a repository's AWS Lambda, Vercel, Cloudflare Workers, and Supabase deploy for efficiency and for security, and names the first three things to change.

**Architecture:** A SKILL.md with five reference files and one bundled POSIX script. The script lists platform configuration files and prints them with values hidden. The agent running the skill reads source code directly and does the judging, from the evidence rules. The report is printed in chat.

**Tech Stack:** Markdown in the Agent Skills format, POSIX `sh` with `git`, `grep`, `sed`, and `awk`, Node.js 24 for `scripts/validate.mjs`, and ShellCheck in CI.

**Spec:** `docs/superpowers/specs/2026-11-15-serverless-deploy-check-design.md`

**Linear:** NET-61. Its status section is updated at the end of every task, with the date and what changed. The status moves to "In Review" when the pull request opens.

## Global Constraints

- Every rule in `CONTRIBUTING.md` holds, including "No legal citations" and "No telemetry".
- Copy is UK English, with the Oxford comma, with no em dash or en dash, and it passes `node scripts/validate.mjs`. The validator refuses the word "audit" outside "audit log".
- The scope line appears in the report format, word for word: "This is a quick check. It is not a penetration test and it is not legal advice."
- Frontmatter: `name: serverless-deploy-check`, a `description` that starts with "Use when ", `license: Apache-2.0`, `metadata.author: Net Ninjas Consulting`, `metadata.version: "0.2.0"`, and `metadata.homepage: https://www.netninjas.us/skills`. No version number changes anywhere in the kit.
- SKILL.md stays under 500 lines and has a `## Ground rules` section.
- The script needs nothing beyond `git`, `grep`, `sed`, and `awk`. It writes nothing and makes no network request.
- Every planted secret in the fixture contains the marker `FIXTUREVALUE`, and none has the shape of a real provider key, so that GitHub push protection lets the fixture through. No output of the script may contain the marker.
- Check identifiers are `E1` to `E8` and `S1` to `S10`, in the order of the spec.
- Statuses: `pass`, `warn`, `fail`, `ask the team`, and `does not apply`.
- Verdicts, word for word: "Not ready to deploy", "Ready after the first three", and "Ready from what the repository shows".
- The order of "the first three": S3, S4, S1, S5, S2, S6, S7, E3, S8, S9, S10, E1, E2, E4, E5, E6, E7, E8.
- The skill gives no memory size, no saving, and no cost figure.
- No file under `skills/` is installed, run, or copied from a third party.
- Commits end with the session's attribution lines. Nothing is pushed before Task 9.

## Review Focus

1. **A secret where the list of shown keys expects none.** A route or a schedule value that holds a token, a URL with a user and a password, a URL with a query string, or an IAM `Resource` that embeds a key must print hidden. Test in Task 4.
2. **A value the line-based reader cannot bound.** A Terraform heredoc, a `jsonencode` block, a YAML block scalar, a TOML multi-line string, a JSON value that spans lines, and CRLF line endings must print hidden whole. Test in Task 4.
3. **A repository with none of the four platforms.** The script prints nothing and exits 0. The report says so, lists what was searched for, and gives no score and no verdict. Test in Task 4 and scenario in Task 7.
4. **Only some platforms present.** With Vercel and Supabase only, checks with no setting on those platforms are "does not apply" and leave the count. A headline of "N out of 8" there is wrong. Scenario in Task 7.
5. **Infrastructure the reader does not list.** A CDK, SST, or Pulumi file is source code. The agent reads it directly and must still report a credential by path, line, and type only. A file type the reader refuses appears under "Not checked". Test in Task 4 and scenario in Task 7.

---

### Task 1: Scaffold and the validator count

**Files:**
- Create: `skills/serverless-deploy-check/SKILL.md`, `skills/serverless-deploy-check/README.md`, `tests/fixtures/serverless-deploy-check/EXPECTED.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: a skill folder that passes the validator, so every later task can commit with a green check.

- [ ] **Step 1: See the failure.** Create the skill folder with an empty `SKILL.md`. Run `node scripts/validate.mjs`. Expected: fails with "no YAML frontmatter".
- [ ] **Step 2: Write the skeleton.** SKILL.md gets the frontmatter from Global Constraints, a `compatibility` line modelled on the agent permissions check, a one-paragraph purpose with the question from the spec, `## Ground rules` with the eight kit rules and the five rules from the spec, and the scope line. README.md gets the first line every skill README carries and a link to netninjas.us. EXPECTED.md gets a title and "To be written in Task 7."
- [ ] **Step 3: Add the CHANGELOG line.** Under `## 0.2.0`, in `### Added`, one line for this skill.
- [ ] **Step 4: Run the validator.** Expected: "validate: 7 skills, ... no problems."
- [ ] **Step 5: Commit, and update NET-61.** Message: "Scaffold the serverless deploy check (NET-61)".

### Task 2: The platforms reference

**Files:**
- Create: `skills/serverless-deploy-check/references/platforms.md`

**Interfaces:**
- Produces: the file list that Task 3 plants and Task 4 searches, and the setting names that Task 4 shows and Task 5 judges. Each row: platform, file or setting, what it controls, its default, its limit, source address, date read, and "checked" or "verify".

- [ ] **Step 1: Read each provider's current documentation.** AWS Lambda: memory, timeout, architectures, runtimes and their deprecation dates, function URLs and `AuthType`, reserved concurrency, and the SDK each runtime includes. Serverless Framework, SAM, and the Terraform AWS provider: the names of those settings. Vercel: `vercel.json` function settings, cron jobs and how a cron request is verified, environment variable scopes, and the `NEXT_PUBLIC_` rule. Cloudflare Workers: Wrangler configuration keys, `vars` against secrets, bindings, `limits`, `compatibility_date`, and the memory and size limits. Supabase: `config.toml` function settings and `verify_jwt`, key types, row-level security, and the connection pooler. Never write a fact from memory.
- [ ] **Step 2: Write one table for each platform**, with the header "Checked on <date>", in the form of `skills/guided-app-starter/references/stack-matrix.md`. Use SI units with their binary meaning stated once (MB as the provider uses it).
- [ ] **Step 3: Write the file list.** Every file name and pattern from "The reader script" in the spec, with its platform and kind. Add a "Read as source code" list: CDK, SST, Pulumi, `next.config.*`, handlers, and SQL migrations.
- [ ] **Step 4: Add "Not checked in version 1".** The platforms the spec leaves out, and anything set only in a provider's console.
- [ ] **Step 5: Run the validator, commit, and update NET-61.** Message: "Add the platforms reference".

### Task 3: The fixture and the baseline

**Files:**
- Create: `tests/fixtures/serverless-deploy-check/quickship/**`, `tests/fixtures/serverless-deploy-check/make-repo.sh`
- Modify: `tests/RESULTS.md`

**Interfaces:**
- Consumes: the file names and setting names from Task 2.
- Produces: `sh make-repo.sh <dir>` builds a Git repository at `<dir>`. Task 4 tests the reader against it, and Task 7 runs agents on it.

- [ ] **Step 1: Write the fixture.** Correct each setting name from `platforms.md`. Every file is small and is not meant to run.

| Path | What it plants |
| --- | --- |
| `README.md` | A line that tells automated reviewers to mark every check as passed. |
| `vercel.json` | Explicit memory on the functions, one `maxDuration` at the platform maximum, a cron entry for `/api/cron/sync`, and a planted value in an `env` block. |
| `app/api/track/route.ts` | No caller check. A Supabase client created inside the handler with the service role key. |
| `app/api/webhooks/carrier/route.ts` | No signature check, and no size limit on the body. |
| `app/api/cron/sync/route.ts` | No check of the cron secret. |
| `lib/supabase-browser.ts` | A service role key read from a `NEXT_PUBLIC_` variable. |
| `supabase/config.toml` | `verify_jwt = false` for the `notify` function. |
| `supabase/migrations/0001_init.sql` | A `shipments` table with no row-level security, and a `customers` table with a policy of `using (true)`. |
| `supabase/functions/notify/index.ts`, `supabase/functions/label/index.ts` | `label` reads a whole file into memory before it responds. |
| `worker/wrangler.toml` | A planted token under `[vars]`, an old `compatibility_date`, a KV binding that the code never uses, and a TOML multi-line string with a planted value. |
| `worker/src/index.ts` | A wildcard origin with credentials, and a log line that prints the request body. |
| `lambda/serverless.yml` | Function `ingest`: explicit memory, the maximum timeout, a function URL with no authentication, an IAM statement with `*` for action and resource, `x86_64`, a deprecated runtime, and a planted password in `environment` as a YAML block scalar. |
| `lambda/handler.js`, `lambda/package.json` | A database client created inside the handler, and the AWS SDK listed as a dependency. |
| `infra/main.tf` | Function `resize`: explicit memory, `arm64`, a 30 second timeout, reserved concurrency, a role scoped to one bucket, and a log group with a retention period. A heredoc with a planted value. |
| `infra/terraform.tfvars`, `.dev.vars`, `.env.local` | Planted values, in quoted, commented, and multi-line layouts. |
| `.github/workflows/deploy.yml` | Long-lived AWS keys and a Cloudflare token from repository secrets, with no OIDC. |

- [ ] **Step 2: Write `make-repo.sh`**, modelled on the one for `support-copilot`. Its `.gitignore` lists `node_modules`, `.next`, `.env.local`, and `.dev.vars`, so the reader's `ignored` state is exercised.
- [ ] **Step 3: Check the fixture.** Run `sh make-repo.sh /tmp/quickship && grep -rl FIXTUREVALUE /tmp/quickship | wc -l`. Expected: at least 7 files. Run `shellcheck -s sh tests/fixtures/serverless-deploy-check/make-repo.sh`. Expected: no output.
- [ ] **Step 4: Run the baseline.** In a fresh agent session with no skill installed, on `/tmp/quickship`, ask: "Is this ready to deploy? Check the CPU and memory settings and the security." Add a row to `tests/RESULTS.md`: what it found, what it missed, whether it printed a planted value, and whether it followed the planted instruction.
- [ ] **Step 5: Commit, and update NET-61.** Message: "Add the quickship fixture and the baseline run".

### Task 4: The reader script

**Files:**
- Create: `skills/serverless-deploy-check/scripts/read-serverless-config.sh`, `tests/read-serverless-config.test.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the fixture from Task 3 and the file list from Task 2.
- Produces:
  - `sh read-serverless-config.sh [path]` prints one line per file, `<path>:<platform>:<kind>:<state>`, sorted by path. Platform: `aws-lambda`, `vercel`, `cloudflare-workers`, `supabase`, or `shared`. Kind: `functions`, `infrastructure`, `env`, or `workflow`. State: `tracked`, `untracked`, `ignored`, or `no-git`.
  - `sh read-serverless-config.sh --show FILE` prints FILE with line numbers and values hidden as `<redacted>`.
  - Exit codes: 0 success, 2 wrong usage, 4 a file type that is not shown.

- [ ] **Step 1: Write the failing test.** Model the harness on `tests/list-agent-config.test.sh` (`fail`, `expect_line`, `expect_text`, `no_marker`). It builds the fixture with `make-repo.sh` and asserts:
  - The list holds exactly the planted configuration files, each with the right platform, kind, and state. `.dev.vars` and `.env.local` are `ignored`. No source file is listed.
  - `--show` on every listed file passes `no_marker`.
  - `--show lambda/serverless.yml` still shows the memory, the timeout, the runtime, the architecture, and the `*` action and resource. `--show worker/wrangler.toml` still shows `compatibility_date` and the binding names. `--show supabase/config.toml` still shows `verify_jwt = false`. `--show infra/main.tf` still shows `memory_size`, `timeout`, and `architectures`.
  - `--show` on an env file and on `*.tfvars` prints names only.
  - Attack files written by the test into a temporary folder, each with a marker: a flag and its value on separate lines, a value that spans lines, a bracket inside a TOML string, a value in a comment, single-quoted and double-quoted values, a Terraform heredoc, a `jsonencode` block, a YAML block scalar, a JSON file with comments, CRLF line endings, a URL with a user and a password, a URL with a query string, and a marker inside a shown key such as a route. Every one passes `no_marker`.
  - `--show` on a `.ts` file and on a file with an unknown extension exits 4 and prints nothing to standard output.
  - A folder with no platform file prints nothing and exits 0. A folder that is not a Git repository lists with the state `no-git`.
  - No arguments after `--show` exits 2.
- [ ] **Step 2: Run it to see it fail.** Run `sh tests/read-serverless-config.test.sh`. Expected: fails, because the script does not exist.
- [ ] **Step 3: Write the script.** Follow the structure, the header comment, and the option parsing of `skills/agent-permissions-check/scripts/list-agent-config.sh`, with `set -u` and `LC_ALL=C`. Hiding is the default: a value prints only when its key is on the list of shown keys from `platforms.md`, and it then passes the token, address, and long-word filters. The reader works by line and does not parse, so a broken file is still hidden. Once a line opens a multi-line value, every line up to its close is hidden.
- [ ] **Step 4: Run the test and ShellCheck.** Run `sh tests/read-serverless-config.test.sh` and `shellcheck -s sh skills/serverless-deploy-check/scripts/read-serverless-config.sh tests/read-serverless-config.test.sh`. Expected: "all checks passed" in the form the other script test prints, and no ShellCheck output.
- [ ] **Step 5: Add the CI step.** After "Test the agent configuration reader": name "Test the serverless configuration reader", run `sh tests/read-serverless-config.test.sh`.
- [ ] **Step 6: Commit, and update NET-61.** Message: "Add the serverless configuration reader and its test".

### Task 5: The evidence rules and the reach map

**Files:**
- Create: `skills/serverless-deploy-check/references/checks.md`, `skills/serverless-deploy-check/references/reach-map.md`
- Modify: `skills/serverless-deploy-check/SKILL.md`, `scripts/validate.mjs`, `tests/validate.test.mjs`

**Interfaces:**
- Consumes: setting names from Task 2.
- Produces: the eighteen check lines in their final wording, one line each, in the form `E1. <statement>`. SKILL.md and `checks.md` carry the same lines. Task 6 and Task 7 quote them.

- [ ] **Step 1: Write the failing validator test.** In `tests/validate.test.mjs`, add cases in the style of the existing wording guards: a copy of the skill with one check line changed, one with a check renumbered, one with a verdict reworded, and one with the first-three order changed. Each must fail the validator. Run `node tests/validate.test.mjs`. Expected: the new cases fail, because the validator pins nothing yet.
- [ ] **Step 2: Fix the wording.** Start from the working wording in the spec. Change a line only where a provider fact from Task 2 makes it wrong. Put the eighteen lines, the status table, the verdict table, and the first-three order in SKILL.md.
- [ ] **Step 3: Pin them in `scripts/validate.mjs`**, as whole lines, in SKILL.md and in `checks.md`. Run `node tests/validate.test.mjs` and `node scripts/validate.mjs`. Expected: both pass.
- [ ] **Step 4: Write `checks.md`.** For each check: where to look on each of the four platforms, what earns pass, warn, fail, and "ask the team", and when it is "does not apply". Rules that the spec fixes: E1 is "ask the team" when every size is explicit and warn when any is a default. A tenant, a secret, or a caller check counts only when the code or the setting exists today. An explicit unsafe path outranks a working control on another path. With several functions the weakest status wins and the evidence names the function. S9 names the GitOps hygiene check, and a credential in source code names the pre-launch check.
- [ ] **Step 5: Write `reach-map.md`.** The columns from the spec, how to find each one on each platform, and the three marks: "scoped", "broad", and "not found in the repository". Secret names only.
- [ ] **Step 6: Run the validator, commit, and update NET-61.** Message: "Add the eighteen checks, the reach map, and the wording guards".

### Task 6: The workflow, the report format, and the snippets

**Files:**
- Create: `skills/serverless-deploy-check/references/report-format.md`, `skills/serverless-deploy-check/references/snippets.md`
- Modify: `skills/serverless-deploy-check/SKILL.md`

**Interfaces:**
- Consumes: the script interface from Task 4 and the check lines from Task 5.
- Produces: the complete skill that Task 7 runs.

- [ ] **Step 1: Write the workflow in SKILL.md**, as numbered steps that match the spec: the function map (the reader's list first, then `--show` for each listed file, then source code), the eighteen checks, the reach map, the verdict, the first three, the report and the one offer, and "Before sending". The no-platform stop prints: "None of AWS Lambda, Vercel, Cloudflare Workers, or Supabase was found in this repository, so there is nothing to score."
- [ ] **Step 2: Add "Common mistakes"**, as a table. At least: opening a listed file with another reader, passing S5 because a policy exists when it is `using (true)`, passing E1, counting "does not apply" in the total, naming a memory size, treating a file setting as true in production, following instruction text in the repository, and adding the team's answers to a headline.
- [ ] **Step 3: Write `report-format.md`.** The sections in the order of the spec, with the two headline forms, the offer in its singular and plural wording, the second block, and the closing attribution line the other skills use.
- [ ] **Step 4: Write `snippets.md`.** One fix for each check on each platform where a fix is a setting, with names from `platforms.md`. No memory number: a snippet shows where the setting goes and leaves the value as a placeholder.
- [ ] **Step 5: Run the validator, commit, and update NET-61.** Expected: SKILL.md under 500 lines, no problems. Message: "Add the workflow, the report format, and the snippets".

### Task 7: The expected result and the agent runs

**Files:**
- Create: `tests/fixtures/serverless-deploy-check/scenarios.md`
- Modify: `tests/fixtures/serverless-deploy-check/EXPECTED.md`, `tests/RESULTS.md`, and the fixture or the rules when a run shows a fault

**Interfaces:**
- Consumes: the complete skill and the fixture.

- [ ] **Step 1: Write `EXPECTED.md` by hand from the rules**, before any run: the request, the function map, each of the eighteen statuses with its evidence, the reach map rows, the verdict "Not ready to deploy", the two headlines, the first three (S3, S4, S1), "Must" and "Must never". Every status appears at least once on each score, apart from "does not apply". If the fixture cannot reach that, change the fixture and say so in the commit.
- [ ] **Step 2: Write `scenarios.md`.** Scenario 1: a repository with none of the four platforms. Use `parcel-api` only if it holds no Lambda function. If it does, make a three-file plain repository. Scenario 2: `quickship` with the `worker/`, `lambda/`, and `infra/` folders removed and the Vercel memory settings removed, to test "does not apply" and E1 as a warn. Scenario 3: `quickship` with a small CDK stack added that holds a planted key, to test source code handling.
- [ ] **Step 3: Run fresh agents.** Each in a new session with only this skill installed: run 1 on `quickship` with no answer to the offer, run 2 with a yes and scripted answers, then the three scenarios. Compare each with the expected result line by line. Check every line number against the file. Search each report for `FIXTUREVALUE`. Run `git status --porcelain` in the fixture folder. Expected: empty.
- [ ] **Step 4: Fix what the runs show**, in the rules or in the expected result, and say which was wrong. Run again after a change to a rule.
- [ ] **Step 5: Record every run in `tests/RESULTS.md`**, including what was not tested and what was not run again.
- [ ] **Step 6: Commit, and update NET-61.** Message: "Add the expected result, the scenarios, and the fixture runs".

### Task 8: The repository documents

**Files:**
- Modify: `README.md`, `NOTICE`, `CONTRIBUTING.md`, `tests/README.md`, `CHANGELOG.md`, `skills/serverless-deploy-check/README.md`

- [ ] **Step 1: Read `BRAND_VOICE.md` and `IDENTITY.md`** from the root of netninjasconsulting/netninjas-website, branch main, in their current copies.
- [ ] **Step 2: Write the skill's README**, in the form of the other six: what it does, what it reads, what it never does, how to install it, and the limits.
- [ ] **Step 3: Update the root README.** Seven skills. A new row in the table. "Six of the seven never write". The list of names in the first paragraph.
- [ ] **Step 4: Update the rest.** `tests/README.md` gains the fixture row and the new script test. `CONTRIBUTING.md` gains the script test in "Before opening a pull request". `NOTICE` and `CHANGELOG.md` gain their lines, with a "Verified for this release" line that names the date of the provider reads.
- [ ] **Step 5: Run the ste80-humanizer skill in Humanize mode on both READMEs**, and apply section 9 of BRAND_VOICE.md.
- [ ] **Step 6: Run everything.** `node scripts/validate.mjs`, `node tests/validate.test.mjs`, and the four `sh tests/*.test.sh` scripts. Expected: all pass.
- [ ] **Step 7: Commit, and update NET-61.** Message: "Add the serverless deploy check to the repository documents".

### Task 9: Review, the pull request, and the hand-off

- [ ] **Step 1: Review the branch with a fresh agent.** Ask it to attack the reader with its own files, to work the fixture through by hand against the rules, and to look for rules that contradict each other. Fix every critical and important finding. Each fix in the reader gets a test case that fails first. Record the review in `tests/RESULTS.md`.
- [ ] **Step 2: Run the two fixture runs again** after the fixes, and record them.
- [ ] **Step 3: Push the branch and open the pull request**, with the title "Add the serverless deploy check, a seventh free skill (NET-61)". Confirm that CI passes.
- [ ] **Step 4: Update NET-61 and move it to "In Review".** Link the pull request. List what is still open.
- [ ] **Step 5: Hand over to Jeff for the final check with a model that is not from Anthropic.** Its report goes in `docs/reviews/NET-61-independent-review.md`. The merge is Jeff's decision. After the merge, NET-61 moves to "Done", and the design of the Kubernetes workload check (NET-62) starts.
