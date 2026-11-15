# The reach map

One row for each function that the function map found: what can call it, and what it can reach. The map is the evidence for S1 and S2 in [checks.md](checks.md). The setting names come from [platforms.md](platforms.md).

Configuration is read through `sh scripts/read-serverless-config.sh --show FILE` only. Source code is read directly. Every cell names a file and a line, or says "not found in the repository". A cell whose setting the reader hides says "not found in what the reader shows", and the line goes under "Not checked".

**Secret names only.** The map names a secret by its variable or key name. It never holds a value, a part of one, or a connection string.

## The columns

| Column | What it holds |
| --- | --- |
| Function | The function's name, its platform, and its handler file with a line. |
| Entry point | What can call it: a route, a function URL, an API event, a webhook, a schedule, a queue, or an internal event. Say whether it is public. |
| Caller check | How the function checks who is calling: the setting or the code, with its line, or "none". |
| Permissions | What the function runs with: an IAM role and its statements, Workers bindings, a Supabase key type, or the Vercel environment variables it reads, by name. |
| Secret names | The names of the secrets it reads, and where each one is set. |
| Data stores | The stores it can read or write, and whether it reads, writes, or both. |
| Mark | "scoped", "broad", or "not found in the repository". |

## How to find each column

### Entry point

- **AWS Lambda:** Serverless `events` (`http`, `httpApi`, `schedule`, `sqs`) and `url`; SAM `Events` and `FunctionUrlConfig`; Terraform `aws_lambda_function_url`, `aws_lambda_permission`, and event source resources. A function URL and an API route are two entry points: list both. A function with no trigger in the repository has the entry point "not found in the repository".
- **Vercel:** the route file's path (`app/**/route.ts`, `pages/api/**`, `api/`) and the exported methods; `vercel.json` `crons` and `schedules`. Every route is public unless its code checks the caller.
- **Cloudflare Workers:** `routes`, `route`, and `workers_dev` in the Wrangler file, and the handlers in `main` (`fetch`, `scheduled`, `queue`). With no `routes` and no `workers_dev = false`, the Worker has a `workers.dev` address.
- **Supabase:** the folder name under `supabase/functions/`. Every Edge Function has a public address. `verify_jwt` decides whether the platform checks a JWT first.

### Caller check

- **AWS Lambda:** `AuthType` or `authorization_type` (`AWS_IAM` or `NONE`), Serverless `url.authorizer`, `httpApi` authorisers, `http` `authorizer` and `private`, and any check at the top of the handler.
- **Vercel:** the code at the top of the route: a session, a token, a `CRON_SECRET` comparison, or a webhook signature.
- **Cloudflare Workers:** the code at the top of `fetch`. A `scheduled` or `queue` handler has no public caller.
- **Supabase:** `verify_jwt`, the `withSupabase` `auth` mode, and any signature or token check in the handler.

### Permissions

- **AWS Lambda:** the execution role. Serverless: `provider.iam.role.statements`, `functions.<name>.iam.role.statements`, `iam.role.mode` (`shared` by default, so every function gets every statement), and `managedPolicies`. SAM: `Role`, or `Policies` on the function. Terraform: the `role` of the function, and the `aws_iam_role_policy`, `aws_iam_policy`, or `aws_iam_policy_document` attached to that role. List each statement's `Effect`, `Action`, and `Resource`. A policy the reader hides whole is "not found in what the reader shows".
- **Vercel:** no IAM. List the environment variable names that the function's code reads. Which environments hold them is set in the dashboard.
- **Cloudflare Workers:** every binding in the Wrangler file at the level the Worker deploys from (`kv_namespaces`, `r2_buckets`, `d1_databases`, `durable_objects`, `queues`, `services`, `hyperdrive`, `ai`, and the rest), and the `vars` names. Bindings in an `env.<name>` are not inherited from the top, so list the environment used. A binding is a permission whether or not the code uses it.
- **Supabase and any route that reaches Supabase:** the key type the code uses. The publishable or anon key is subject to row-level security. A secret key, a `service_role` key, or `ctx.supabaseAdmin` bypasses it.

### Secret names

The names of the secrets the function reads in code (`process.env.NAME`, `env.NAME`, `Deno.env.get("NAME")`), and where each is set: a secret store, a reference the reader shows, an env file with its Git state, or "not found in the repository". Use the secret names in [checks.md](checks.md) under S3.

### Data stores

The stores the function reaches: a Supabase table through the client or a REST call, a PostgreSQL database through a connection string, an S3 bucket, a KV namespace, an R2 bucket, a D1 database, a queue, or an outside service by host. Say whether it reads, writes, or both, from the code, with the line.

## The marks

| Mark | When |
| --- | --- |
| scoped | Every permission names its actions and its resources, every binding and key is one the code uses, the caller check is in place or the function is public on purpose, and no key bypasses row-level security. |
| broad | Any permission allows more than the code uses (`*` as an action or a resource, a shared role, an unused binding, or a key that bypasses row-level security), or anyone can call the function and it is not public on purpose. Name the part that makes it broad. |
| not found in the repository | The permissions are not in the repository or not shown by the reader, such as a role defined elsewhere or a policy the reader hides whole. Name what is missing. |

A row is broad when its permissions are broad or when anyone can call it and it is not public on purpose, even when its permissions are narrow. A row with one broad part is broad. A row whose permissions are partly hidden and otherwise scoped is "not found in the repository", because what is hidden can be broad. Under S2, a "not found in the repository" row is "ask the team" when its permissions are hidden or defined outside the repository, and follows the status table when no permissions are found at all.
