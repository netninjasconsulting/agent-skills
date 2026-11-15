# Platforms

Files, setting names, defaults, and limits for AWS Lambda, Vercel, Cloudflare Workers, and Supabase. This file is the single source of platform facts for the fixture, the reader script, and the evidence rules in `checks.md`.

**Checked on 15 November 2026.** Each fact below is marked "checked" (read in the provider's own documentation on that date; sources at the end) or "verify" (not read on that date: read the current documentation before relying on it). Provider limits and defaults change often. This file is re-checked at every release of the skill.

Units are the provider's own: Lambda and Cloudflare write "MB" (Cloudflare also writes "MiB"), Vercel writes "GB", and Supabase writes "MB" and "MiB". The pages read do not say whether their "MB" means 1,000,000 or 1,048,576 bytes, so this file copies each figure with the unit as written and never converts one. Binary meaning of "MB": verify.

The skill never states a memory size, a saving, or a cost as advice. The defaults and limits below say what the platform does when a setting is absent or too high. They are not recommendations.

## Contents

1. [How to read the tables](#how-to-read-the-tables)
2. [AWS Lambda](#aws-lambda)
3. [Vercel](#vercel)
4. [Cloudflare Workers](#cloudflare-workers)
5. [Supabase](#supabase)
6. [Setting names for each check](#setting-names-for-each-check)
7. [Files the reader lists](#files-the-reader-lists)
8. [Read as source code](#read-as-source-code)
9. [Keys whose values the reader shows](#keys-whose-values-the-reader-shows)
10. [Not checked in version 1](#not-checked-in-version-1)
11. [Facts that conflict or moved](#facts-that-conflict-or-moved)
12. [Sources](#sources)

## How to read the tables

Each row is one setting or file. The columns are the setting or file, what it controls, its default, its limit, the source id (the address is under "Sources"), the date read, and the status. Every row was read on 15 November 2026 unless its status says "verify".

A "no setting" cell means the pages read show no setting for it on that platform. It is not proof that no setting exists. Where a row says "no setting read", the matching status is "verify".

Source ids: A for AWS and its tools, V for Vercel, C for Cloudflare, B for Supabase.

## AWS Lambda

**Checked on 15 November 2026.** Setting names are given for the four ways a repository sets Lambda: SAM (`AWS::Serverless::Function`), Serverless Framework (`serverless.yml`), the Terraform AWS provider (`aws_lambda_function`), and CloudFormation, which uses the SAM names without the `Serverless` shorthand (CloudFormation property names: verify).

| Setting or file | What it controls | Default | Limit | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| SAM `MemorySize`, Terraform `memory_size`, Serverless `memorySize`, CLI `--memory-size` | Memory of the function, and its CPU in proportion | Lambda and Terraform: 128 MB. Serverless Framework: 1024 MB | 1 MB steps | A1, A9, A13, A17 | 15 Nov 2026 | checked |
| Memory maximum | Largest value the setting accepts | Not applicable | Lambda guide: 10,240 MB. CreateFunction API and Terraform page: 32,768 MB. The pages disagree | A1, A9, A13 | 15 Nov 2026 | verify |
| CPU | Not a separate setting | Not applicable | One vCPU at 1,769 MB | A1 | 15 Nov 2026 | checked |
| SAM `EphemeralStorage`, Terraform `ephemeral_storage.size` | Size of `/tmp` | 512 MB | 512 to 10,240 MB | A9, A10, A13 | 15 Nov 2026 | checked |
| SAM `Timeout`, Terraform `timeout`, Serverless `timeout`, CLI `--timeout` | Time limit of one invocation | Lambda, SAM, Terraform: 3 seconds. Serverless Framework: 6 seconds | 1 to 900 seconds | A2, A8, A13, A17 | 15 Nov 2026 | checked |
| SAM `Architectures`, Terraform `architectures`, Serverless `architecture`, CLI `--architectures` | CPU architecture | `x86_64` | Values `x86_64` or `arm64`; one value only | A4, A8, A9, A13, A17 | 15 Nov 2026 | checked |
| SAM `Runtime`, Terraform `runtime`, Serverless `runtime` (provider or function) | Language runtime. Required for `Zip` packages | None | See the runtime table below | A3, A8, A13, A17 | 15 Nov 2026 | checked |
| SAM `PackageType`, Terraform `package_type` | `Zip` or `Image` | `Zip` | Image: 10 GB uncompressed | A8, A10, A13 | 15 Nov 2026 | checked |
| SAM `RuntimeManagementConfig` (`UpdateRuntimeOn`: `Auto`, `FunctionUpdate`, `Manual`) | When the runtime version updates | Not stated | Not applicable | A8 | 15 Nov 2026 | checked |
| SAM `ReservedConcurrentExecutions`, Terraform `reserved_concurrent_executions`, Serverless `reservedConcurrency`, CLI `put-function-concurrency` | Maximum concurrent executions of this function, and a share held for it | Terraform: `-1`, which means unreserved. `0` stops all invocations | Account default 1,000 per Region. Lambda keeps 100 unreserved | A6, A8, A13, A17, A28 | 15 Nov 2026 | checked |
| SAM `ProvisionedConcurrencyConfig` (needs `AutoPublishAlias`), Serverless `provisionedConcurrency` | Pre-initialised environments | None | Not applicable | A6, A8, A17 | 15 Nov 2026 | checked |
| Terraform provisioned concurrency resource name | Same | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| Serverless `sqs` event `maximumConcurrency`, `batchSize` | Concurrency of a queue consumer | Not stated | Not applicable | A18 | 15 Nov 2026 | checked |
| SAM SQS event concurrency setting | Same | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| Concurrency scaling | How fast Lambda adds environments | Not applicable | 1,000 environments every 10 seconds for each function. Requests per second capped at 10 times the account concurrency | A28 | 15 Nov 2026 | checked |
| SAM `FunctionUrlConfig` (`AuthType`, `Cors`, `InvokeMode`), Terraform `aws_lambda_function_url` (`authorization_type`, `cors`, `invoke_mode`), Serverless `url` | A public HTTPS address for the function | No URL unless configured. Serverless `url: true` makes a public URL with no CORS. `InvokeMode` defaults to `BUFFERED` | `AuthType` values `AWS_IAM` or `NONE` | A5, A12, A14, A17, A23 | 15 Nov 2026 | checked |
| Serverless `url.authorizer: aws_iam` | IAM sign-in on the function URL | None set | Not applicable | A17 | 15 Nov 2026 | checked |
| Resource policy for `AuthType` `NONE`: `lambda:InvokeFunctionUrl` with `lambda:FunctionUrlAuthType`, and `lambda:InvokeFunction` with `lambda:InvokedViaFunctionUrl`; Terraform `aws_lambda_permission` (`function_url_auth_type`, `invoked_via_function_url`) | Whether the public can call the URL | Console and SAM create the policy. CLI and CloudFormation need it added by hand | Without both permissions the caller gets 403 | A5, A16 | 15 Nov 2026 | checked |
| Function URL CORS: `AllowOrigins`, `AllowMethods`, `AllowHeaders`, `ExposeHeaders`, `AllowCredentials`, `MaxAge`; Terraform `cors` block with lower-case names; Serverless `url.cors` with `allowedOrigins` and the rest | Cross-origin rules of the URL | `MaxAge` 5. Console with CORS on allows all origins. `*` means every origin | Terraform `max_age` up to 86,400 | A12, A14, A17 | 15 Nov 2026 | checked |
| Serverless `provider.httpApi.authorizers` (`type: jwt` with `issuerUrl`, `audience`; `type: request`), event `httpApi.authorizer` (`name`, `scopes`, or `type: aws_iam`) | Caller check on an HTTP API | None | Not applicable | A21 | 15 Nov 2026 | checked |
| Serverless `provider.httpApi.cors`, `provider.httpApi.disableDefaultEndpoint` | CORS rules and the default `execute-api` address | Not stated | Not applicable | A21 | 15 Nov 2026 | checked |
| Serverless `http` event: `authorizer` (`name`, `arn`, `type`), `private` (needs an API key), `cors` (`origin`, `origins`, `headers`, `allowCredentials`) | Caller check on a REST API | Not stated | Not applicable | A22 | 15 Nov 2026 | checked |
| Serverless `provider.apiGateway.usagePlan` (`throttle.burstLimit`, `throttle.rateLimit`, `quota`), `provider.apiGateway.apiKeys` | Rate limit and quota on a REST API | Not stated | Not applicable | A18, A22 | 15 Nov 2026 | checked |
| API Gateway account throttle | Account-wide request rate | Not applicable | 10,000 requests per second with a burst bucket of 5,000. 2,500 and 1,250 in 13 Regions | A29 | 15 Nov 2026 | checked |
| API Gateway payload limit and integration timeout | Size and time limits | Not applicable | Not on the page read | A29 | 15 Nov 2026 | verify |
| SAM `Api` and `HttpApi` event properties (`Auth`, `MethodSettings`, usage plan) | Caller check and throttling in SAM | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| Invocation payload | Request and response size | Not applicable | Synchronous: 6 MB each. Asynchronous: 1 MB. Streamed response: 200 MB, with bandwidth uncapped for the first 6 MB and 2 MBps after | A10, A11 | 15 Nov 2026 | checked |
| `InvokeMode` `RESPONSE_STREAM` (SAM, Terraform `invoke_mode`, Serverless `url.invokeMode`) | Streams the response | `BUFFERED` | Node.js managed runtimes support streaming natively; other languages need a custom runtime or the Lambda Web Adapter | A11, A14, A17, A23 | 15 Nov 2026 | checked |
| Node.js handler wrapper `awslambda.streamifyResponse` | Code side of streaming | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| Serverless `package` (`patterns`, `individually`, `artifact`, `excludeDevDependencies`), SAM `CodeUri` and `Layers`, Terraform `filename` and `layers` | What goes into the deploy package | Serverless packages the service directory and excludes `.git/**`, `.serverless/**`, `.DS_Store`, and the config file. Dev dependencies are excluded by default | 50 MB zipped by API or SDK upload; 250 MB unzipped with layers; 5 layers | A10, A13, A20, A26 | 15 Nov 2026 | checked |
| SAM `Environment.Variables`, Terraform `environment.variables`, Serverless `environment` | Environment variables of the function | None | 4 KB in total. Serverless merges provider and function values; function wins | A9, A17, A27 | 15 Nov 2026 | checked |
| SAM `KmsKeyArn`, Terraform `kms_key_arn` | Customer managed key for environment variables | AWS owned or managed key | Not applicable | A9, A13, A27 | 15 Nov 2026 | checked |
| Secrets Manager reference for secrets | Where a secret should live | Not applicable | The Lambda guide recommends Secrets Manager over environment variables and does not mention Parameter Store | A27 | 15 Nov 2026 | checked |
| Serverless `${ssm:...}` and `${secretsmanager:...}` reference syntax | Resolves a secret at deploy time | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| SAM `Role` and `Policies`; `PermissionsBoundary` | Execution role of the function | If `Role` is omitted SAM creates one. `Policies` is appended to it and ignored when `Role` is set | Not applicable | A8 | 15 Nov 2026 | checked |
| Terraform `role` (required ARN of the execution role) | Same | None | Not applicable | A13 | 15 Nov 2026 | checked |
| Serverless `provider.iam.role.statements` (`Effect`, `Action`, `Resource`), `provider.iam.role.managedPolicies`, `provider.iam.role.mode` (`shared` or `perFunction`), `functions.<name>.iam.role.statements`, `functions.<name>.iam.inheritStatements`, `functions.<name>.role` | Execution role statements | One shared role for all functions unless set otherwise. It gets CloudWatch Logs access by default | Not applicable | A19 | 15 Nov 2026 | checked |
| Terraform and CloudFormation IAM resource and property names (`aws_iam_role`, `aws_iam_role_policy`, `Statement`, `Effect`, `Action`, `Resource`) | Permissions in a template | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| Terraform `aws_cloudwatch_log_group` (`name`, `retention_in_days`, `kms_key_id`, `log_group_class`), Serverless `logRetentionInDays`, `logs.lambda` | Log retention and log format | `retention_in_days`: default not stated on the page. `0` keeps events for ever | Valid values: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0 | A15, A17, A18 | 15 Nov 2026 | checked |
| SAM `LoggingConfig`, Terraform `logging_config` (`log_format` `Text` or `JSON`, `application_log_level`, `system_log_level`, `log_group`) | Log format and level | None | Not applicable | A8, A13 | 15 Nov 2026 | checked |
| SAM `Tracing` (`Active`, `Disabled`, `PassThrough`), Terraform `tracing_config.mode` | X-Ray tracing | Not stated | Not applicable | A8, A13 | 15 Nov 2026 | checked |
| SAM `VpcConfig`, Terraform `vpc_config` (`subnet_ids`, `security_group_ids`), Serverless `vpc` | Network placement | None | Not applicable | A8, A13, A18 | 15 Nov 2026 | checked |
| RDS Proxy for connection reuse | Database connection pool for functions | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| SAM `SnapStart` (appears in the `Globals` list) | Start-up snapshot | Not applicable | Not applicable | A26 (name only) | 15 Nov 2026 | verify |
| SAM `Globals.Function` | Values every function inherits: `MemorySize`, `Timeout`, `Runtime`, `Architectures`, `Environment`, and others. A function may change a value but not remove it | Not applicable | Maps merge, lists add, simple values are replaced | A26 | 15 Nov 2026 | checked |
| SAM template marker | Tells a SAM template from other YAML | Not applicable | The spec's marker is a `Transform: AWS::Serverless` line. The exact transform value (`AWS::Serverless-2016-10-31`) was not read | Not read | 15 Nov 2026 | verify |
| CloudFormation marker `AWSTemplateFormatVersion` | Tells a CloudFormation template | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| `samconfig.toml`: `version = 0.1`, tables `[<env>.<command>.parameters]`, keys `stack_name`, `capabilities`, `confirm_changeset`, `resolve_s3`, `parameter_overrides` | Deploy parameters. `parameter_overrides` can hold values | Environment `default` | Not applicable | A25 | 15 Nov 2026 | checked |
| SDK in the runtime | Which AWS SDK the runtime includes | Node.js 22, 24, and 26 include the AWS SDK for JavaScript v3, in a minor version that depends on the runtime and Region | Not applicable | A7 | 15 Nov 2026 | checked |
| SDK in the Python runtime | Same | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| GitHub Actions `aws-actions/configure-aws-credentials`: `role-to-assume`, `aws-region`, workflow `permissions: id-token: write`; static keys `aws-access-key-id`, `aws-secret-access-key` | How a workflow signs in to AWS | Not applicable | The action's README recommends OIDC because it gives temporary credentials | A24 | 15 Nov 2026 | checked |

### Lambda runtimes

Dates are forecasts that AWS says can change. "Deprecation" is the date AWS stops security patches. "Block create" and "block update" are the dates AWS stops those calls. All rows read on 15 November 2026 from A3, status checked.

Supported on 15 November 2026:

| Name | Identifier | Deprecation | Block create | Block update |
| --- | --- | --- | --- | --- |
| Node.js 26 | `nodejs26.x` | Not scheduled | Not scheduled | Not scheduled |
| Node.js 24 | `nodejs24.x` | 30 Apr 2028 | 1 Jun 2028 | 1 Jul 2028 |
| Node.js 22 (re-read 15 Nov 2026: matches the page, but it looks irregular beside Node.js 20 and 24, so verify before quoting) | `nodejs22.x` | 30 May 2027 | 29 Jul 2027 | 31 Aug 2027 |
| Python 3.15 | `python3.15` | Not scheduled | Not scheduled | Not scheduled |
| Python 3.14 | `python3.14` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Python 3.13 | `python3.13` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Python 3.12 | `python3.12` | 31 Oct 2028 | 30 Nov 2028 | 10 Jan 2029 |
| Python 3.11 | `python3.11` | 30 Jun 2027 | 29 Jul 2027 | 31 Aug 2027 |
| Java 25 | `java25` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Java 21 | `java21` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Java 17 | `java17.al2023` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Java 17 (older base) | `java17` | 30 Jun 2027 | 29 Jul 2027 | 31 Aug 2027 |
| Java 11 | `java11.al2023` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Java 11 (older base) | `java11` | 30 Jun 2027 | 29 Jul 2027 | 31 Aug 2027 |
| Java 8 | `java8.al2023` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |
| Java 8 (older base) | `java8.al2` | 30 Jun 2027 | 29 Jul 2027 | 31 Aug 2027 |
| .NET 10 | `dotnet10` | 14 Nov 2028 | 14 Dec 2028 | 15 Jan 2029 |
| Ruby 4.0 | `ruby4.0` | 31 Mar 2029 | 30 Apr 2029 | 31 May 2029 |
| Ruby 3.4 | `ruby3.4` | 31 Mar 2028 | 30 Apr 2028 | 31 May 2028 |
| Ruby 3.3 | `ruby3.3` | 31 Mar 2027 | 29 Jul 2027 | 31 Aug 2027 |
| OS-only runtime | `provided.al2023` | 30 Jun 2029 | 31 Jul 2029 | 31 Aug 2029 |

Already deprecated on 15 November 2026 (the most recent ones; the page lists older identifiers too, all deprecated):

| Name | Identifier | Deprecation | Block create | Block update |
| --- | --- | --- | --- | --- |
| .NET 8 | `dotnet8` | 10 Nov 2026 | 29 Jul 2027 | 31 Aug 2027 |
| .NET 9 (container only) | `dotnet9` | 10 Nov 2026 | Not applicable | Not applicable |
| Python 3.10 | `python3.10` | 31 Oct 2026 | 29 Jul 2027 | 31 Aug 2027 |
| OS-only runtime | `provided.al2` | 31 Jul 2026 | 29 Jul 2027 | 31 Aug 2027 |
| Node.js 20 | `nodejs20.x` | 30 Apr 2026 | 29 Jul 2027 | 31 Aug 2027 |
| Ruby 3.2 | `ruby3.2` | 31 Mar 2026 | 29 Jul 2027 | 31 Aug 2027 |
| Python 3.9 | `python3.9` | 15 Dec 2025 | 29 Jul 2027 | 31 Aug 2027 |
| Node.js 18 | `nodejs18.x` | 1 Sep 2025 | 29 Jul 2027 | 31 Aug 2027 |

Identifiers older than these (`nodejs16.x`, `nodejs14.x`, `nodejs12.x`, `python3.8`, `python3.7`, `python2.7`, `dotnet6`, `dotnetcore3.1`, `go1.x`, `ruby2.7`, `java8`, `provided`, and earlier) are deprecated, and AWS lists their dates on the same page. A runtime identifier that is on neither list is "verify".

## Vercel

**Checked on 15 November 2026.** Vercel documents the path of a setting in three places: function code, `vercel.json`, and the dashboard. Code wins over `vercel.json`, which wins over the dashboard, which wins over Fluid defaults (V3).

| Setting or file | What it controls | Default | Limit | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Function memory and CPU | Memory of a function, and its CPU with it. Set in the dashboard under "Function CPU". Not settable in `vercel.json`: Vercel warns at build time | 2 GB with 1 vCPU ("Standard"). Pro and Enterprise can choose "Performance": 4 GB with 2 vCPUs. Hobby is fixed at 2 GB | Hobby 2 GB; Pro and Enterprise 4 GB | V2, V3, V9 | 15 Nov 2026 | checked |
| `memory` key in `vercel.json` `functions` when Fluid compute is off | Memory | Not applicable | Not applicable | V8 says it is not settable with Fluid; V9 says it cannot be set. Behaviour with Fluid off was not read | 15 Nov 2026 | verify |
| Projects created before 8 Nov 2019 | Older memory defaults | Hobby 1024 MB with 0.6 vCPU; Pro and Enterprise 3008 MB with 1.67 vCPU | Not applicable | V9 | 15 Nov 2026 | checked |
| `maxDuration`: `vercel.json` `functions.<glob>.maxDuration` (integer seconds, or `"max"`), route file `export const maxDuration`, Pages `export const config = { maxDuration }`, framework adapters, dashboard "Default Max Duration" | Time limit of one invocation | 300 seconds on every plan with Fluid compute | Hobby 300 seconds. Pro and Enterprise 800 seconds, and 1800 seconds as an extended beta set per function. Over the limit returns 504 `FUNCTION_INVOCATION_TIMEOUT` | V1, V2, V3, V8 | 15 Nov 2026 | checked |
| Defaults and limits with Fluid compute off | Same | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| `fluid` in `vercel.json`, "Fluid Compute" in the dashboard | Fluid compute, with optimised concurrency (Node.js and Python), bytecode caching, and `waitUntil` | On by default for new projects since 23 Apr 2025 | Not applicable | V3, V8 | 15 Nov 2026 | checked |
| Concurrency | How many invocations run at once | Auto-scales | Up to 30,000 on Hobby and Pro, and 100,000 or more on Enterprise | V2 | 15 Nov 2026 | checked |
| Per-function concurrency ceiling setting | Cap on invocations at once | Not applicable | No setting found on the pages read | V2 | 15 Nov 2026 | verify |
| `regions` in `vercel.json`, `functions.<glob>.regions`, `functionFailoverRegions` (Enterprise) | Where functions run | `iad1` | Hobby one Region; Pro up to three; Enterprise all | V2, V3, V8 | 15 Nov 2026 | checked |
| `includeFiles`, `excludeFiles` in `vercel.json` `functions`; for Next.js use `outputFileTracingIncludes` and `outputFileTracingExcludes` in `next.config.*` | What goes into the function bundle | Not applicable | 250 MB uncompressed (500 MB for Python). "Large functions" beta up to 5 GB with `VERCEL_SUPPORT_LARGE_FUNCTIONS` | V2 | 15 Nov 2026 | checked |
| Request and response body | Size of a body | Not applicable | 4.5 MB each. Streamed responses are exempt from the response limit. Over the limit returns 413 `FUNCTION_PAYLOAD_TOO_LARGE` | V2 | 15 Nov 2026 | checked |
| File descriptors | Open files and connections | Not applicable | 1,024 shared across concurrent executions | V2 | 15 Nov 2026 | checked |
| Edge runtime | A function on the Edge runtime | Not applicable | Must begin a response within 25 seconds, and can stream for up to 300 seconds | V2 | 15 Nov 2026 | checked |
| `crons` in `vercel.json`: array of `{ "path", "schedule" }`. `path` must start with `/` (up to 512 characters); `schedule` is a cron expression (up to 256 characters) | Scheduled calls to a route. Legacy: Vercel says Cron Jobs "will be migrated to Schedules" | Not applicable | Hobby: once a day, anywhere in the hour. Runs on production deployments only. No retry. Delivery is best effort, so a run can be missed or repeated | V4, V6, V8 | 15 Nov 2026 | checked |
| Cron verification: project environment variable `CRON_SECRET` (random, 16 characters or more). Vercel sends `Authorization: Bearer <CRON_SECRET>`, `user-agent: vercel-cron/1.0`, and `x-vercel-cron-schedule` | How a cron request is verified. Without the check the path is public | Not set | Not applicable | V4, V5 | 15 Nov 2026 | checked |
| `schedules` in `vercel.json`: a map keyed by name, each with `schedule`, and one target (`path` with `requestMethod`, `function`, or `topic`), plus `timezone` and `jitter` | Vercel Schedules, the successor to cron jobs. A `path` target sends `POST` by default and uses `CRON_SECRET`. A `function` target has no public URL and needs no secret (`handleSchedule`, trigger `schedule/v1beta` in `functions.<file>.experimentalTriggers`). Both `crons` and `schedules` for one route run it twice | `requestMethod` `POST`; timezone UTC | Hobby: at most once every 15 minutes | V5, V6 | 15 Nov 2026 | checked |
| Schedules release status ("public beta") | Whether a team should rely on it | Not applicable | Not applicable | Seen only as a changelog link title | 15 Nov 2026 | verify |
| `headers` in `vercel.json`: array of `{ source, headers: [{ key, value }], has, missing }` | Response headers, including cross-origin headers | Not applicable | Not applicable | V8 | 15 Nov 2026 | checked |
| Environment scopes | Where a variable applies: Production, Preview (all branches or one branch), Development, and custom environments such as `staging` | Not applicable | Not applicable | V7, V10 | 15 Nov 2026 | checked |
| Variable type: Config (readable after saving) or Secret (write-only). Older "Sensitive" variables count as Secret. CLI `vercel env add NAME --sensitive` | Whether a value can be read back | Not applicable | A Secret of 32 characters or more is redacted in build logs. Secrets are now allowed in Development | V7, V10 | 15 Nov 2026 | checked |
| Team policy "Separate Production Secret Values" | Production secret must differ from other environments | Off | Not applicable | V7 | 15 Nov 2026 | checked |
| `NEXT_PUBLIC_` prefix (Next.js) | Names that Next.js inlines into the browser bundle at build time. Names without the prefix stay on the server. `process.env[varName]` lookups are not inlined | Not applicable | Values are frozen at build time | V11 | 15 Nov 2026 | checked |
| Env files `.env`, `.env.local`, `.env.<NODE_ENV>`, `.env.<NODE_ENV>.local`, `.env.test`; Vercel CLI writes `.vercel/.env.<environment>.local` | Local variable files. Next.js says they are almost never committed | Not applicable | Not applicable | V10, V11 | 15 Nov 2026 | checked |
| Firewall (WAF): dashboard custom rules, IP blocking, rate limiting, managed rulesets | Rate limit and block rules ahead of a function | On every plan | Custom rules: Hobby 3, Pro 40, Enterprise 250. Rate limiting counts in fixed windows (Enterprise may use token bucket) | V12 | 15 Nov 2026 | checked |
| Firewall rules in `vercel.json`; the Rate Limiting SDK | Rules and limits in a file or in code | Not applicable | Not applicable | Seen only as a changelog and page title | 15 Nov 2026 | verify |
| `bunVersion` in `vercel.json` (`"1.x"` or `"1.4.x"`, beta) | Bun runtime | Not applicable | Not applicable | V8 | 15 Nov 2026 | checked |
| Node.js and Python versions Vercel supports, and where the version is set | Runtime currency | Not applicable | The extended-duration beta lists `nodejs22.x`, `nodejs24.x`, `nodejs26.x`, `python3.12`, `python3.13`, and `python3.14`. The full list was not read | V1 | 15 Nov 2026 | verify |
| CPU architecture | Whether the platform has a setting | Not applicable | No setting read | Not read | 15 Nov 2026 | verify |
| Log retention | How long runtime logs are kept | Not applicable | Not read | Not read | 15 Nov 2026 | verify |
| `vercel.ts` (programmatic configuration with `@vercel/config`) | Same settings written in TypeScript | Not applicable | Not applicable | Seen only as a link title | 15 Nov 2026 | verify |
| Deploy credentials in a workflow: `VERCEL_TOKEN` as a bearer token for the REST API; `VERCEL_OIDC_TOKEN` as a system variable in builds | How a pipeline signs in to Vercel | Not applicable | Not applicable | V7 (names only) | 15 Nov 2026 | verify |
| Deployment Protection | Who can open a preview or production URL | Not applicable | Not applicable | Seen only as a search-result title | 15 Nov 2026 | verify |
| Background work: `waitUntil`, Cron Jobs, Queues, Workflows | Work after the response | Not applicable | Not applicable | V3 (`waitUntil`), V5 (queues) | 15 Nov 2026 | checked |

## Cloudflare Workers

**Checked on 15 November 2026.** Cloudflare recommends `wrangler.jsonc` for new projects (C1). Some newer features need a JSON configuration file.

| Setting or file | What it controls | Default | Limit | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `wrangler.jsonc`, `wrangler.json`, `wrangler.toml` | The Worker's configuration. JSON support arrived in Wrangler 3.91.0 | Not applicable | Not applicable | C1 | 15 Nov 2026 | checked |
| `name`, `main`, `account_id`, `compatibility_date`, `compatibility_flags` (such as `nodejs_compat`) | Identity, entry point, and the runtime behaviour version | Not applicable | Cloudflare's guide: set the date to today on new projects, and update it from time to time | C1, C6 | 15 Nov 2026 | checked |
| Behaviour when `compatibility_date` is absent | The date Workers assume | Not read | Not applicable | Not read | 15 Nov 2026 | verify |
| `vars` | Plain variables, visible in the config file and in Wrangler and the dashboard. The page says never to put sensitive values in `vars` | None | 64 variables Free, 128 Paid, 5 KB each. `vars` is not inherited by `env.<name>` | C1, C2, C3, C4, C8 | 15 Nov 2026 | checked |
| Secrets: `wrangler secret put NAME`, dashboard "Variables and Secrets", `secrets.required` (names that must exist) | Encrypted values, hidden after they are set. Per Worker, and not inherited by an environment | Not applicable | Not applicable | C3, C4, C8 | 15 Nov 2026 | checked |
| `secrets_store_secrets` binding (Cloudflare Secrets Store, beta) | Account-wide secrets | Not applicable | Not applicable | C1, C4 | 15 Nov 2026 | checked |
| Local files `.dev.vars`, `.dev.vars.<env>`, `.env`, `.env.local`, `.env.<env>`, `.env.<env>.local` | Local secrets, beside the Wrangler config. Use `.dev.vars` or `.env`, not both. Cloudflare says to add `.dev.vars*` and `.env*` to `.gitignore` | Not applicable | Not applicable | C3 | 15 Nov 2026 | checked |
| Memory | Memory of the isolate. No setting | 128 MB, Free and Paid | 128 MB | C2 | 15 Nov 2026 | checked |
| `limits.cpu_ms` | CPU time of one invocation (CPU, not elapsed time) | Free: 10 ms, not configurable. Paid: 30,000 ms | Paid: up to 300,000 ms | C1, C2 | 15 Nov 2026 | checked |
| Elapsed time | Time an HTTP request may last | Not applicable | No limit for HTTP requests. Cron Triggers, Durable Object alarms, and Queue consumers: 15 minutes | C2 | 15 Nov 2026 | checked |
| Subrequests and connections | Calls a Worker makes | Not applicable | Subrequests: 50 Free, 10,000 Paid (raisable). Simultaneous open connections: 6 per request | C2 | 15 Nov 2026 | checked |
| Concurrency ceiling | Number of Worker invocations at once | Not applicable | No setting read. The `ratelimits` binding and WAF rules limit callers, not concurrency | C2, C5 | 15 Nov 2026 | verify |
| Worker size, uncompressed | Size of the script | Not applicable | 64 MiB on both plans | C2 | 15 Nov 2026 | checked |
| Worker size, compressed | Size of the script | Not applicable | Not stated clearly on the page read | C2 | 15 Nov 2026 | verify |
| Request body size | Size of an incoming body | Tied to the zone's Cloudflare plan, not the Workers plan | Free 100 MB, Pro 100 MB, Business 200 MB, Enterprise up to 5 GB | C2 | 15 Nov 2026 | checked |
| `routes` or `route`, `workers_dev` (boolean), `triggers.crons` | Where the Worker is reachable, and its schedules | A `workers.dev` address is assigned on creation. Adding `routes` without `workers_dev` sets it to false on the next deploy | Cron Triggers per account: Free 5, Paid 250 | C1, C2, C9 | 15 Nov 2026 | checked |
| `workers_dev = false` | Turns off the `workers.dev` address. It does not turn off Version, Preview, or Deployment URLs. A dashboard-only change is reversed by the next Wrangler deploy | Not stated when absent | Not applicable | C9 | 15 Nov 2026 | checked |
| `preview_urls` | Preview URLs | Not applicable | Not applicable | Not on the page read | 15 Nov 2026 | verify |
| `env.<name>` blocks | Environments. Inherited: `name`, `main`, `compatibility_date`, `compatibility_flags`, `account_id`, `workers_dev`, `routes`, `triggers`, `limits`, `observability`, `assets`, `placement`, `logpush`. Not inherited, so each must be repeated: `vars`, `kv_namespaces`, `r2_buckets`, `durable_objects`, `queues`, `services`, `vectorize`, `workflows`, `secrets`, `secrets_store_secrets`, `define`. Deployed name is `<name>-<env>` | Without `--env` the top level is used | Not applicable | C1, C8 | 15 Nov 2026 | checked |
| Bindings: `kv_namespaces`, `r2_buckets`, `d1_databases`, `durable_objects`, `queues`, `services`, `vectorize`, `hyperdrive`, `ai` (`binding`; one per project), `analytics_engine_datasets`, `send_email`, `browser`, `images` | What the Worker can reach. A binding is the Worker's permission to a named resource | Not applicable | Not applicable | C1 | 15 Nov 2026 | checked |
| Read-only or scoped binding modes | Whether a binding can be narrowed to read-only | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| `assets`: `directory`, `binding`, `run_worker_first` (boolean or a list of patterns, up to 100) | Static files served with the Worker | `run_worker_first` false | Not applicable | C1 | 15 Nov 2026 | checked |
| `ratelimits` entries: `name`, `namespace_id`, `simple.limit`, `simple.period` | Rate limit binding. Limits count per Cloudflare location and are eventually consistent, so they can be exceeded | Not applicable | `period` is 10 or 60 seconds | C5 | 15 Nov 2026 | checked |
| `hyperdrive` entries: `binding`, `id`, `localConnectionString` | Connection pool to a remote PostgreSQL or MySQL database. `localConnectionString` can hold credentials | Not applicable | Not applicable | C7 | 15 Nov 2026 | checked |
| `observability`: `enabled`, `head_sampling_rate`, `logs.invocation_logs`; `logpush` | Workers Logs | `enabled`: on for new Workers, off for existing ones. `head_sampling_rate` 1 (all requests). `invocation_logs` on | Retention 3 days Free, 7 days Paid. Free: 200,000 events a day. A log entry over 256 KB is truncated | C10 | 15 Nov 2026 | checked |
| `placement` | Where the Worker runs | Not applicable | Value names were not read | C1 (name only) | 15 Nov 2026 | verify |
| `upload_source_maps` | Whether source maps are uploaded | Unset: uploaded, and unresolved maps are skipped (from Wrangler 4.150.0) | Not applicable | C1 | 15 Nov 2026 | checked |
| Streaming bodies | Cloudflare's guide: pipe request and response bodies through; do not buffer with `text()` or `arrayBuffer()`, because memory is 128 MB | Not applicable | Not applicable | C6 | 15 Nov 2026 | checked |
| Global state | Cloudflare's guide: no request data in module-level variables. With Hyperdrive create a new client per request and let Hyperdrive pool | Not applicable | Not applicable | C6, C7 | 15 Nov 2026 | checked |
| WAF rate limiting rules | Dashboard rules ahead of a Worker | Not applicable | Not applicable | Seen only as a search-result title | 15 Nov 2026 | verify |
| Caller check on a route (Cloudflare Access, or code) | Who may call a Worker | Not applicable | No setting read. A Worker on a public route or `workers.dev` address is reachable unless its code checks the caller (the second half is inferred, not read) | Not read | 15 Nov 2026 | verify |
| Cross-origin rules | CORS | Not applicable | No setting read. Set in code | Not read | 15 Nov 2026 | verify |
| CPU architecture | Whether the platform has a setting | Not applicable | No setting read | Not read | 15 Nov 2026 | verify |
| Deploy credential `CLOUDFLARE_API_TOKEN` in a workflow | How a pipeline signs in to Cloudflare | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |

## Supabase

**Checked on 15 November 2026.** Supabase has no one function resource. Edge Functions live in `supabase/functions/<name>/`, and `supabase/config.toml` holds the project and per-function settings (B1, B3).

| Setting or file | What it controls | Default | Limit | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `[functions.<name>]` in `supabase/config.toml`: `verify_jwt`, `import_map`, `entrypoint`, `static_files` | Per-function settings. `entrypoint` is a path relative to `config.toml` (`.ts`, `.js`, `.tsx`, `.jsx`, or `.mjs`; CLI 1.215.0 or higher) | `verify_jwt` true; the rest none | Not applicable | B1, B3 | 15 Nov 2026 | checked |
| `verify_jwt = false` | Removes the platform's JWT check. Supabase warns that anyone can then call the function, and says it is used for webhooks such as Stripe's. The handler or the `withSupabase` wrapper must then check the caller | Not applicable | Not applicable | B1, B10 | 15 Nov 2026 | checked |
| `withSupabase` wrapper `auth` modes `'user'`, `'secret'`, `'publishable'`, `'none'`; `ctx.supabaseAdmin` bypasses RLS | Caller check inside a function | Not applicable | Not applicable | B10 | 15 Nov 2026 | checked |
| `[edge_runtime]`: `enabled`, `policy` (`oneshot` or `per_worker`), `inspector_port`; `[edge_runtime.secrets]` with `NAME = "env(NAME)"` | Local function runtime and local secrets | `enabled` true; `policy` `oneshot` | Not applicable | B3, B7 | 15 Nov 2026 | checked |
| Edge Function limits | Fixed limits, no setting | Not applicable | Memory 256 MB. CPU time 2 seconds per request (excludes async I/O). Wall clock 150 seconds Free and 400 seconds Paid. Idle timeout 150 seconds (504). Function size 20 MB bundled by the CLI, 5 MB bundled server-side | B4 | 15 Nov 2026 | checked |
| Edge Function request body limit | Size of a body | Not applicable | Not stated on the page read | B4 | 15 Nov 2026 | verify |
| Functions per project | Count | Not applicable | Free 100, Pro 1,000, Team 2,000, Enterprise unlimited | B4 | 15 Nov 2026 | checked |
| Deno version | Runtime currency. No `deno_version` key was found in the config reference read | Not applicable | Not applicable | B3 | 15 Nov 2026 | verify |
| API keys | Publishable key `sb_publishable_...` (low privilege, subject to RLS, safe in a browser). Secret key `sb_secret_...` (maps to `service_role`, bypasses RLS, server only, a browser request gets 401). Legacy JWT keys `anon` and `service_role` | Not applicable | Supabase is deprecating the legacy keys "by the end of 2026". They work until disabled in the dashboard | B2 | 15 Nov 2026 | checked |
| Environment variable names for keys | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (browser), `SUPABASE_SECRET_KEY` (server), `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` (legacy). In functions the runtime sets `SUPABASE_URL`, `SUPABASE_DB_URL`, `SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS` (JSON), `SUPABASE_JWKS`, and the legacy names | Not applicable | A secret name cannot start with `SUPABASE_` | B2, B7 | 15 Nov 2026 | checked |
| Function secrets: `supabase secrets set NAME=value`, `supabase secrets set --env-file .env`, `supabase secrets list`, dashboard "Edge Function Secrets", local `supabase/functions/.env` | Where secret values live. Production secrets take effect without a redeploy | Not applicable | Not applicable | B7 | 15 Nov 2026 | checked |
| Secret references in `config.toml`: `env(NAME)`, for example `secret = "env(SUPABASE_AUTH_EXTERNAL_<PROVIDER>_SECRET)"` | Keeps a value out of the file | Not applicable | Not applicable | B3 | 15 Nov 2026 | checked |
| Row-level security: `alter table <t> enable row level security;` in a migration | Whether the API enforces access per row | Tables made in the dashboard have RLS on. Tables made in the SQL editor or other tools need it enabled | With RLS on and no policy, a publishable key sees no data. Views bypass RLS unless made `with (security_invoker = true)` (Postgres 15 and later). `security definer` functions bypass RLS | B5, B8 | 15 Nov 2026 | checked |
| Grants to `anon`, `authenticated`, and `service_role` | Which roles reach a table or function through the Data API | A new table in `public` on an existing project can start with all privileges to those roles | Not applicable | B5, B8 | 15 Nov 2026 | checked |
| `[api]`: `enabled`, `port`, `schemas`, `extra_search_path`, `max_rows` | The Data API | `schemas` `["public", "storage", "graphql_public"]`; `max_rows` 1000 | Local defaults | B3 | 15 Nov 2026 | checked |
| `supabase/seed.sql` (`[db.seed]` `sql_paths` `["./seed.sql"]`) | Seed file | `[db.seed]` enabled | Not applicable | B3 | 15 Nov 2026 | checked |
| `supabase/migrations/*.sql` | Schema and policy files. The path was not read | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| `[db.pooler]`: `enabled`, `port`, `pool_mode`, `default_pool_size`, `max_client_conn` | Connection pooler of the local stack | `enabled` false; `pool_mode` `transaction`; `default_pool_size` 20; `max_client_conn` 100 | Local defaults | B3 | 15 Nov 2026 | checked |
| Hosted pooler (Supavisor) | Connection pooling for the hosted database | Direct: port 5432. Shared pooler, session mode: port 5432. Shared pooler, transaction mode: port 6543 | Transaction mode has no prepared statements, `set`, `listen`, or temporary tables. For serverless and edge functions use transaction mode, make the client once at module scope, set the pool to `max: 1`, set SSL to `require`, and turn prepared statements off | B6 | 15 Nov 2026 | checked |
| `[auth]`: `site_url`, `additional_redirect_urls`, `jwt_expiry`, `enable_signup`, `enable_anonymous_sign_ins`; `[auth.email]` `enable_confirmations`; `[auth.external.<provider>]` `client_id`, `secret` | Sign-in settings | `jwt_expiry` 3600; `enable_signup` true; `enable_anonymous_sign_ins` false; `enable_confirmations` false | Not applicable | B3 | 15 Nov 2026 | checked |
| Auth rate limits (Management API keys `rate_limit_email_sent`, `rate_limit_sms_sent`, `rate_limit_anonymous_users`, `rate_limit_verify`, `rate_limit_token_refresh`, `rate_limit_otp`, `rate_limit_web3`; dashboard "Authentication, Rate Limits") | Rate limits on sign-in calls | Email 2 an hour on the built-in provider; SMS 30 an hour; verify 30 per 5 minutes; token refresh 150 per 5 minutes; OTP 30 per 5 minutes | Not applicable | B9 | 15 Nov 2026 | checked |
| `[auth.rate_limit]` in `config.toml` | The same limits as a file setting | Not applicable | Not applicable | Not on the config page read | 15 Nov 2026 | verify |
| `[storage]` `file_size_limit` | Largest upload | `"50MiB"` | Not applicable | B3 | 15 Nov 2026 | checked |
| Rate limit or size limit on an Edge Function | Limits ahead of a function | Not applicable | No setting read | Not read | 15 Nov 2026 | verify |
| Cross-origin rules of an Edge Function | CORS | Not applicable | Not read. Believed to be set in function code | Not read | 15 Nov 2026 | verify |
| Log retention | How long logs are kept | Not applicable | Not read. The production checklist page does not cover it | B11 | 15 Nov 2026 | verify |
| Deploy credential `SUPABASE_ACCESS_TOKEN` in a workflow | How a pipeline signs in | Not applicable | Not applicable | Not read | 15 Nov 2026 | verify |
| CPU architecture | Whether the platform has a setting | Not applicable | No setting read | Not read | 15 Nov 2026 | verify |
| Supabase provider for Terraform | Project settings as `*.tf` | Not applicable | Not applicable | Seen only as a search-result title | 15 Nov 2026 | verify |

## Setting names for each check

For each of the eighteen checks, the setting or file that lets the skill judge it on each platform. "No setting" means the pages read show none, and the check cannot pass or fail from a file on that platform for that part. It is judged from code, or it is "ask the team", as `checks.md` says. Rows marked "verify" repeat a verify row above.

### Efficiency

| Check | AWS Lambda | Vercel | Cloudflare Workers | Supabase |
| --- | --- | --- | --- | --- |
| E1 Memory, and CPU where a setting exists | `MemorySize`, `memory_size`, `memorySize` (also `Globals.Function.MemorySize`). CPU follows memory, no separate setting | No file setting: the dashboard "Function CPU" only, and `vercel.json` `memory` is refused. The skill reports "no setting in a file" | No memory setting (128 MB). CPU: `limits.cpu_ms` | No setting (256 MB fixed) |
| E2 Time limit | `Timeout`, `timeout` (also `Globals.Function.Timeout`); API Gateway integration timeout: verify | `maxDuration` in route code, `vercel.json` `functions.<glob>.maxDuration`, or the dashboard default | `limits.cpu_ms` limits CPU time only. No setting for elapsed time of HTTP requests | No setting (wall clock 150 or 400 seconds, CPU 2 seconds, fixed) |
| E3 Concurrency ceiling | `ReservedConcurrentExecutions`, `reserved_concurrent_executions`, `reservedConcurrency`; SQS `maximumConcurrency`; API throttling (`usagePlan.throttle`) | No setting read (verify) | No setting read (verify). `ratelimits` limits callers | No setting read for functions (verify). `[db.pooler]` `max_client_conn`, `default_pool_size` limit database connections locally |
| E4 Runtime and architecture current | `Runtime`, `runtime`; `Architectures`, `architectures`, `architecture`; runtime table above | Node.js and Python version settings: verify. No architecture setting read | `compatibility_date`, `compatibility_flags`. No architecture setting | No Deno version key read (verify). No architecture setting |
| E5 Deploy package | `package.patterns`, `package.individually`, `package.excludeDevDependencies`, `CodeUri`, `Layers`, `filename`; 250 MB unzipped | `functions.<glob>.includeFiles`, `excludeFiles`; Next.js `outputFileTracingIncludes`, `outputFileTracingExcludes`; 250 MB | `assets.directory`; 64 MiB uncompressed | `[functions.<name>]` `import_map`, `entrypoint`, `static_files`; 20 MB local, 5 MB server-side |
| E6 Clients and connections | Client at module scope (code). RDS Proxy: verify. `VpcConfig` | Client at module scope (code); 1,024 file descriptors; use a pooler | `hyperdrive` binding; new client per request; no request data at module level | Transaction pooler on port 6543, client at module scope, `max: 1`; `[db.pooler]` |
| E7 Streaming | `InvokeMode` `RESPONSE_STREAM` (`invoke_mode`, `url.invokeMode`); 6 MB buffered, 200 MB streamed | 4.5 MB body limit, not applied to streamed responses (code uses streams) | Code pipes streams; 128 MB memory | No setting read (code); verify |
| E8 Start-up work | `ProvisionedConcurrencyConfig`, `provisionedConcurrency`; `SnapStart` (verify); package size | No setting. Bytecode caching is automatic for Node.js 20 and later on production | No setting. Work at module scope runs in the isolate start (code) | No setting. Code only |

### Security

| Check | AWS Lambda | Vercel | Cloudflare Workers | Supabase |
| --- | --- | --- | --- | --- |
| S1 Caller check on public entry points | Function URL `AuthType` (`authorization_type`, `url.authorizer`), resource policy `Principal` `*`; `httpApi.authorizers`; `http` `authorizer` and `private` | No file setting for a route. Code checks the caller. Deployment Protection: verify | No setting read. `routes` and `workers_dev` set exposure. Code checks the caller (verify) | `[functions.<name>]` `verify_jwt` (default true); `withSupabase` `auth` |
| S2 Permissions cover what is used | `Policies`, `Role`, `role`; Serverless `iam.role.statements` (`Effect`, `Action`, `Resource`), `mode`, `inheritStatements`; Terraform IAM names: verify | No IAM. The environment variables in scope by name for each environment | The bindings list (`kv_namespaces`, `r2_buckets`, `d1_databases`, `durable_objects`, `queues`, `services`, `hyperdrive`, `ai`). Read-only modes: verify | The key type a function uses (`SUPABASE_SECRET_KEY` or `SUPABASE_SERVICE_ROLE_KEY` against the publishable key); grants to roles |
| S3 Secrets in the secret store | `Environment`, `environment`, `Variables` hold values (hidden by the reader); Secrets Manager; `${ssm:}` syntax: verify | Variable type Secret (`--sensitive`); `vercel.json` has no values | `vars` against `wrangler secret put`; `secrets.required`; `secrets_store_secrets`; `.dev.vars` kept out of git | `supabase secrets set`; `env(NAME)` in `config.toml`; `supabase/functions/.env` kept out of git |
| S4 No server secret in the browser bundle | Not applicable to Lambda alone. A front end in the repository follows the Vercel row | `NEXT_PUBLIC_` names (and the framework equivalents: verify) | `assets` and a front end's public prefix (verify); `vars` are not sent to the browser by themselves (verify) | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` is allowed. A secret or `service_role` key behind a public prefix is the finding |
| S5 Data layer enforces access | No setting at the function. The data store's own rules: verify | No data layer | No row policy setting read for D1, KV, or R2 (verify) | `enable row level security`, policies, grants, `security_invoker` on views, `[api] schemas` |
| S6 Webhook and schedule callers verified | Function URL `AuthType`; `authorizers`; code verifies a webhook signature | `CRON_SECRET` with the `Authorization` header (cron and path schedules); `function` schedule targets have no public URL | `triggers.crons` (scheduled events). Webhook check in code (verify) | `verify_jwt = false` plus a signature check in code; `withSupabase` `auth: 'none'` only with a signature check |
| S7 Size limit and rate limit | `usagePlan.throttle`, `quota`, `apiKeys`; 6 MB payload; WAF: verify | Firewall rate limiting (dashboard); 4.5 MB body limit fixed. `vercel.json` firewall: verify | `ratelimits` binding; zone WAF rules (verify); request body size by zone plan | Auth rate limits (`rate_limit_*`); `[storage]` `file_size_limit`; no function setting read |
| S8 Cross-origin rules name origins | Function URL `AllowOrigins`; `httpApi.cors`; `url.cors.allowedOrigins`; `http` `cors.origin` | `headers` entry for `Access-Control-Allow-Origin`; code | No setting read; code | No setting read; function code (verify) |
| S9 Short-lived deploy credentials | `role-to-assume` with `id-token: write`, against `aws-access-key-id` and `aws-secret-access-key` | `VERCEL_TOKEN` in a workflow: verify | `CLOUDFLARE_API_TOKEN` in a workflow: verify | `SUPABASE_ACCESS_TOKEN` in a workflow: verify |
| S10 Logs: no secrets or bodies, with retention | `retention_in_days`, `logRetentionInDays`, `LoggingConfig`, `logging_config`, `kms_key_id` | Log retention: verify | `observability` (`enabled`, `head_sampling_rate`, `logs.invocation_logs`); retention fixed at 3 or 7 days | Log retention: verify |

## Files the reader lists

The reader's list output is `<path>:<platform>:<kind>:<tracked|untracked|ignored|no-git>`. Platform is one of `aws-lambda`, `vercel`, `cloudflare-workers`, `supabase`, or `shared`. Kind is one of `functions`, `infrastructure`, `env`, or `workflow`. The spec fixes the file names and the two sets. The platform and kind in the table are this file's assignment and Task 4 may adjust a kind if a file fits better elsewhere.

| File or pattern | Platform | Kind | Format | Notes |
| --- | --- | --- | --- | --- |
| `wrangler.toml` | `cloudflare-workers` | `functions` | TOML | C1 |
| `wrangler.json` | `cloudflare-workers` | `functions` | JSON | C1 |
| `wrangler.jsonc` | `cloudflare-workers` | `functions` | JSON with comments | C1. Recommended for new projects |
| `.dev.vars` | `cloudflare-workers` | `env` | dotenv | C3 |
| `.dev.vars.<environment>` | `cloudflare-workers` | `env` | dotenv | C3. Ruling by the controller: listed, with `.dev.vars` |
| `vercel.json` | `vercel` | `functions` | JSON | V8 |
| `serverless.yml` | `aws-lambda` | `functions` | YAML | A18 |
| `serverless.yaml` | `aws-lambda` | `functions` | YAML | A18 |
| `template.yaml`, `template.yml`, `template.json` | `aws-lambda` | `infrastructure` | YAML or JSON | SAM and CloudFormation. Listed whatever the name when the file holds an `AWSTemplateFormatVersion` line or a `Transform: AWS::Serverless` line. Markers: verify |
| Any other `*.yaml`, `*.yml`, or `*.json` with an `AWSTemplateFormatVersion` or a `Transform: AWS::Serverless` line | `aws-lambda` | `infrastructure` | YAML or JSON | From the spec |
| `samconfig.toml` | `aws-lambda` | `infrastructure` | TOML | A25 |
| `*.tf`, `*.tofu` | By the first match in this order: `aws-lambda` when the file holds a resource whose type starts with `aws_lambda_`; `cloudflare-workers` when it holds a resource whose type starts with `cloudflare_worker`; `supabase` when it holds a resource whose type starts with `supabase_`; otherwise `shared` | `infrastructure` | HCL | Ruling by the controller. Resource type prefixes are the controller's; the provider resource names were not all read (`aws_lambda_` is read in A13 to A16) |
| `*.tfvars` | `shared` | `env` | HCL variable file | Names only. Format: verify |
| `supabase/config.toml` | `supabase` | `functions` | TOML | B3 |
| Env files: `.env`, `.env.*`, `.env.local`, `.env.<NODE_ENV>.local`, `supabase/functions/.env`, `.vercel/.env.<environment>.local` | `shared` | `env` | dotenv | Names only. V10, V11, B7 |
| `.github/workflows/*.yml`, `.github/workflows/*.yaml` | `shared` | `workflow` | YAML | For S9 only. Ruling by the controller: both extensions are listed. Only the top `.github/workflows` folder, which is the one GitHub runs |

The reader skips `.git`, `node_modules`, `.terraform`, `.next`, `.serverless`, `.wrangler`, `.aws-sam`, `.turbo`, `.venv`, and `venv`. A file type the reader does not know is not shown. The skill reports it under "Not checked". The files in the next section are source code, and the agent reads them directly.

## Read as source code

These define or affect functions but are code, not configuration. The agent reads them directly, under ground rule 1, and never prints a credential value from them.

| File or pattern | Platform | What to look for |
| --- | --- | --- |
| AWS CDK stacks (`lib/*.ts`, `bin/*.ts`, `cdk.json`) | `aws-lambda` | `Function` constructs: memory, timeout, architecture, runtime, reserved concurrency, function URL `authType`, role statements. File names and construct names: verify |
| SST (`sst.config.ts`) | `aws-lambda` and others | The same settings. Names: verify |
| Pulumi (`Pulumi.yaml` and programs) | `aws-lambda` and others | The same settings. Names: verify |
| `next.config.js`, `next.config.mjs`, `next.config.ts` | `vercel` | `outputFileTracingIncludes`, `outputFileTracingExcludes`, `env` (values placed here reach the bundle: verify) |
| `vercel.ts` | `vercel` | Programmatic form of `vercel.json`. Seen only as a link title: verify |
| Handlers: Lambda handler files; Next.js route handlers (`app/**/route.ts`, `pages/api/**`); Vercel `api/` files; Worker entry (`main` in the Wrangler config); `supabase/functions/<name>/index.ts` and its siblings | all | Entry points, caller checks, `maxDuration`, clients at module scope, body handling, webhook signature checks, `process.env.NEXT_PUBLIC_*` use. The default Supabase entry file name `index.ts` was not read: verify |
| SQL migrations (`supabase/migrations/*.sql`) and `supabase/seed.sql` | `supabase` | `enable row level security`, `create policy`, `grant`, `security_invoker`, `security definer`. Path: verify |
| Front-end source and framework config | `vercel`, `cloudflare-workers` | Public-prefix variables (`NEXT_PUBLIC_`); keys placed in code |

## Keys whose values the reader shows

Hiding is the default. A shown key prints its value only in its home: a container that this section names as a place where that key is a real setting. In every other container, at any depth, the reader prints key names only, and a container it does not know counts as one of these. So a list of homes, not a list of maps to hide, decides what prints, and a map nobody has named yet hides without a new entry. Four rules then settle every case, in this order.

1. **The never-shown list wins.** A key on the list below prints as `<redacted>` in every file, unless rule 2 names it as an exception in that file and under that parent.
2. **A shown key shows only what is listed for it, and only in its home.** The tables below name each shown key and, where a key has children, the children that are shown. A child that is not named is hidden. A map key (`events`, `Events`, `Auth`, `Globals`, `Environment`, `environment`, `vars`, `with`, `env`, `inputs`, `parameter_overrides`) is never shown whole: the reader shows its key names and applies these rules to each child. Any `Variables`, `environment`, or `vars` map at any depth, including inside `Globals`, shows names and hides every value.
3. **A shown value must have the shape of a setting, and still passes through the token-shape filters.** Each shown key has one shape: a number, a boolean, a date, a single word, a short text, a schedule, a path or route, an origin, or an address. Any other value is hidden. A value that starts with a dash is a flag: it is hidden, and so is the next item of the same list. A value that spans lines, a heredoc, a block scalar, a TOML multi-line string, and a comment are hidden whole. A list that spans lines is hidden whole. Env files and `*.tfvars` print names only.
   A key with a small closed set of values shows a value only from that set: architecture (`x86_64`, `arm64`), authentication mode (`AWS_IAM`, `NONE`), invoke mode (`BUFFERED`, `RESPONSE_STREAM`), tracing mode, package type, log format and level, IAM effect (`Allow`, `Deny`), IAM role mode, HTTP method, the `type` of an `authorizer`, usage-plan period, Wrangler placement mode, Supabase pool mode and edge runtime policy, and a Region. A key with a fixed form shows a value only in that form: a role to assume is an IAM role ARN, a principal is `*`, an account, an IAM ARN, or an `amazonaws.com` service, a layer is a layer ARN, an SQS event is an ARN, a schedule has fields or is `rate(` a number and a unit `)`, `cron(` fields `)`, or `@name`, a Worker route or route pattern holds a `/`, and a `vercel.json` `Access-Control-Allow-Origin` value is an origin. A number or boolean setting shows only a number or a boolean. A runtime and a handler keep the single-word shape.
4. **A path or a route is shown by its path part only.** A value that holds `?`, `=`, `@`, `#`, or `%` is hidden whole, and so is a path with a part that looks like a token (8 or more characters mixing letters and digits, or 8 capital letters in a row). A segment of the path itself (not the host) longer than 15 characters hides the value too, because a shared secret can be a segment made only of letters.

A value that only names where a secret lives is shown under any key whose name is shown, because it holds no secret: `${{ secrets.NAME }}`, `${{ vars.NAME }}` and the other workflow contexts, `env(NAME)`, `${ssm:...}`, `${secretsmanager:...}`, and `${env:NAME}`. It is never shown in an env file or a `*.tfvars` file. This tells a secret kept in a store from a value written into the file, which S3 and S9 need.

Never-shown keys, matched by name in any file: `secret`, `secrets`, `token`, `password`, `passwd`, `apikey`, `api_key`, `access_key`, `secret_key`, `client_secret`, `auth_token`, `private_key`, `localConnectionString`, `connection_string`, `database_url`, `aws-access-key-id`, `aws-secret-access-key`, `CRON_SECRET`, `input` (a schedule payload), `request` and `parameters` of a Serverless `http` event (`parameters` is never shown in a Serverless file only, so `samconfig.toml` tables still show), `buildCommand`, `installCommand`, `run`, `Condition` values, `apiKeys` (a Serverless list that can hold key values), `parameter_overrides`, and any key whose name, with dashes and underscores removed, contains `secret`, `token`, `passw`, `credential`, `privatekey`, `apikey`, `accesskey`, `connectionstring`, or `databaseurl`. A bare `key` is never shown, except for the `key` of an item in a `vercel.json` `headers` list (see below). Below a never-shown key, names and values are hidden. `Condition` and `condition` show their key names and hide every value.

The homes, by file. A name in angle brackets is one the user picks. The keys shown in each home are those in the tables below.

| File | Homes of shown keys |
| --- | --- |
| `serverless.yml` | The top of the file; `provider`, with `tracing`, `iam`, `iam.role`, `iam.role.statements`, `apiGateway.usagePlan` (and a named plan in it) with `throttle` and `quota`, `httpApi` with `cors` and `authorizers.<name>`, and `logs`; `functions.<name>`, with `url` and its `cors`, `iam`, `package`, and `events`, where each event (`http`, `httpApi`, `schedule`, `sqs`) and its `cors` and `authorizer`; the top `package`. `resources`, `custom`, `params`, and everything else print names only |
| SAM and CloudFormation templates | The top of the file; `Resources.<name>`; its `Properties` and `Globals.Function`, with `ProvisionedConcurrencyConfig`, `EphemeralStorage`, `FunctionUrlConfig` and its `Cors`, `LoggingConfig`, `RuntimeManagementConfig`, `SnapStart`, `Events.<name>` with its `Properties` and `Auth`, `Policies` and their `Statement`, `PolicyDocument` and `AssumeRolePolicyDocument` with `Statement` and `Principal`. `Parameters`, `Mappings`, `Conditions`, `Outputs`, `Metadata`, and `Tags` print names only |
| `wrangler.toml`, `wrangler.json`, `wrangler.jsonc` | The top of the file and each `env.<name>`, which holds the same settings as the top but not another `env`; `routes`, `triggers`, `limits`, `placement`, `observability` and its `logs`, `assets`, `secrets`; each resource list (`kv_namespaces`, `d1_databases`, `r2_buckets`, `services`, `queues.producers`, `queues.consumers`, `durable_objects.bindings`, `workflows`, `ratelimits` and its `simple`, `hyperdrive`, `vectorize`, `analytics_engine_datasets`, `dispatch_namespaces`, `mtls_certificates`); each single binding, which is one object and not a list (`ai`, `browser`, `images`, `version_metadata`, `send_email`) |
| `vercel.json` | The top of the file; `functions.<glob>`; `crons`; `schedules.<name>`; `headers` and the `headers` list in each item; `rewrites` |
| Workflows | The top of the file; `on` and `on.<event>`, and `on.schedule`; `permissions` at the top and in a job; `jobs.<name>` and its `environment`; each step and its `with`. `env`, `secrets`, `strategy`, `matrix`, `services`, `inputs`, and `outputs` print names only |
| `samconfig.toml` | The top of the file, and `[<environment>.<command>.parameters]` |
| `supabase/config.toml` | `[api]`, `[db]` with `[db.pooler]` and `[db.seed]`, `[auth]` with `[auth.email]` and `[auth.external.<name>]`, `[functions.<name>]`, `[edge_runtime]`, `[storage]` |
| `*.tf`, `*.tofu` | A `resource` block of type `aws_lambda_function` (with `ephemeral_storage`, `tracing_config`, `logging_config`), `aws_lambda_function_url` (with `cors`), `aws_lambda_permission`, `aws_cloudwatch_log_group`, `aws_iam_role`, `aws_iam_role_policy`, or `aws_iam_policy` (with the `Statement` of a `jsonencode` policy), and a `data` block of type `aws_iam_policy_document` (with `statement` and its `condition`). Any other block, attribute map, or resource type, such as `tags`, `parameters`, or `locals`, prints names only |

An item of a sequence (YAML), an object in an array (JSON), a `[[table]]` (TOML), or an object in a list (HCL) is in a home only where that home is a list and the list is the value of its key: Serverless `functions` (its array form), `events`, IAM `statements`, and `usagePlan`; SAM `Policies` and `Statement`; workflow `steps` and `on.schedule`; `vercel.json` `crons`, `headers` and their `headers`, and `rewrites`; each Wrangler resource list and `routes`; and the `Statement` of a `jsonencode` policy. An item anywhere else prints names only. So does an item of an item (a list inside a list), at any depth, and so does a single Wrangler binding that is written as a list.

The reader does not parse. It follows the structure of each format with the rules below, and it hides what it cannot place.

- **HCL.** A bracket is in a home only when a line of a known form opens it and that line closes nothing. The known forms are a block header in a block body, `key = {`, `key = [`, and `key = jsonencode(` with these brackets alone, a bare `{` that is an item of a list home or the one object of a `jsonencode` call, and `}, {` between two items of a list home. Every other bracket opens an unknown container, where names and values print hidden until it closes. So a line that closes a block and then opens another, such as `} resource "x" "y" {` or a bare `} {`, with or without a comment between, hides itself and the new block. A quoted name or a colon in a block body, such as `"runtime" = "x"`, hides the line, because only an object takes them. A `resource` or `data` block is named by its first label, and only when that label is quoted. A closer that does not match the last open bracket, a quoted string that does not end on its line, and a heredoc whose end word is not a plain word break the file: that line and the rest of the file are hidden.
- **YAML.** A container is a map or a sequence, fixed by its first child, with one indent. A key at an indent that no other key of the same map uses, a key beside items, an item beside keys, and an item at another indent are broken YAML: each is hidden with everything below it. A value on the line after its key hides its own indent and everything deeper. A `---` or `...` line starts again with nothing open, and a document with text on its `---` line is hidden whole. A value in brackets that spans lines is hidden up to its closing bracket, and a bracket in a comment or in a quoted string does not count.
- **JSON.** A file is one value. A closer of the wrong kind, a closer with nothing open, and anything after the end of that value break the file: that line and the rest of the file are hidden.
- **TOML.** A multi-line string is followed only as the whole value of a key. One that opens anywhere else, such as inside an array, hides the rest of the file. A one-line string that does not close hides every line up to the one that closes it, and a table header among those lines leaves the table unknown. A key with a quoted part that holds a dot, a space, or another sign hides its line.

Known limit: these rules hide some valid layouts, and the cost is a setting that the skill reports as not found. Examples are an HCL value opened as `policy = merge(local.base, {`, an HCL list item that opens on the line of its list after another item (`Statement = [ { ... }, {`), a YAML sequence written in brackets inside a list home, and a TOML multi-line string inside an array.

Known limit: an HCL `module` block prints names only, because the module's author names its inputs, so a module that sets up a function shows none of its settings. The skill reads such a module as source code.

A TOML table header the reader does not recognise (a quoted part with a dot, a space, `/`, or `:`, a letter outside ASCII, or one bracket on one side and two on the other) hides every line below it until the next header it recognises. A line that still holds a carriage return after its end is cut (a file with old Mac line endings) is hidden whole. This list is a safe default and not read from a provider. It is the list `scripts/read-serverless-config.sh` uses.

Exceptions to the never-shown list, by parent. They are the only ones.

| Key | Parent that makes it an exception | What is shown |
| --- | --- | --- |
| `required` | wrangler `secrets` | The names listed in `required` (the names are the setting; there are no values) |
| `private` | Serverless `http` event | The boolean only |
| `ApiKeyRequired` | SAM `Auth` | The boolean only. The name holds `apikey`, so rule 1 would hide it |
| `id-token`, `contents`, and every other permission | GitHub workflow `permissions` | Only `read`, `write`, `none`, `read-all`, or `write-all` |
| `url` | Serverless function | `authorizer`, `invokeMode`, and the `cors` keys. A `url` that holds an address of a database is hidden |
| `key` | An item of `vercel.json` `headers` | The key name. The `value` is shown only when the key starts with `Access-Control-` |
| `Condition` | IAM statement | The condition operator and the condition key names. Every value is hidden |
| `secrets` | GitHub workflow `jobs.<job>.steps[].env` or `with` | Names only, never values |

### TOML: `wrangler.toml`, `samconfig.toml`, `supabase/config.toml`

| File | Keys whose values are shown |
| --- | --- |
| `wrangler.toml` | `name`, `main`, `compatibility_date`, `compatibility_flags`, `workers_dev`, `route`, `routes` (path part only, and `pattern`, `custom_domain` inside), `crons` under `[triggers]`, `cpu_ms` under `[limits]`, `mode` under `[placement]`, `enabled`, `head_sampling_rate`, `invocation_logs` under `[observability]`, `binding` of `kv_namespaces`, `r2_buckets`, `d1_databases`, `durable_objects`, `queues`, `services`, `hyperdrive`, `ai`, `vectorize`, `analytics_engine_datasets`, `class_name`, `script_name`, `bucket_name`, `queue`, `service`, `entrypoint`, `directory` and `run_worker_first` under `[assets]`, `upload_source_maps`, `keep_vars`, `name`, `limit`, `period` under `ratelimits` and `simple`, `required` under `secrets`. Resource ids (`id`, `namespace_id`, `database_id`, `account_id`) are hidden. `vars` shows names only |
| `samconfig.toml` | `version`, `stack_name`, `capabilities`, `confirm_changeset`, `resolve_s3`, `region`, `cached`, `parallel`, `watch`. `parameter_overrides` shows no names and no values |
| `supabase/config.toml` | `verify_jwt`, `entrypoint`, `import_map`, `static_files` (paths), `enabled`, `policy`, `port`, `schemas`, `extra_search_path`, `max_rows`, `major_version`, `pool_mode`, `default_pool_size`, `max_client_conn`, `site_url`, `additional_redirect_urls`, `jwt_expiry`, `enable_signup`, `enable_anonymous_sign_ins`, `enable_confirmations`, `file_size_limit`, `sql_paths`. A value written as `env(NAME)` shows the name `NAME` only. `client_id` and `secret` under `[auth.external.*]` are hidden |

### JSON and JSON with comments: `wrangler.json`, `wrangler.jsonc`, `vercel.json`, `template.json`

| File | Keys whose values are shown |
| --- | --- |
| `wrangler.json` and `wrangler.jsonc` | The same keys as `wrangler.toml`, in their JSON form, under the same rules. `vars` shows names only. A comment is hidden whole |
| `vercel.json` | `maxDuration`, `memory`, `regions`, `functionFailoverRegions`, `includeFiles`, `excludeFiles`, `supportsCancellation`, `runtime`, `fluid`, `bunVersion`, `$schema`, `framework`. Under `crons`: `path` (path part only) and `schedule`. Under `schedules`: the schedule name, and `schedule`, `path` (path part only), `requestMethod`, `function`, `topic`, `timezone`, `jitter`. Under `headers` and `rewrites`: `source`. Under `headers`: the item `key`, and the item `value` only for an `Access-Control-*` key. `buildCommand` and `installCommand` are hidden. `env` shows names only |
| `template.json` (CloudFormation) | `Type`, `Runtime`, `Handler`, `MemorySize`, `Timeout`, `Architectures`, `ReservedConcurrentExecutions`, `PackageType`, `AuthType`, `InvokeMode`, `AllowOrigins`, `AllowMethods`, `AllowHeaders`, `MaxAge`, `RetentionInDays`, `Tracing`, `Effect`, `Action`, `Resource` (an ARN may carry an account number: shown, then passed through the filters), `Principal`, `Transform`, `AWSTemplateFormatVersion`. `Condition` shows operators and key names, not values. `Environment` `Variables` shows names only. CloudFormation property names: verify |

### YAML: `serverless.yml`, `serverless.yaml`, `template.yaml`, `template.yml`, workflows

| File | Keys whose values are shown |
| --- | --- |
| `serverless.yml` and `serverless.yaml` | `service`, `runtime`, `memorySize`, `timeout`, `architecture`, `reservedConcurrency`, `provisionedConcurrency`, `logRetentionInDays`, `handler`, `region`, `stage`, `package` (`patterns`, `individually`, `excludeDevDependencies`), `url` (`authorizer`, `invokeMode`, `cors` and its keys), `httpApi` (`authorizers`, `cors`, `disableDefaultEndpoint`), `authorizer` (`name`, `type`, `scopes`), `private`, `usagePlan` (`throttle`, `burstLimit`, `rateLimit`, `quota`, `limit`, `period`), `iam` (`role`, `statements`, `Effect`, `Action`, `Resource`, `mode`, `inheritStatements`, `managedPolicies`; `Condition` shows operators and key names only), `layers`, `tracing`, `logs`, `vpc` (the ids are hidden). Under `events`: the event type (`http`, `httpApi`, `schedule`, `sqs`), and only `path`, `method`, `batchSize`, `maximumConcurrency`, `rate`, `enabled`. Event `input`, `request`, and `parameters` are hidden. `environment` shows names only. `apiKeys` is hidden below its name. Also shown: `provider.name`, `role`, and the short forms `schedule`, `sqs`, `http`, and `httpApi` of an event. `${ssm:...}` and `${secretsmanager:...}` references show the path and hide nothing else (reference syntax: verify) |
| `template.yaml` and `template.yml` (SAM and CloudFormation) | `Type`, `Runtime`, `Handler`, `CodeUri`, `MemorySize`, `Timeout`, `Architectures`, `ReservedConcurrentExecutions`, `ProvisionedConcurrencyConfig`, `AutoPublishAlias`, `EphemeralStorage`, `PackageType`, `FunctionUrlConfig` (`AuthType`, `InvokeMode`, `Cors` and its keys), `Policies`, `Role`, `PermissionsBoundary`, `Tracing`, `LoggingConfig`, `RuntimeManagementConfig`, `SnapStart`, `RetentionInDays`, `Effect`, `Action`, `Resource`, `Principal`, `Transform`, `AWSTemplateFormatVersion`. Under `Events`: the event name, `Type`, `Path`, `Method`, `Schedule`. Under `Auth`: only `Authorizer`, `DefaultAuthorizer`, `ApiKeyRequired`, `AddDefaultAuthorizerToCorsPreflight` (names read from no page: verify); other children are hidden. Under `Globals`: `Function` and its shown settings under these same rules, with every `Environment` `Variables` map names only. `Condition` shows operators and key names only. `Parameters` default values are hidden |
| `.github/workflows/*.yml` and `*.yaml` | `name`, `on`, `permissions` (and `id-token`, `contents`), `runs-on`, `uses`, `environment`, `role-to-assume` (an ARN: shown, then filtered), `aws-region`, `jobs` keys and `steps` `name`. `with` entries show names and hide values except `role-to-assume` and `aws-region`. `env` and `secrets` entries show names only. `run` blocks are hidden whole. Under `on`: `branches`, `branches-ignore`, `tags`, `paths`, `types`, and `cron`. `environment` shows a name; as a map it shows names only |

### HCL: `*.tf`, `*.tofu`, `*.tfvars`

| File | Keys whose values are shown |
| --- | --- |
| `*.tf` and `*.tofu` | Block types and labels (`resource "aws_lambda_function" "name"`), `runtime`, `handler`, `memory_size`, `timeout`, `architectures`, `reserved_concurrent_executions`, `package_type`, `filename`, `size` under `ephemeral_storage`, `authorization_type`, `invoke_mode`, `allow_origins`, `allow_methods`, `allow_headers`, `allow_credentials`, `max_age`, `function_url_auth_type`, `invoked_via_function_url`, `action`, `principal`, `effect`, `actions`, `resources`, `retention_in_days`, `log_format`, `application_log_level`, `system_log_level`, `mode` under `tracing_config`, `layers`, `function_name`, `role` (an ARN or a reference to a role). Inside a `jsonencode` policy: `Effect`, `Action`, and `Resource`; every other value in it is hidden. `condition` blocks show the test and variable names, not values. `environment` `variables` shows names only. Heredocs (such as `<<EOF` policy documents) are hidden whole, so an inline JSON policy is not shown and the skill reports that it could not read it. Variable `default` values are hidden |
| `*.tfvars` | Names only |

### Env files

`.env`, `.env.*`, `.dev.vars`, `.dev.vars.*`, `supabase/functions/.env`, and `.vercel/.env.*.local` print names only. The reader also prints the tracked, untracked, ignored, or `no-git` status, so a tracked env file is itself a finding for S3.

## Not checked in version 1

- **Platforms the spec leaves out:** Azure Functions, Google Cloud Functions, Netlify, Deno Deploy, and Fly.io.
- **Kubernetes and virtual machines.** The Kubernetes workload check (NET-62) is a separate skill.
- **Container image functions** on Lambda are read as configuration only. The image contents are not read.
- **Settings held only in a provider's console or account.** The skill reads a repository, so a file is not the running system.
  - AWS: settings changed in the console or CLI, AWS WAF rules, API Gateway stage settings, account concurrency quotas, IAM policies attached outside the repository, RDS Proxy.
  - Vercel: the dashboard "Function CPU" size, the dashboard "Default Max Duration", the Fluid compute toggle, Deployment Protection, firewall rules held in the dashboard, environment variable values and their Config or Secret type, log retention.
  - Cloudflare: secrets, variables edited in the dashboard, the `workers.dev` toggle changed in the dashboard, WAF and rate limiting rules, Cloudflare Access policies, Secrets Store contents.
  - Supabase: RLS policies made in the dashboard and never written to a migration, API key state, auth rate limits set in the dashboard, network restrictions, secrets set with `supabase secrets set`, hosted pooler settings, log retention.
- **Cost, usage, and exported logs.** No figure is given, and no log is read.
- **Secrets in source code beyond the types the skill reports.** The pre-launch check does a full pass.
- **Third-party plugins and build steps** that change what is deployed, and files generated at build time.
- **A YAML or JSON file that looks like a SAM or CloudFormation template but has neither marker line.**

## Facts that conflict or moved

- **Lambda memory maximum.** The Lambda guide says 128 to 10,240 MB. The CreateFunction API page and the Terraform page say 128 to 32,768 MB. Both were read on 15 November 2026. The skill never states a maximum. Verify before any text quotes one.
- **Lambda default account concurrency.** 1,000 per Region (A28, A10). Lambda page text says new accounts start lower and AWS raises them with use (A10).
- **Vercel Cron Jobs and Schedules.** Vercel calls Cron Jobs legacy and migrating to Schedules (V4, V6). Both `crons` and `schedules` exist in `vercel.json` today. A repository can hold either.
- **Vercel memory.** Memory is a dashboard setting, not a `vercel.json` setting (V9). This differs from older guides, so the skill does not read memory from `vercel.json`.
- **Vercel duration defaults.** 300 seconds on every plan with Fluid compute (V1, V2, V3). Values for projects with Fluid compute off were not read.
- **Supabase keys.** `anon` and `service_role` are being deprecated by the end of 2026 (B2). A repository can still hold either, or both, with the new keys.
- **Cloudflare `wrangler.toml` and `wrangler.jsonc`.** Cloudflare recommends `wrangler.jsonc` and supports all three (C1).
- **Wrangler `workers_dev`.** Setting `routes` without `workers_dev` makes it false on the next deploy (C9). A file without the key says nothing certain about the running Worker.

## Sources

Read on 15 November 2026. Where a Terraform Registry page needed JavaScript, the same text was read from the provider's documentation source on `raw.githubusercontent.com`.

AWS and tools:

- A1 Lambda memory: https://docs.aws.amazon.com/lambda/latest/dg/configuration-memory.html
- A2 Lambda timeout: https://docs.aws.amazon.com/lambda/latest/dg/configuration-timeout.html
- A3 Lambda runtimes: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
- A4 Lambda architectures: https://docs.aws.amazon.com/lambda/latest/dg/foundation-arch.html
- A5 Function URL authentication: https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html
- A6 Reserved and provisioned concurrency: https://docs.aws.amazon.com/lambda/latest/dg/configuration-concurrency.html
- A7 Lambda Node.js runtimes: https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html
- A8 SAM `AWS::Serverless::Function`: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-function.html
- A9 Lambda CreateFunction API: https://docs.aws.amazon.com/lambda/latest/api/API_CreateFunction.html
- A10 Lambda quotas: https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html
- A11 Lambda response streaming: https://docs.aws.amazon.com/lambda/latest/dg/configuration-response-streaming.html
- A12 Function URL configuration: https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html
- A13 Terraform `aws_lambda_function`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function (read from https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/main/website/docs/r/lambda_function.html.markdown)
- A14 Terraform `aws_lambda_function_url`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url (read from the matching `lambda_function_url.html.markdown`)
- A15 Terraform `aws_cloudwatch_log_group`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group (read from the matching `cloudwatch_log_group.html.markdown`)
- A16 Terraform `aws_lambda_permission`: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission (read from the matching `lambda_permission.html.markdown`)
- A17 Serverless Framework functions: https://www.serverless.com/framework/docs/providers/aws/guide/functions
- A18 Serverless Framework `serverless.yml` reference: https://www.serverless.com/framework/docs/providers/aws/guide/serverless.yml
- A19 Serverless Framework IAM: https://www.serverless.com/framework/docs/providers/aws/guide/iam
- A20 Serverless Framework packaging: https://www.serverless.com/framework/docs/providers/aws/guide/packaging
- A21 Serverless Framework HTTP API events: https://www.serverless.com/framework/docs/providers/aws/events/http-api
- A22 Serverless Framework API Gateway events: https://www.serverless.com/framework/docs/providers/aws/events/apigateway
- A23 SAM `FunctionUrlConfig`: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-functionurlconfig.html
- A24 `aws-actions/configure-aws-credentials` README: https://raw.githubusercontent.com/aws-actions/configure-aws-credentials/main/README.md
- A25 SAM CLI configuration file: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-config.html
- A26 SAM `Globals`: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-specification-template-anatomy-globals.html
- A27 Lambda environment variables: https://docs.aws.amazon.com/lambda/latest/dg/configuration-envvars.html
- A28 Lambda concurrency scaling: https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html
- A29 API Gateway quotas page (account throttle only): https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html

Vercel and Next.js:

- V1 Maximum duration: https://vercel.com/docs/functions/configuring-functions/duration.md
- V2 Function limits: https://vercel.com/docs/functions/limitations
- V3 Fluid compute: https://vercel.com/docs/fluid-compute
- V4 Managing Cron Jobs: https://vercel.com/docs/cron-jobs/manage-cron-jobs
- V5 Handling scheduled runs: https://vercel.com/docs/schedules/handle-runs
- V6 Migrating from Cron Jobs to Schedules: https://vercel.com/docs/schedules/migrate-from-cron-jobs
- V7 Config and Secret environment variables: https://vercel.com/docs/environment-variables/sensitive-environment-variables
- V8 `vercel.json`: https://vercel.com/docs/project-configuration/vercel-json
- V9 Memory and CPU: https://vercel.com/docs/functions/configuring-functions/memory.md
- V10 Environment variables across environments: https://vercel.com/docs/environment-variables/manage-across-environments
- V11 Next.js environment variables: https://nextjs.org/docs/pages/guides/environment-variables
- V12 Vercel WAF: https://vercel.com/docs/vercel-firewall/vercel-waf

Cloudflare:

- C1 Wrangler configuration: https://developers.cloudflare.com/workers/wrangler/configuration/
- C2 Workers limits: https://developers.cloudflare.com/workers/platform/limits/
- C3 Environment variables and secrets in development: https://developers.cloudflare.com/workers/development-testing/environment-variables/
- C4 Secrets: https://developers.cloudflare.com/workers/configuration/secrets/
- C5 Rate Limiting binding: https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- C6 Workers best practices: https://developers.cloudflare.com/workers/best-practices/workers-best-practices/
- C7 Hyperdrive: https://developers.cloudflare.com/hyperdrive/
- C8 Wrangler environments: https://developers.cloudflare.com/workers/wrangler/environments/
- C9 `workers.dev`: https://developers.cloudflare.com/workers/configuration/routing/workers-dev/index.md
- C10 Workers Logs: https://developers.cloudflare.com/workers/observability/logs/workers-logs/

Supabase:

- B1 Function configuration: https://supabase.com/docs/guides/functions/function-configuration
- B2 API keys: https://supabase.com/docs/guides/getting-started/api-keys
- B3 CLI configuration: https://supabase.com/docs/guides/local-development/cli/config
- B4 Edge Function limits: https://supabase.com/docs/guides/functions/limits
- B5 Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- B6 Connecting to Postgres: https://supabase.com/docs/guides/database/connecting-to-postgres
- B7 Edge Function secrets: https://supabase.com/docs/guides/functions/secrets
- B8 Securing your API: https://supabase.com/docs/guides/api/securing-your-api
- B9 Auth rate limits: https://supabase.com/docs/guides/auth/rate-limits
- B10 Securing Edge Functions: https://supabase.com/docs/guides/functions/auth
- B11 Production checklist: https://supabase.com/docs/guides/deployment/going-into-prod
