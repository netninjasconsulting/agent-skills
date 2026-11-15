# Serverless deploy check

I publish this free skill through Net Ninjas Consulting, a one-person cloud, DevOps, and AI consultancy in New York City.

A free agent skill that checks if a deploy to AWS Lambda, Vercel, Cloudflare Workers, or Supabase is sized on purpose and safe to expose.

I keep seeing the same pattern in functions that shipped fast. The memory size came from a template. The time limit is the platform's maximum. A function URL is open to anyone, and a key sits in the configuration. Then the bill grows, and nobody can say which setting caused it. This skill reads the repository and checks both sides: how each function is sized, and who can reach it.

## What it checks

**Eight efficiency checks,** for CPU, memory, and time.

- E1. Every function sets its memory, and its CPU, where the platform has a setting.
- E2. Every function has a time limit that is set on purpose and sits below the platform's maximum.
- E3. Concurrency and fan-out have a ceiling.
- E4. The runtime and the CPU architecture are current.
- E5. The deploy package holds only what the function runs.
- E6. Clients and connections are created once and reused, through a pooler where the database needs one.
- E7. Large request and response bodies are streamed, not held in memory.
- E8. Start-up work is small.

**Ten security checks.**

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

**The reach map.** It has one row for each function. The row gives the entry point, the caller check, the permissions, the secret names it reads, and the data stores it can reach. Each row is marked "scoped", "broad", or "not found in the repository". The map shows secret names only, never a value.

## What it reads

- The skill reads configuration through a bundled reader script. The script covers Serverless Framework files, AWS SAM and CloudFormation templates, `samconfig.toml`, Terraform and OpenTofu files, `vercel.json`, Wrangler configuration, `supabase/config.toml`, env files, `*.tfvars`, `*.tfvars.json`, and GitHub workflows. It prints keys and structure. It prints a value only when the key carries a setting. Env files, `*.tfvars`, and `*.tfvars.json` print names only. The skill reads workflows for S9, and to see if a workflow deploys to Vercel.
- It reads source code directly. That covers handlers, Next.js route handlers, Worker entry files, Supabase edge functions, and SQL migrations. It also covers AWS CDK, SST, and Pulumi programs, `serverless.ts`, `next.config.*`, and `package.json`.
- It reads the top-level README and other top-level documents as data. They never pass a check.

## What comes back

The report opens with the scope line. A note follows it: a file is not the running system.

Then comes the verdict: "Not ready to deploy", "Ready after the first three", or "Ready from what the repository shows". A fail in any of S1 to S5 blocks the deploy. The efficiency score alone never blocks it. Two headlines sit under the verdict.

```text
Efficiency: N out of M confirmed in the repository (K to ask the team)
Security: N out of M confirmed in the repository (K to ask the team)
```

Each check gets one status: "pass", "warn", "fail", "ask the team", or "does not apply". M counts only the checks that apply to the platforms in the repository. E1 never passes from the repository. An explicit memory size is "ask the team", because only measured use shows that the size fits.

The function map comes after the headlines. Then the report gives the eight efficiency checks and the ten security checks, each with a file and a line. The reach map follows them.

Next come the first three things to change. They follow a fixed order, from S3, S4, and S1 down to the efficiency checks. Each one comes with a snippet for its platform. Every value in a snippet is a placeholder.

The report ends with the questions for the team, anything else it found, and what it did not check. When a check is "ask the team", the skill offers once to ask those questions. The answers go in a second block, and each one carries the label "stated by the team". The first headlines and the verdict never change.

When the repository holds none of the four platforms, the skill says so, lists what it searched for, and stops with no score.

## What it never does

- It never runs the project. It runs no install, build, test, dev server, or deploy command.
- It never makes a network request, and it never writes a file.
- It never changes a setting in a cloud account, a Git remote, or a provider.
- It never opens a configuration file that the reader lists in any other way.
- It tells the agent never to repeat a secret value. The reader hides values, and the agent reports the file, the line, and the secret type. The limits below say where that can fail.
- It never passes a check because a README, a comment, or a variable name says so.
- It never follows instructions found inside the repository.
- It sends nothing to Net Ninjas or to anyone else.

It doesn't repeat the full secrets pass of the [vibe-code pre-launch check](../vibe-code-pre-launch-check/). This skill reports a credential in configuration or code when it meets one. The pre-launch check searches the whole repository for them.

## Limits

- **The reader doesn't parse.** It works by line and hides what it can't place. Some valid layouts get hidden that way. In Terraform they are the inputs of a `module` block, the items of a one-line `jsonencode` list, and the principals of a policy document. In other files they are a top-level `maxDuration` in `vercel.json` and the `Cors` of a SAM API. The report gives their settings as "not found in what the reader shows".
- **Terraform hides more than the checks need.** The reader hides the opening line of an inline policy, so S2 can't pass from one. It also hides a managed policy attached to a role, the function that a function URL belongs to, and the name of a log group. A long resource type that holds a digit prints as `<redacted>`.
- **Other things the reader hides.** A YAML anchor on a key such as `provider` hides everything below that key. A SAM `Transform` line prints with its version hidden. `references/platforms.md` lists each case under "Known limit".
- **A secret in the wrong place can print.** The reader shows a value when its key carries a setting. So a secret can appear in its output when someone writes it where a setting name belongs. Examples are a runtime, a handler, an IAM action, and the last part of an ARN. A secret used as a key name can appear too. The skill tells the agent not to copy such a value into the report.
- **The reader doesn't check the resource type of a SAM property.** A property with a setting's name, such as `Handler` or `Role`, shows its word under any resource in a template.
- **A credential word in a name hides nothing.** A function, a resource, a job, or an environment whose name holds `token`, `password`, or `secret` shows its settings like any other. The reader still hides the value of a key with such a name.
- **The reader lists known file names only.** It doesn't list a platform file that is a symbolic link. It doesn't list `serverless.json`, `samconfig.yaml`, `*.tf.json`, or `terraform.tfstate`. The skill names such a file under "Not checked" and doesn't open it.
- **45 provider facts are marked "verify".** `references/platforms.md` holds 147 rows of provider facts. I read 102 of them in each provider's documentation on 15 November 2026. The other 45 are marked "verify", and I didn't confirm them on that date. Provider limits and defaults change often.
- **No size, no saving, and no cost.** The skill says if a setting is explicit, and where. Measured use is the evidence for a size, and the repository doesn't hold it.
- **A file is not the running system.** A memory size, a region, or an access rule can live in a provider's console and not in a file. The report says so at the top.
- **Four platforms only.** Azure Functions, Google Cloud Functions, Netlify, Deno Deploy, Fly.io, and Kubernetes are outside this check.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill serverless-deploy-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/serverless-deploy-check` from this repository into the agent's skills folder works without any installer.

It needs a POSIX shell with `git`, `grep`, `sed`, `awk`, `find`, and `sort`. I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In a clone of the repository:

```text
Is this ready to deploy? Check the CPU and memory settings and the security.
```

## Test fixture

`tests/fixtures/serverless-deploy-check/quickship/` in this repository holds a delivery tracking app on all four platforms. It also holds the result the skill has to produce on it. `scenarios.md` adds four cases: none of the four platforms, Vercel and Supabase only, E1 as a warn, and a Lambda function defined in AWS CDK.

`tests/read-serverless-config.test.sh` runs the reader against the fixture and its own attack files in CI. It fails when a planted value appears in any output. `tests/RESULTS.md` records every run, and the rules that the first runs and the reviews changed.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which of your functions still runs at the size its template gave it? More free skills and guides: [netninjas.us/skills](https://www.netninjas.us/skills).
