# Snippets

Fixes to paste, by check and by platform. The setting names come from [platforms.md](platforms.md). Adapt names and paths to the repository, and say which lines were adapted.

Every value is a placeholder in angle brackets. A snippet shows where a setting goes and leaves the value to the team: the skill never says what a memory size, a time limit, a concurrency ceiling, a rate, or a retention period should be. Here, "verify" marks a name, a key, or a form that does not come from [platforms.md](platforms.md), or that it marks "verify": it was not read in the provider's documentation on 15 November 2026, so read the current page before pasting it. A secret never goes into a snippet, as a value or as an example.

Where a platform has no setting for a check, its section says so, and the fix sits in code or in the provider's console.

## Contents

1. [E1. Memory](#e1-memory)
2. [E2. Time limit](#e2-time-limit)
3. [E3. Concurrency and fan-out](#e3-concurrency-and-fan-out)
4. [E4. Runtime and architecture](#e4-runtime-and-architecture)
5. [E5. Deploy package](#e5-deploy-package)
6. [E6. Clients and connections](#e6-clients-and-connections)
7. [E7. Streaming](#e7-streaming)
8. [E8. Start-up work](#e8-start-up-work)
9. [S1. Caller check](#s1-caller-check)
10. [S2. Permissions](#s2-permissions)
11. [S3. Secrets in the store](#s3-secrets-in-the-store)
12. [S4. Nothing secret in the browser](#s4-nothing-secret-in-the-browser)
13. [S5. Row-level security](#s5-row-level-security)
14. [S6. Webhooks and schedules](#s6-webhooks-and-schedules)
15. [S7. Size limit and rate limit](#s7-size-limit-and-rate-limit)
16. [S8. Cross-origin rules](#s8-cross-origin-rules)
17. [S9. Short-lived deploy credentials](#s9-short-lived-deploy-credentials)
18. [S10. Logs](#s10-logs)

## E1. Memory

**AWS Lambda.** Set memory on each function, or once for every function. CPU follows memory. Choose the value from measured use.

```yaml
# serverless.yml
provider:
  memorySize: <MB, from measured use>
functions:
  <function>:
    memorySize: <MB, from measured use>
```

```yaml
# template.yaml (SAM)
Globals:
  Function:
    MemorySize: <MB, from measured use>
```

```hcl
# Terraform
resource "aws_lambda_function" "<name>" {
  memory_size = <MB, from measured use>
}
```

**Vercel.** No file setting. Memory and CPU are the dashboard setting "Function CPU". Remove a `memory` key from `vercel.json` `functions`: with Fluid compute Vercel does not take it.

**Cloudflare Workers and Supabase.** Memory is fixed, with no setting.

## E2. Time limit

**AWS Lambda.** Set a time limit below 900 seconds on each function.

```yaml
# serverless.yml
functions:
  <function>:
    timeout: <seconds, below 900>
```

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Type: AWS::Serverless::Function
    Properties:
      Timeout: <seconds, below 900>
```

```hcl
# Terraform
resource "aws_lambda_function" "<name>" {
  timeout = <seconds, below 900>
}
```

**Vercel.** In the route file, or in `vercel.json`. Code wins over `vercel.json`. Keep it below the plan's maximum, and do not use `"max"`.

```ts
// app/<route>/route.ts
export const maxDuration = <seconds, below the plan's maximum>;
```

```json
{
  "functions": {
    "<glob, such as app/api/**/route.ts>": { "maxDuration": <seconds, below the plan's maximum> }
  }
}
```

**Cloudflare Workers.** A limit on CPU time, below 300,000 ms. An HTTP request has no setting for elapsed time.

```toml
# wrangler.toml
[limits]
cpu_ms = <milliseconds, below 300000>
```

**Supabase.** The limits are fixed, with no setting.

## E3. Concurrency and fan-out

**AWS Lambda.** Reserved concurrency caps a function on every entry point, including a function URL. Use a value above 0: `0` stops every invocation.

```yaml
# serverless.yml
functions:
  <function>:
    reservedConcurrency: <ceiling, above 0>
    events:
      - sqs:
          arn: <queue ARN> # key name: verify
          maximumConcurrency: <ceiling>
```

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      ReservedConcurrentExecutions: <ceiling, above 0>
```

```hcl
# Terraform
resource "aws_lambda_function" "<name>" {
  reserved_concurrent_executions = <ceiling, above 0>
}
```

**Vercel, Cloudflare Workers, and Supabase.** No concurrency setting was found in a file (verify). The fix is the bound on fan-out in code.

**Every platform, in code.** Bound a fan-out over a list: cap the list, then work in fixed batches.

```ts
const MAX_ITEMS = <cap>;
const BATCH = <batch size>;
if (items.length > MAX_ITEMS) return new Response("Too many items", { status: 413 });
for (let i = 0; i < items.length; i += BATCH) {
  await Promise.all(items.slice(i, i + BATCH).map(handleItem));
}
```

## E4. Runtime and architecture

**AWS Lambda.** A runtime from the supported list in [platforms.md](platforms.md), and the architecture written out. Both `x86_64` and `arm64` are current.

```yaml
# serverless.yml
provider:
  runtime: <a supported runtime, such as an identifier from platforms.md>
  architecture: <x86_64 or arm64> # provider level: verify
```

```yaml
# template.yaml (SAM)
Globals:
  Function:
    Runtime: <a supported runtime>
    Architectures:
      - <x86_64 or arm64>
```

```hcl
# Terraform
resource "aws_lambda_function" "<name>" {
  runtime       = "<a supported runtime>"
  architectures = ["<x86_64 or arm64>"]
}
```

**Cloudflare Workers.** A recent compatibility date. Read the changes between the old date and the new one before deploying.

```toml
# wrangler.toml
compatibility_date = "<YYYY-MM-DD, recent>"
```

**Vercel and Supabase.** No runtime setting was confirmed (verify).

## E5. Deploy package

**AWS Lambda, Serverless Framework.** Package each function on its own, from only what it runs.

```yaml
# serverless.yml
package:
  individually: true
  patterns:
    - "!**" # pattern form: verify
    - "<path the function runs>/**"
```

**AWS Lambda, SAM and Terraform.** Point `CodeUri` or `filename` at a folder or archive that holds the function's own code, and build that archive from what the handler imports.

**Vercel.** Leave out what the function does not run. The form of the `excludeFiles` value: verify.

```json
{
  "functions": {
    "<glob>": { "excludeFiles": "<pattern of files the function does not run>" }
  }
}
```

```js
// next.config.js
module.exports = {
  outputFileTracingExcludes: { // shape of the map: verify
    "<route>": ["<pattern of files the route does not run>"],
  },
};
```

**Cloudflare Workers.** Wrangler bundles from `main`. Point `assets.directory` at the built front end only, never at the repository root.

```toml
# wrangler.toml
main = "<path to the Worker entry file>"

[assets]
directory = "<path to the built static files>"
```

**Supabase.** The CLI bundles from the entry file. List only the files the function reads in `static_files`.

```toml
# supabase/config.toml
[functions.<name>]
static_files = ["<path the function reads>"]
```

**Every platform.** Remove a runtime dependency that no function imports from `package.json`.

## E6. Clients and connections

**Every platform, in code.** Create a client once, at module scope, and reuse it in the handler.

```ts
const client = createClient(<settings, read from the environment>);

export async function handler(event) {
  // use client here; do not create a new one
}
```

**Supabase, from any function.** Reach PostgreSQL through the transaction pooler, on port 6543, with one connection for each function instance and prepared statements off. Keep the connection string in the secret store, under a name.

```ts
import postgres from "postgres"; // client library and option names: verify

const sql = postgres(process.env.<DATABASE_URL name>, { max: 1, prepare: false, ssl: "require" });
```

**Cloudflare Workers.** Reach PostgreSQL or MySQL through a Hyperdrive binding. With Hyperdrive, a new client for each request is the reuse Cloudflare advises.

```toml
# wrangler.toml
[[hyperdrive]]
binding = "<BINDING>"
id = "<Hyperdrive id>"
```

**AWS Lambda.** RDS Proxy pools connections for functions (verify).

## E7. Streaming

**Every platform, in code.** Pipe a download, a stored file, or an export through. Do not read it whole.

```ts
const upstream = await fetch(<url>);
return new Response(upstream.body, { headers: { "content-type": <type> } });
```

**AWS Lambda.** Stream the response of a function URL.

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      FunctionUrlConfig:
        AuthType: <AWS_IAM or NONE>
        InvokeMode: RESPONSE_STREAM
```

```hcl
# Terraform
resource "aws_lambda_function_url" "<name>" {
  invoke_mode = "RESPONSE_STREAM"
}
```

```yaml
# serverless.yml
functions:
  <function>:
    url:
      invokeMode: RESPONSE_STREAM
```

The handler side, `awslambda.streamifyResponse` in Node.js, was not confirmed (verify).

**Cloudflare Workers and Supabase.** Check a request body's size before reading it whole. See S7.

## E8. Start-up work

**Every platform, in code.** Keep module scope to imports, constants, and client creation. Move a network call, a query, or a large file read into the handler, and run it once on first use.

```ts
let table;

async function getTable() {
  table ??= await loadTable();
  return table;
}

export async function handler(event) {
  const t = await getTable();
}
```

**AWS Lambda.** Provisioned concurrency keeps environments started. It is never needed for a pass.

```yaml
# serverless.yml
functions:
  <function>:
    provisionedConcurrency: <count>
```

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      AutoPublishAlias: <alias>
      ProvisionedConcurrencyConfig:
        ProvisionedConcurrentExecutions: <count>
```

The SAM property under `ProvisionedConcurrencyConfig` was not confirmed (verify).

## S1. Caller check

**AWS Lambda.** Turn on IAM sign-in for a function URL, or put a JWT authoriser on an HTTP API.

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      FunctionUrlConfig:
        AuthType: AWS_IAM
```

```hcl
# Terraform
resource "aws_lambda_function_url" "<name>" {
  authorization_type = "AWS_IAM"
}
```

```yaml
# serverless.yml
provider:
  httpApi:
    authorizers:
      <authoriser name>:
        type: jwt
        issuerUrl: <issuer URL>
        audience:
          - <audience>
functions:
  <function>:
    url:
      authorizer: aws_iam
    events:
      - httpApi:
          path: <path>
          method: <method>
          authorizer:
            name: <authoriser name>
```

**Vercel.** Check the caller at the top of the route, before any work.

```ts
// app/<route>/route.ts
export async function POST(request: Request) {
  const session = await getSession(request); // the app's own session check
  if (!session) return new Response("Unauthorised", { status: 401 });
  // work starts here
}
```

**Cloudflare Workers.** Turn off the `workers.dev` address when the Worker has routes, and check the caller at the top of `fetch`.

```toml
# wrangler.toml
workers_dev = false
routes = [{ pattern = "<host>/<path>*", zone_name = "<zone>" }] # zone_name: verify
```

```ts
export default {
  async fetch(request, env) {
    if (!(await isAllowedCaller(request, env))) return new Response("Unauthorised", { status: 401 });
    // work starts here
  },
};
```

**Supabase.** Keep the platform's JWT check on, and check the user in code: the check alone proves only that the caller holds a key.

```toml
# supabase/config.toml
[functions.<name>]
verify_jwt = true
```

## S2. Permissions

**AWS Lambda, Serverless Framework.** One role for each function, with named actions on named resources.

```yaml
# serverless.yml
provider:
  iam:
    role:
      mode: perFunction
functions:
  <function>:
    iam:
      role:
        statements:
          - Effect: Allow
            Action:
              - <service:Action the code calls>
            Resource:
              - <ARN of the resource it touches>
```

**AWS Lambda, SAM.**

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      Policies:
        - Statement:
            - Effect: Allow
              Action:
                - <service:Action the code calls>
              Resource: <ARN of the resource it touches>
```

**AWS Lambda, Terraform.** The resource and attribute names were not confirmed (verify).

```hcl
resource "aws_iam_role_policy" "<name>" {
  role = aws_iam_role.<function role>.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["<service:Action the code calls>"]
      Resource = ["<ARN of the resource it touches>"]
    }]
  })
}
```

**Vercel.** Scope each environment variable to the environments that need it, in the dashboard. Remove a variable that no function reads.

**Cloudflare Workers.** Remove each binding the Worker's code never uses, at the level it deploys from, including each `env.<name>`.

**Supabase.** Behind a caller check, act as the caller: use the publishable key with the caller's JWT, so that row-level security applies. Keep the secret key for the work that needs it, behind a caller check.

```ts
// passing the caller's Authorization header this way: verify
const supabase = createClient(<project URL>, <publishable key name>, {
  global: { headers: { Authorization: request.headers.get("Authorization") } },
});
```

## S3. Secrets in the store

**AWS Lambda.** Read a secret at run time from Secrets Manager, or resolve a reference at deploy time. Remove the value from the environment map.

```yaml
# serverless.yml
functions:
  <function>:
    environment:
      <SECRET_NAME>: ${ssm:<parameter path>} # reference syntax: verify
```

**Vercel.** Move the value out of `vercel.json` `env` into a Secret variable, then delete the key from `vercel.json`. The CLI prompts for the value.

```sh
vercel env add <SECRET_NAME> production --sensitive # environment argument: verify
```

**Cloudflare Workers.** Move the value out of `vars` into a secret. Wrangler prompts for the value. List the name under `secrets.required`.

```sh
npx wrangler secret put <SECRET_NAME>
```

```toml
# wrangler.toml
[secrets]
required = ["<SECRET_NAME>"]
```

**Supabase.** Set function secrets from a local file that Git ignores, and reference a secret in `config.toml` by name.

```sh
supabase secrets set --env-file <path to an ignored env file>
```

```toml
# supabase/config.toml
[auth.external.<provider>]
secret = "env(<SECRET_NAME>)"
```

**Every platform.** Remove a tracked env file from Git with `git rm --cached <file>`, add it to `.gitignore`, and rotate every secret it held: it stays in the history.

## S4. Nothing secret in the browser

**Vercel and any Next.js front end.** Drop the public prefix from a server secret and read it on the server only.

```ts
// a server file, never a "use client" file
const key = process.env.<SECRET_NAME>; // no NEXT_PUBLIC_ prefix
```

**Supabase.** The browser gets the publishable key only.

```ts
const supabase = createClient(<project URL>, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
```

Rotate a secret that has shipped in a bundle: renaming it does not take it back.

## S5. Row-level security

**Supabase and any PostgreSQL schema.** In a new migration, turn row-level security on for each exposed table, and limit each policy to the caller's rows.

```sql
-- supabase/migrations/<timestamp>_row_level_security.sql
alter table public.<table> enable row level security;

drop policy if exists "<old policy name>" on public.<table>;

create policy "<table>: owner reads"
  on public.<table> for select
  to authenticated
  using ((select auth.uid()) = <owner column>);

create policy "<table>: owner writes"
  on public.<table> for insert
  to authenticated
  with check ((select auth.uid()) = <owner column>);
```

A view in an exposed schema runs as the caller:

```sql
create or replace view public.<view> with (security_invoker = true) as <query>;
```

## S6. Webhooks and schedules

**Vercel.** A scheduled path compares `CRON_SECRET`, set as a project variable.

```ts
// app/<cron route>/route.ts
export async function GET(request: Request) {
  if (request.headers.get("authorization") !== `Bearer ${process.env.CRON_SECRET}`) {
    return new Response("Unauthorised", { status: 401 });
  }
  // work starts here
}
```

**Every platform, a webhook.** Check the provider's signature over the raw body before acting. Use the provider's own verification library where it has one. The header name and the signing scheme come from the provider.

```ts
import { createHmac, timingSafeEqual } from "node:crypto";

const raw = await request.text();
const expected = createHmac("sha256", process.env.<WEBHOOK_SECRET name>).update(raw).digest("hex");
const given = request.headers.get("<signature header>") ?? "";
const ok = given.length === expected.length && timingSafeEqual(Buffer.from(given), Buffer.from(expected));
if (!ok) return new Response("Unauthorised", { status: 401 });
// parse raw and act here
```

**Supabase.** A webhook function turns off the JWT check and checks the signature in code, as above.

```toml
# supabase/config.toml
[functions.<webhook function>]
verify_jwt = false
```

**AWS Lambda and Cloudflare Workers.** A `schedule` event or `triggers.crons` has no public address and needs no check. A webhook checks its signature in code, as above.

## S7. Size limit and rate limit

**Every platform, in code.** Check the size before reading the body.

```ts
const MAX_BYTES = <limit>;
const length = Number(request.headers.get("content-length") ?? "0");
if (!length || length > MAX_BYTES) return new Response("Payload too large", { status: 413 });
```

A missing `content-length` is refused here. A function that must take a body without one counts the bytes as it reads the stream.

**AWS Lambda, Serverless Framework.** A rate limit and a quota on a REST API. A function URL has no rate limit setting: reserved concurrency (E3) is its only cap.

```yaml
# serverless.yml
provider:
  apiGateway:
    usagePlan:
      throttle:
        burstLimit: <burst>
        rateLimit: <requests per second>
      quota: # limit and period keys: verify
        limit: <requests>
        period: <period>
```

**Vercel.** Rate limiting is a Firewall rule, set in the dashboard (outside the repository), or a limit in code.

**Cloudflare Workers.** A rate limit binding, called before the work. The call in code was not confirmed (verify).

```toml
# wrangler.toml
[[ratelimits]]
name = "<BINDING>"
namespace_id = "<namespace id>"
simple = { limit = <requests>, period = <10 or 60> }
```

```ts
const { success } = await env.<BINDING>.limit({ key: <caller id> }); // verify
if (!success) return new Response("Too many requests", { status: 429 });
```

**Supabase.** A size limit on uploads. No rate limit setting for a function was found: use a limit in code.

```toml
# supabase/config.toml
[storage]
file_size_limit = "<size>"
```

## S8. Cross-origin rules

**AWS Lambda.** Name the origins of a function URL.

```yaml
# template.yaml (SAM)
Resources:
  <Function>:
    Properties:
      FunctionUrlConfig:
        Cors:
          AllowOrigins:
            - <https://app origin>
```

```hcl
# Terraform
resource "aws_lambda_function_url" "<name>" {
  cors {
    allow_origins = ["<https://app origin>"]
  }
}
```

```yaml
# serverless.yml
functions:
  <function>:
    url:
      cors:
        allowedOrigins:
          - <https://app origin>
```

**Vercel.**

```json
{
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [{ "key": "Access-Control-Allow-Origin", "value": "<https://app origin>" }]
    }
  ]
}
```

**Cloudflare Workers and Supabase, and any route in code.** Answer only origins on a list. Never echo the request's `Origin` without it.

```ts
const ALLOWED = new Set(["<https://app origin>"]);
const origin = request.headers.get("Origin");
const headers = new Headers();
if (origin && ALLOWED.has(origin)) {
  headers.set("Access-Control-Allow-Origin", origin);
  headers.set("Vary", "Origin");
}
```

## S9. Short-lived deploy credentials

**AWS Lambda.** Sign in with OIDC and a role, and delete the stored access keys. The role's trust policy and the full job are in the [GitOps hygiene check's snippets](../../gitops-hygiene-check/references/snippets.md#oidc-deploy-without-stored-keys).

```yaml
# .github/workflows/<deploy>.yml
permissions:
  contents: read
  id-token: write
steps:
  - uses: aws-actions/configure-aws-credentials@<commit-sha> # <tag>
    with:
      role-to-assume: ${{ vars.<ROLE_ARN name> }}
      aws-region: <region>
```

**Vercel, Cloudflare Workers, and Supabase.** No short-lived option was confirmed (verify). Read the token from the repository's secrets, never from the workflow file, scope it to this project at the provider, and rotate it.

```yaml
env:
  <TOKEN_NAME>: ${{ secrets.<TOKEN_NAME> }}
```

## S10. Logs

**Every platform, in code.** Log an identifier and an outcome, never a request, a body, the headers, a whole event, or `process.env`.

```ts
console.log(JSON.stringify({ requestId: <request id>, route: <route>, status: <status> }));
```

**AWS Lambda.** A retention period for each function's log group. `0` keeps events for ever.

```yaml
# serverless.yml
provider:
  logRetentionInDays: <days, a value CloudWatch accepts>
```

```hcl
# Terraform
resource "aws_cloudwatch_log_group" "<name>" {
  name              = "/aws/lambda/<function name>"
  retention_in_days = <days, a value CloudWatch accepts>
}
```

**Cloudflare Workers.** Retention is set by the plan. `logpush` sends events to a destination with its own retention.

**Vercel and Supabase.** No retention setting was found in a file (verify). Retention is set outside the repository.
