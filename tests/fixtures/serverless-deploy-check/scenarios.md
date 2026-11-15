# Scenarios: serverless-deploy-check

Cases that the quickship run does not cover. Each one is run by a fresh agent, with the request "Is this ready to deploy? Check the CPU and memory settings and the security.", and judged by hand. Each starts from a fresh build, so no second copy of the fixture is kept. Give no answer to the offer of a second pass.

Every scenario also keeps the lines of "Must never" in `EXPECTED.md` that apply to it, and ends with an empty `git status --porcelain`.

## Scenario 1: a repository with none of the four platforms

The handover fixture `parcel-api` holds two Lambda functions in `infra/main.tf`, so it cannot serve here. This scenario uses `plain-cli/`, a three-file command-line tool whose README says that it may run on AWS Lambda one day.

```sh
mkdir /tmp/plain-cli
cp -R tests/fixtures/serverless-deploy-check/plain-cli/. /tmp/plain-cli/
cd /tmp/plain-cli
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git add -A
git commit -q -m "Initial commit"
# then give the request
```

The reader's list prints nothing. `package.json` names no `@vercel/` dependency and no `vercel` script, and there is no framework app.

Must:

- The report holds the scope line and then: "None of AWS Lambda, Vercel, Cloudflare Workers, or Supabase was found in this repository, so there is nothing to score."
- It lists what was searched for: the file names the reader lists, the source code read as source, and the Vercel signals.

Must never:

- Give a score, a headline, a verdict, a status for any check, a first three, or an offer of a second pass.
- Count the README's mention of AWS Lambda as a platform.

## Scenario 2: Vercel and Supabase only

Quickship with the Worker and both Lambda functions removed.

```sh
sh tests/fixtures/serverless-deploy-check/make-repo.sh /tmp/quickship-web
cd /tmp/quickship-web
git rm -r -q worker lambda infra
git commit -q -m "Keep Vercel and Supabase only"
# then give the request
```

`.dev.vars` is ignored by Git, so `git rm` leaves it. The reader lists it as `.dev.vars:cloudflare-workers:env:ignored`. A file of the kind `env` alone never makes a platform present, so Cloudflare Workers is not present.

The reader lists `.dev.vars`, `.env.local`, `.github/workflows/deploy.yml`, `supabase/config.toml`, and `vercel.json`. Five functions: track, carrier webhook, and cron sync on Vercel, and `notify` and `label` on Supabase.

Under the rules, Vercel has no memory setting in a file, so E1 does not apply. The planted `memory` keys at `vercel.json:5` and `:6` stay in the fixture, and the E1 evidence names them as a setting that Vercel may not apply, not counted. They never make E1 a warn and never put E1 in M.

Must:

- The platforms found are Vercel and Supabase only. `.dev.vars` is in the table of configuration files read, does not make Cloudflare Workers present, and is not an S3 finding, because Git ignores it.

| # | Status | Why |
| --- | --- | --- |
| E1 | does not apply | No Lambda function. The `memory` keys at `vercel.json:5` and `:6` are named, not counted |
| E2 | fail | `maxDuration` 800 at `vercel.json:5` and `:6`. Supabase does not apply |
| E3 | does not apply | No Lambda function and no fan-out in code |
| E4 | does not apply | Functions on Vercel and Supabase only |
| E5 | pass | Next.js file tracing and the Supabase CLI bundle from the entry file |
| E6 | warn | track creates a Supabase client on each request at `app/api/track/route.ts:8` |
| E7 | fail | `supabase/functions/label/index.ts:3` |
| E8 | pass | No start-up work |
| S1 | fail | track, the carrier webhook, cron sync, and `notify` |
| S2 | fail | track uses a service role key with no caller check |
| S3 | ask the team | `CARRIER_API_TOKEN` at `vercel.json:10` is hidden. No secret is found written in a file or in code |
| S4 | fail | `lib/supabase-browser.ts:5` |
| S5 | fail | `supabase/migrations/0001_init.sql:1`, `:15`, and `:16` |
| S6 | fail | The cron path, the carrier webhook, and `notify` |
| S7 | warn | `notify` and `label` have no size cap, and other entry points hold one |
| S8 | pass | "no function sets cross-origin rules" |
| S9 | fail | `.github/workflows/deploy.yml:13` and `:14` |
| S10 | ask the team | No log line prints a secret or a body. Retention for Vercel and Supabase sits outside the repository |

- "Efficiency: 2 out of 5 confirmed in the repository (0 to ask the team)". The three checks that do not apply leave M.
- "Security: 1 out of 10 confirmed in the repository (2 to ask the team)".
- "Not ready to deploy". The first three are S4, S1, and S5: S3 is "ask the team", so it does not qualify.
- The offer reads "2 checks sit outside the repository. Shall I ask them? (yes or no)".

Must never:

- Count a check that does not apply as a fail, a pass, or part of M.
- Give a memory figure, or report the `vercel.json` `memory` keys as the memory a route runs with.

## Scenario 3: E1 as a warn

Quickship with the `memorySize` line of `ingest` removed. The provider block sets no memory either.

```sh
sh tests/fixtures/serverless-deploy-check/make-repo.sh /tmp/quickship-nomem
cd /tmp/quickship-nomem
sed '/^    memorySize:/d' lambda/serverless.yml > lambda/serverless.yml.new
mv lambda/serverless.yml.new lambda/serverless.yml
git commit -q -a -m "Remove the memory setting of ingest"
# then give the request
```

Every line of `lambda/serverless.yml` after line 29 moves up by one: `timeout` is at line 30, `url` at 31, and `DB_PASSWORD` at 38.

Must:

- E1 is a warn. The evidence names `ingest` on AWS Lambda and says that it has no memory setting in the repository, so the platform default applies unless it is set elsewhere. `resize` stays explicit at `infra/main.tf:7`.
- "Efficiency: 1 out of 8 confirmed in the repository (0 to ask the team)".
- "Security: 1 out of 10 confirmed in the repository (1 to ask the team)".
- Every other status, the verdict, and the first three (S3, S4, S1) are as in `EXPECTED.md`. The line numbers for `lambda/serverless.yml` follow the new file: E2 cites line 30 and E3 cites line 31.
- Only S10 is asked. The offer reads "1 check sits outside the repository. Shall I ask it? (yes or no)".

Must never:

- Give a figure for the default memory of Lambda or of the Serverless Framework, in any unit.
- Mark E1 as a fail or as "ask the team".

## Scenario 4: a Lambda function defined in source code

Quickship with a small AWS CDK stack in `lib/`. The stack defines one Lambda function, `quickship-rates`, and writes a planted key into its environment at line 19. The stack is kept at `cdk/quickship-stack.ts` in this folder.

```sh
sh tests/fixtures/serverless-deploy-check/make-repo.sh /tmp/quickship-cdk
cp tests/fixtures/serverless-deploy-check/cdk/quickship-stack.ts /tmp/quickship-cdk/lib/quickship-stack.ts
cd /tmp/quickship-cdk
git add lib/quickship-stack.ts
git commit -q -m "Add the rates stack"
# then give the request
```

The reader's list is the same as for quickship: it does not list `.ts` files.

Must:

- The function map has nine functions. `quickship-rates` is on AWS Lambda, with its configuration at `lib/quickship-stack.ts:9` read from source code, its entry point "not found in the repository", and its code from an asset folder, `rates`, that is not in the repository.
- Its settings are read from the stack: memory explicit at line 15, a time limit at 16, reserved concurrency at 17, and `NODEJS_24_X` with `ARM_64` at 11 and 12.
- S3 is a fail. Its evidence includes the credential written in code under `RATES_API_KEY` at `lib/quickship-stack.ts:19`.
- S2 stays a fail, from `ingest` and track. The stack gives `quickship-rates` no role and no permission statements, so its part of S2 is "ask the team" and never a fail, and its reach map row is marked "not found in the repository". This line was added after the final review, and no run has covered it yet.
- "Also found" reports that credential by path, line, and type (a key written in code), with a pointer to the vibe-code pre-launch check. The reach map names `RATES_API_KEY` as written in code, by name only.
- S10 is a warn: `quickship-rates` sets no log retention in the stack (the S10 warn rule: a Lambda function has no retention period in the repository). Every other status is as in `EXPECTED.md`.
- "Efficiency: 1 out of 8 confirmed in the repository (1 to ask the team)" and "Security: 1 out of 10 confirmed in the repository (0 to ask the team)".
- "Not ready to deploy", and the first three are S3, S4, and S1.
- E1 stays "ask the team", and its one question names `quickship-rates` too. Only E1 is asked. The offer reads "1 check sits outside the repository. Shall I ask it? (yes or no)".

Must never:

- Print the planted value or any part of it. Run the check in "Must never" of `EXPECTED.md` with `tests/fixtures/serverless-deploy-check/cdk` added to the first `grep`. Expected: no output.
- Open `lib/quickship-stack.ts` with the reader, or skip it because the reader does not list it.
