# Design: Serverless deploy check

Date: 15 November 2026. Status: approved by Jeff on 15 November 2026. Target version: 0.2.0. Linear: NET-61.

## Intent

A seventh free skill, `serverless-deploy-check`. It answers one question for a team that is about to deploy functions to AWS Lambda, Vercel, Cloudflare Workers, or Supabase: "is this deploy sized on purpose, and is it safe to expose?"

The result is two scores from what the repository shows, one for efficiency (CPU, memory, and time) and one for security. It also gives a map of what each function can reach, a verdict, and the first three things to change.

The skills on skills.sh for these platforms are reference guides or deploy helpers for one provider. In one search on 15 November 2026, none read the configuration of all four platforms and scored it. This skill carries the checks I run by hand in the Cloud Cost & Architecture Review and in the Cloud Security Posture & Hardening work, so the report is a free first pass of both.

## Who it is for

- A founder or a lead engineer with an app on one or more of the four platforms, before a launch or a large release.
- A team whose function bill grew and who cannot say which setting caused it.
- A team that built with an AI coding tool and took the platform defaults.

It is not for a team on Kubernetes or on virtual machines. The Kubernetes workload check (NET-62) is a separate skill for a separate reader.

## Goals

1. List every function and every platform configuration file before judging anything, and print the list as the coverage record.
2. Score eight efficiency checks and ten security checks from what the code and the configuration show.
3. Print, for each function, what it can reach: its entry point, its caller check, its permissions, its secret names, and its data stores.
4. Give one verdict, and name the first three things to change.
5. Read every platform configuration file through a bundled reader that hides values, so that no secret reaches the agent or the report.
6. Give a complete result with no network access and no answer to any question.

## Non-goals

- Reading a live cloud account, a provider's console, or a bill.
- Any cost figure, and any memory size as a recommendation. A size needs measured use.
- Reading exported logs or usage data. That is a candidate for a later skill.
- Deciding whether a route belongs at the edge or in a region.
- A full pass for secrets in source code. The pre-launch check does that, and this skill points to it.
- Scoring the pipeline. The GitOps hygiene check does that. This skill has one check on deploy credentials and points to it.
- Running the app, a build, a deploy, or a provider's command-line tool.
- Writing a file. The report is printed in chat.
- Azure Functions, Google Cloud Functions, Netlify, Deno Deploy, and Fly.io in version 1.

## Anti-goals

The skill has failed, even if it runs, when any of these happens:

- A secret value, or part of one, appears in the report, in chat, or in the reader's output.
- A check passes because a README, a comment, or a document says it is met.
- The report states a memory size, a saving, or a cost as if the repository proved it.
- A team's answer is mixed into a score that the code proved.
- A setting in a file is reported as true in production.
- A low score reads as a sales pitch.

## Decisions Jeff made

| Decision | Choice |
| --- | --- |
| Packaging | A separate skill and a separate project from the Kubernetes check. The audiences, the workloads, and the requirements differ. |
| Order of work | The skill first. The Notion page and the website pages follow it (NET-63). |
| Source of the checks | The check list lives in the skill. No takeaway page comes first. |
| How it is built | Approach B below: instructions plus a bundled reader script with its own test in CI. |
| Version | The kit stays at 0.2.0. This skill carries 0.2.0, as the other six do. |
| Final check | Jeff runs a final check of the branch with a model that is not from Anthropic, before the merge. |

## Approaches

**A. Instructions only.** `SKILL.md` and reference files, as in the AI feature architecture check. The agent reads each configuration file and hides values by rule. Rejected: `wrangler.toml`, `serverless.yml`, `vercel.json`, and Terraform variable files often hold secrets in plain `vars` and `environment` blocks, and a rule in a file does not stop a value from reaching the agent's context.

**B. Instructions plus a bundled reader script. Chosen.** The same files, plus one POSIX script that lists the platform configuration files it finds and prints each one with values hidden. CI tests the hiding. The agent opens no platform configuration file any other way. The cost is a reader for four formats (TOML, JSON with comments, YAML, and HCL). The reader of the agent permissions check printed planted credentials in five ordinary layouts during its review, so this one hides by default and is tested against those layouts from the first commit.

**C. One skill for each platform.** Rejected: a real repository mixes platforms, such as Vercel with Supabase, or Workers with Lambda. Four skills would give four verdicts and no single list of what to change first.

## The shape of the skill

### Files

```text
skills/serverless-deploy-check/
  SKILL.md
  README.md
  references/checks.md         evidence rules for the eighteen checks, by platform
  references/platforms.md      files, setting names, defaults, and limits for each platform, each with its date and source
  references/reach-map.md      how to fill the map of what each function can reach
  references/report-format.md
  references/snippets.md       fixes to paste, by platform
  scripts/read-serverless-config.sh
tests/fixtures/serverless-deploy-check/
  quickship/                   the repository under test
  make-repo.sh
  EXPECTED.md
  scenarios.md
tests/read-serverless-config.test.sh
```

### Ground rules

The eight rules every skill in this repository holds to, plus five that are specific to this one:

1. **Configuration is read through the script only.** No `cat`, no editor, and no other reader on a file that the script lists. Source code is read directly. A credential in source code is reported with its path, its line, and its type, never its value.
2. **A pass needs a setting or code that exists today.** A README, a comment, or a variable name never passes a check.
3. **The file is not the running system.** A memory size, a region, or an access rule can be set in a provider's console and not in a file. The report says so at the top.
4. **No size and no figure.** The skill says whether a setting is explicit. It does not say what the setting should be, and it gives no cost.
5. **No platform, no score.** When the repository holds none of the four platforms, the skill says so, lists what it searched for, and stops.

The skill runs nothing from the project and makes no network request.

### The reader script

`scripts/read-serverless-config.sh`, POSIX `sh`, with no dependency beyond `git`, `grep`, `sed`, and `awk`. It writes nothing and makes no network request. It follows `list-agent-config.sh` in structure and in exit codes.

```text
sh read-serverless-config.sh [path]        list platform configuration files in the repository
sh read-serverless-config.sh --show FILE   print FILE with line numbers and values hidden
```

- List output, one line per file: `<path>:<platform>:<kind>:<tracked|untracked|ignored|no-git>`.
- Platform is one of `aws-lambda`, `vercel`, `cloudflare-workers`, `supabase`, or `shared`. Kind is one of `functions`, `infrastructure`, `env`, or `workflow`.
- Files it lists: `wrangler.toml`, `wrangler.json`, `wrangler.jsonc`, `.dev.vars`, `vercel.json`, `serverless.yml`, `serverless.yaml`, SAM and CloudFormation templates (`template.yaml`, `template.yml`, `template.json`, and any YAML or JSON file with an `AWSTemplateFormatVersion` or a `Transform: AWS::Serverless` line), `samconfig.toml`, `*.tf`, `*.tofu`, `*.tfvars`, `supabase/config.toml`, env files, and `.github/workflows/*.yml`.
- **Hiding is the default.** `--show` prints keys and structure. A value is shown only when its key is on a short list of keys that carry a setting and not a secret, such as a memory size, a timeout, a runtime, an architecture, a compatibility date, a route, a schedule, an authentication mode, a binding name, or an IAM action and resource. A shown value still passes through the token-shape filters. Everything else prints as `<redacted>`.
- A value that spans lines, a heredoc, a YAML block scalar, a TOML multi-line string, and a comment are hidden whole.
- Env files and `*.tfvars` print names only.
- A file type the reader does not know is not shown, and the skill reports it under "Not checked".

Infrastructure written in a programming language (AWS CDK, SST, Pulumi, and `next.config.*`) is source code. The agent reads it directly, under ground rule 1.

### Step 1: the function map

The reader's list comes first. Then the skill names each platform that is present, and each function on it, with a path and a line: the entry point (a route, a function URL, a queue, a schedule, or a webhook), the handler file, and the configuration that sets it up. `references/platforms.md` names what to look for. A function that exists only as a file convention, such as a Next.js route handler or a file under `supabase/functions/`, counts as a function.

### Step 2: the eighteen checks

Each check is a statement that should hold. The wording below is the working wording. The final wording is fixed in `SKILL.md` at the build, and the validator pins it from then on, so that a takeaway page can be cut from it later.

**Efficiency**

- E1. Every function sets its memory, and its CPU where the platform has a setting.
- E2. Every function has a time limit that is set on purpose and sits below the platform's maximum.
- E3. Concurrency and fan-out have a ceiling.
- E4. The runtime and the CPU architecture are current.
- E5. The deploy package holds only what the function runs.
- E6. Clients and connections are created once and reused, through a pooler where the database needs one.
- E7. Large request and response bodies are streamed, not held in memory.
- E8. Start-up work is small.

**Security**

- S1. Every public entry point checks who is calling, or is public on purpose.
- S2. Each function's permissions cover only what it uses.
- S3. Secrets live in the platform's secret store, not in configuration or code.
- S4. No server secret reaches the browser bundle.
- S5. The data layer enforces access itself.
- S6. Webhook and scheduled endpoints verify the caller.
- S7. Requests meet a size limit and a rate limit before they cost money.
- S8. Cross-origin rules name their origins.
- S9. Deploys use short-lived credentials.
- S10. Logs leave out secrets and request bodies, and have a retention period.

Each check gets one status.

| Status | Meaning | Points |
| --- | --- | --- |
| pass | Every part of the check is met, with evidence. | 1 |
| warn | Part of the check is met, and the missing part would be in the repository. | 0 |
| fail | The check is not met, or nothing for it is found in the repository. | 0 |
| ask the team | The part that the repository can show is met, and the rest sits outside it. | 0 |
| does not apply | No platform in the repository has this setting. | not counted |

With several functions or several platforms, a check gets the weakest status: fail, then warn, then "ask the team", then pass. The evidence names the function and the platform that earned it.

E1 cannot pass from the repository. An explicit size is "ask the team", because only measured use shows that the size fits. A size left at the platform default is a warn.

The two headlines are "Efficiency: N out of M confirmed in the repository (K to ask the team)" and "Security: N out of M confirmed in the repository (K to ask the team)". M counts the checks that apply.

### Step 3: the reach map

One row for each function: its entry point, how it checks the caller, the permissions it runs with (an IAM role and its statements, Workers bindings, a Supabase key type, or the Vercel environment variables in scope, by name), the secret names it reads, and the data stores it can read or write. Each row is marked "scoped", "broad", or "not found in the repository". The map is the evidence for S1 and S2.

### Step 4: the verdict

| Verdict | Rule |
| --- | --- |
| Not ready to deploy | Any of S1 to S5 is a fail. |
| Ready after the first three | No fail in S1 to S5, and at least one of the eighteen checks is a fail or a warn. |
| Ready from what the repository shows | No fail and no warn. |

The efficiency score does not block a deploy alone. A function that is the wrong size costs money. A function that anyone can call, with a secret in its configuration, loses data.

### Step 5: the first three to change

Up to three checks marked fail or warn, in this order: S3, S4, S1, S5, S2, S6, S7, E3, then the remaining security checks in number order, then the remaining efficiency checks in number order. E3 sits with the security checks because a function with no ceiling and no rate limit lets a stranger run up the bill. When fewer than three qualify, the skill lists those only.

Each of the three comes with the snippet from `references/snippets.md` for the platform it was found on.

### Step 6: the optional second pass

After the report, the skill offers once to ask the checks marked "ask the team". With a yes it asks each one as a yes or no question, then prints one more block: each answer labelled "stated by the team", and two lines of the form "With the team's answers: N out of M". The first headlines and the verdict stay as they were. With no answer, the report is the result.

### Report

Printed in chat: the scope line, the note that a file is not the running system, the verdict, the two headlines, the function map, the eight efficiency checks, the ten security checks, the reach map, the first three to change with their snippets, the questions for the team, "Also found" (instruction text aimed at reviewers, and credentials in source code), "Not checked", and the closing attribution line.

## Tests

- **Baseline first.** One run of the plain request on the fixture with no skill installed, recorded in `tests/RESULTS.md`.
- **Fixture.** `quickship` is a small delivery-tracking product on all four platforms: a Next.js app on Vercel, a Supabase project with migrations and two edge functions, a Cloudflare Worker, and two Lambda functions, one in `serverless.yml` and one in Terraform. It holds planted values in `vars`, `environment`, `.dev.vars`, `*.tfvars`, and `vercel.json`, in single-line, multi-line, quoted, and commented layouts. It also holds a planted instruction to reviewers. The fixture and its scenarios exercise every status at least once: the fixture holds pass, warn, fail, and "ask the team" on both scores, and scenario 2 holds "does not apply", on the efficiency score only. Its expected verdict is "Not ready to deploy".
- **Script test.** `tests/read-serverless-config.test.sh` runs in CI. It fails when any planted value appears in any output, when a planted file is missing from the list, or when an unknown file type is shown. It starts with the five layouts that defeated the first reader of the agent permissions check.
- **Fresh agent runs** against `EXPECTED.md`: one with no answer to the offer, and one with scripted answers, to confirm that the headlines and the verdict stay apart from the team's answers.
- **Scenarios.** A repository with none of the four platforms (the `parcel-api` fixture has AWS services, so the builder confirms that it fits or adds a plain one). A variant of `quickship` with only Vercel and Supabase, to test "does not apply".
- **Independent check.** Jeff runs a final check of the branch with a model that is not from Anthropic. Its report goes in `docs/reviews/NET-61-independent-review.md`, as the reports for NET-52 and NET-53 did.
- **Validator.** `scripts/validate.mjs` pins the eighteen checks in `SKILL.md` and `references/checks.md` to one wording, the status table, the verdict rules, and the order of the first three.

## Changes outside the new skill

- `scripts/validate.mjs`: the checks above.
- `.github/workflows/`: a step for the new script test. The shellcheck step already covers `skills/*/scripts/*.sh`.
- Root `README.md`, `NOTICE`, `CONTRIBUTING.md`, and `tests/README.md` gain the new skill. The README says seven skills, and six of the seven are read-only.
- `CHANGELOG.md` gains this skill's lines under 0.2.0. No version number changes.
- The README is public copy. It follows BRAND_VOICE.md and IDENTITY.md, and it passes through the ste80-humanizer skill and section 9 of BRAND_VOICE.md before the pull request opens.

## Not in this change

- The Notion page and the `/skills` pages on netninjas.us and netninjas.eu (NET-63).
- A takeaway page built from the eighteen checks.
- A step in the guided app starter that runs this check on a new project.
- A pointer to a third-party profiling skill for Workers.
- Reading exported logs to propose a size.
- The Kubernetes workload check (NET-62).

## Calls made by the builder, for Jeff to check

1. Eight efficiency checks and ten security checks, in the working wording above.
2. Five statuses, with "does not apply" left out of the count.
3. E1 cannot pass from the repository. An explicit size is "ask the team".
4. The verdict comes from S1 to S5. Efficiency does not block a deploy alone.
5. The order that picks "the first three to change", with E3 among the security checks.
6. The reader is POSIX shell, as `list-agent-config.sh` is, and not Node.js.
7. The reader covers Serverless Framework, SAM, CloudFormation, Terraform, and OpenTofu. CDK, SST, and Pulumi are read as source code.
8. Workflows are read through the reader, for S9 only.
9. No file is written.
10. The fixture is one repository on all four platforms, named `quickship`.

## Left to the builder

- Every file name, setting name, default, and limit in `references/platforms.md`, read from each provider's current documentation on the build date, dated, linked, and marked "verify" when it cannot be confirmed.
- The list of keys whose values the reader shows.
- The evidence rules for each check on each platform, the final wording of the checks, the wording of the questions for the team, and the snippets.
- The exact contents of the fixture and of `EXPECTED.md`.
