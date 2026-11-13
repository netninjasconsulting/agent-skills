# The checks

Nine groups, in the order to run them. Each group says what to look for, how to find it, and what counts as a finding. The search patterns are starting points. Follow the code from each hit to the place where the decision is made.

Every command here only reads. If a command would write, install, or call the network, do not run it.

## Contents

1. [Secrets](#1-secrets)
2. [Sign-in and authorisation](#2-sign-in-and-authorisation)
3. [Database rules](#3-database-rules)
4. [API surface](#4-api-surface)
5. [Cloud and provider keys](#5-cloud-and-provider-keys)
6. [Dependencies](#6-dependencies)
7. [LLM features](#7-llm-features)
8. [Launch basics](#8-launch-basics)
9. [Personal data (flag only)](#9-personal-data-flag-only)

## 1. Secrets

Run the scanner from SKILL.md step 3, then triage its hit types.

| Hit type | Finding? |
| --- | --- |
| `committed-env-file` | Yes when the file holds any value the scanner flags. An env file with only public settings is a hardening note. |
| `server-secret-behind-public-prefix` | Yes, reach "Anyone on the internet". The build inlines `NEXT_PUBLIC_`, `VITE_`, `EXPO_PUBLIC_`, `REACT_APP_`, `NUXT_PUBLIC_`, `GATSBY_`, and `PUBLIC_` values into the client bundle. |
| `private-key-block`, `aws-access-key-id`, `github-token`, `stripe-secret-key`, `stripe-webhook-secret`, `openai-api-key`, `anthropic-api-key`, `google-api-key`, `slack-token`, `supabase-secret-key`, `database-url-with-password` | Yes when the path is `tracked` or the hit is in history. `ignored` and `untracked` hits are local only: mention them once as a note, not as findings. |
| `json-web-token` | Depends on the variable name on that line (read it with `--show`). A Supabase `anon` or publishable key is public by design. A `service_role` key, or any token used as a credential, is a finding. |
| `env-file-value`, `possible-secret-assignment` | Read the name with `--show`. A name that says secret, token, password, or private key with a real-looking value is a finding. Placeholders (`changeme`, `xxx`, `your-key-here`) are not. |

Values that vendors publish as documentation examples still count as findings when they sit where a real key would. The fix is the same: the real key will land in the same place.

**History.** A secret that reached any commit is compromised. The fix order is: rotate the key at the provider, then remove it from the code, then decide whether to rewrite history. Rewriting history alone does not make the old key safe.

**Fix pattern.** Server-only variable names, values in the host's secret store, `.env*` in `.gitignore`, and an `.env.example` with names only.

## 2. Sign-in and authorisation

For every server entry point from the map, answer two questions: who may call this, and where does the code check it?

- **No auth check.** A handler that reads or writes user data without reading a session, a token, or a framework guard. Look for the project's own session helper first (`getServerSession`, `auth()`, `getUser`, `currentUser`, `verifyIdToken`, `requireUser`, a middleware matcher) and list the handlers that never reach it.
- **Auth only in the browser.** A redirect or a hidden button in client code (`"use client"`, `useEffect`, `localStorage`, a route guard component) with no matching check in the handler it protects. The handler is still open.
- **Missing ownership check.** A handler that takes an ID from the path, the query, or the body and loads the record without tying it to the caller: `where: { id }` with no `userId`, `.eq("id", id)` with no user filter and no row level security.
- **Role from the client.** `isAdmin`, `role`, or `plan` read from the request body, a cookie the app does not sign, or `localStorage`.
- **Cookies and sessions.** Session cookies without `HttpOnly`, `Secure`, and `SameSite`. A JWT secret that is short, a default, or in the code. Tokens with no expiry. Sessions kept in `localStorage`.
- **Password reset and email verification.** Reset tokens that are guessable, never expire, or can be reused. A reset that takes the user ID or the email from the request body after the token check. Sign-up that grants access before the email is verified, when the app relies on verified email.

Reach is "Anyone on the internet" when no account is needed and "Any signed-in user" when any account will do.

## 3. Database rules

**Supabase and Postgres.**

- List every table in the schema and migrations (`create table`). For each one in an exposed schema (`public` by default), look for `enable row level security`. A table without it is readable and writable with the public key.
- Read each policy. `using (true)`, `with check (true)`, or a policy `for all` granted to `anon` or `public` on a table with user data is a finding. A policy that never references `auth.uid()` on a per-user table is a finding.
- `service_role` or a secret key in client code, in a public-prefixed variable, or in a file that client components import.
- A Postgres connection string in client code or behind a public prefix.
- `security definer` functions that are callable by `anon` or `authenticated` and skip their own checks.

**Firebase.**

- `firestore.rules`, `database.rules.json`, `storage.rules`: `allow read, write: if true`, a match on `/{document=**}` with open access, rules that only check `request.auth != null` on data that belongs to one user, or a rules file that is missing while the SDK is in use.
- Rules in "test mode" with a date condition.

**Any SQL database.** The app's database user is an owner or superuser. Migrations run from the app at start-up with that user.

Open rules that the public key can reach belong in "Anyone on the internet".

## 4. API surface

- **Unauthenticated endpoints.** Carried over from group 2. List each one once.
- **Input validation.** Handlers that pass `request.json()`, `req.body`, or query values straight into a query, a file path, a shell command, a redirect, or an HTML response with no schema check (Zod, Valibot, Pydantic, Joi, class-validator, or the framework's own).
- **SQL built by string concatenation.** `"... WHERE id = '" + id + "'"`, template literals inside `query(...)`, `$queryRawUnsafe`, `execute(f"...")`, `.raw(` with interpolation. The fix is a parameterised query.
- **Rate limits.** No limiter on sign-in, sign-up, password reset, or any endpoint that costs money per call (LLM calls, SMS, email, payments). Look for a limiter library or a platform rule. "not found in the repository" is the finding, and the report notes that a platform rule may exist outside the repository.
- **CORS.** `Access-Control-Allow-Origin: *` together with credentials, an origin that is reflected from the request, or a wildcard on an API that uses cookies.
- **Webhooks.** A handler for Stripe, GitHub, Clerk, Resend, or a similar sender that parses the body without verifying the signature header (`stripe.webhooks.constructEvent`, `svix`, an HMAC compare). Anyone can post a fake "payment succeeded".
- **Uploads.** No size limit, no type check, the client's file name used as the path, files written under a web-served folder, or presigned URLs with no content-type or size condition.
- **Errors.** Stack traces or raw database errors returned to the caller.

## 5. Cloud and provider keys

- **Long-lived keys.** `aws_iam_access_key`, static cloud keys in CI secrets used by a deploy job (`AWS_ACCESS_KEY_ID`, a service account JSON key), or provider tokens with no expiry. The fix is OIDC from the pipeline, with short-lived credentials.
- **Wildcard IAM.** `"Action": "*"`, `"Resource": "*"` on write actions, `AdministratorAccess` attached to an app role, `roles/owner` or `roles/editor` on a service account.
- **Public storage.** `acl = "public-read"` or `"public-read-write"`, public access blocks set to `false`, bucket policies with `"Principal": "*"`, `allUsers` bindings, a public R2 or storage bucket that holds user uploads.
- **Scope.** A token that can do more than the app needs: an account-wide Cloudflare token, a GitHub token with `repo` scope for a job that only reads, a Stripe secret key where a restricted key fits, a database owner role for the app.
- **Open network paths.** Security groups or firewall rules that open a database port or SSH to `0.0.0.0/0`.

Only infrastructure code and config in the repository can be read. The live account is under "Not checked".

## 6. Dependencies

**Offline, always.**

- **Missing lockfile.** A manifest with no lockfile next to it (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, `uv.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock`). Every install can pull different code.
- **Lockfile ignored.** A lockfile named in `.gitignore`.
- **Loose sources.** Dependencies from a Git URL without a commit, a tarball URL, or `latest`.
- **Install scripts.** `preinstall` or `postinstall` scripts in the project's own manifest that fetch and run remote code.

**With the registry yes from step 1, and only with tools already installed.**

- **Names that do not exist, or look like typosquats.** For each direct dependency, ask the registry whether the name exists: `npm view <name> name`, `pip index versions <name>`, `cargo search <name> --limit 1`. A name that does not exist, a package first published in the last few weeks with few downloads, or a name one character away from a well-known package is a finding. AI coding tools invent package names, and attackers register them.
- **Known-vulnerable versions.** Use the ecosystem's own command, read-only: `npm audit --json`, `pnpm audit --json`, `yarn npm audit --json`, `bun audit`, `pip-audit`, `cargo audit`, `govulncheck ./...`, `bundle audit check`, `composer audit`. Never run a variant that changes files (`audit fix`). Report high and critical results in packages the app loads at runtime. Summarise the rest as a count.

If a tool is not installed, do not install it. List the check under "Not checked".

## 7. LLM features

- **Model key in the client.** A provider key behind a public prefix or in client code. Reach "Anyone on the internet".
- **User input with tools or secrets.** A prompt built from user input in a call that also has tools, function calling, database access, file access, or secrets in the system prompt. Check what each tool can do without a second, server-side permission check. A tool that runs SQL, fetches a URL, sends an email, or writes files on the model's say-so is a finding.
- **Model output trusted as code or markup.** Output passed to `eval`, a shell, a SQL query, `dangerouslySetInnerHTML`, or a redirect.
- **No spend cap.** An LLM endpoint with no sign-in, no rate limit, no `max_tokens` or equivalent, and no per-user quota. One script can spend the budget.
- **Logs.** Prompts and completions logged in full when they contain personal data or secrets.

## 8. Launch basics

- **Debug mode on.** `DEBUG=true`, `NODE_ENV=development` in a committed production env file, Django `DEBUG = True`, Flask `debug=True`, Rails `consider_all_requests_local = true`, source maps served in production.
- **Verbose errors.** Stack traces or framework error pages shown to users.
- **Default admin credentials.** A seeded or hard-coded admin account with a fixed or well-known password. Report the path and line, and write the password as `<redacted:default-password>`.
- **Seed or test data on production paths.** A seed script wired into the build, the start command, or a migration that runs everywhere. Test routes, `/debug`, or `/api/test` handlers that ship.
- **Missing basics.** No `.gitignore` entry for env files. No security headers set anywhere in the app or the platform config (`Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`). These are hardening notes unless something else depends on them.

## 9. Personal data (flag only)

List where personal data lives and whether it reaches the logs. Draw no legal conclusion.

- **Stored.** Columns and fields such as email, name, phone, address, date of birth, IP address, payment details, and health or location data. Give the schema file and line.
- **Logged.** `console.log`, a logger call, or an analytics event that includes those fields, request bodies, or auth headers. Passwords and tokens in logs are a security finding and belong in group 4 or group 8 as well.
- **Sent on.** Third-party SDKs that receive those fields (analytics, error tracking, LLM providers). Name the SDK and the call site.

Each line in the report reads: what kind of data, where it is stored, and where it is logged or sent, or "No logging of it found in the repository."
