# CI/CD baseline

What step 8 scaffolds, in order. The target is the 10-check safety net published at https://www.netninjas.eu/events/vibe-coding-safety-net: a pipeline that can say no.

Every remote change in this file needs its own confirmation card (SKILL.md, rule 2). Local files need none. Commands are shown in the shape to use. Check each one against the CLI's own `--help` before running it, because flags change between versions.

## Contents

1. [Before anything remote](#1-before-anything-remote)
2. [Local files](#2-local-files)
3. [The repository](#3-the-repository)
4. [Branch protection](#4-branch-protection)
5. [Secret scanning and dependency updates](#5-secret-scanning-and-dependency-updates)
6. [Deploys by provider](#6-deploys-by-provider)
7. [The production environment](#7-the-production-environment)
8. [Stored tokens](#8-stored-tokens)
9. [What stays for the user](#9-what-stays-for-the-user)

## 1. Before anything remote

Check each sign-in with a status command. Never run a sign-in command for the user, and never accept a token in chat.

| Provider | Status command | Sign-in command the user runs |
| --- | --- | --- |
| GitHub | `gh auth status` | `gh auth login` |
| Vercel | `vercel whoami` | `vercel login` |
| Cloudflare | `wrangler whoami` | `wrangler login` |
| AWS | `aws sts get-caller-identity` | `aws sso login`, or the sign-in the user's organisation uses |
| Neon | `neonctl me` | `neonctl auth` |
| Supabase | `supabase projects list` | `supabase login` |
| Firebase | `firebase login:list` | `firebase login` |
| Expo | `eas whoami` | `eas login` |

If a CLI is not installed, name it and its install page, and wait. Do not install it.

## 2. Local files

Create these in the project folder before the first commit.

- **`.gitignore`**: dependencies, build output, `.env*` with an exception for `.env.example`, and for infrastructure code `*.tfstate*` and `.terraform/`.
- **`.env.example`**: every variable name the app reads, with no values.
- **The lockfile**, committed.
- **`.github/workflows/ci.yml`**: lint, type check, tests, and build on every pull request and on pushes to main. Start from the starter workflow at https://www.netninjas.eu/events/starter-github-actions-workflow and fit it to the stack. Keep these properties:
  - `permissions: contents: read` at the top, and more only on the job that needs it.
  - `concurrency` that cancels older runs of the same pull request.
  - One job named `checks`, so branch protection has a stable name to require.
  - No `continue-on-error`, and no `|| true`.
  - A dependency review job on pull requests, and CodeQL, when the repository is public or the account has GitHub Code Security (stack matrix, "What each GitHub plan allows").
- **`.github/dependabot.yml`**: weekly updates for the package ecosystem and for `github-actions`, with minor and patch updates grouped.
- **`.github/CODEOWNERS`**: the user's GitHub handle on `/.github/workflows/`, on infrastructure code, and on auth and payment code.
- **`README.md`**: how to run, test, and deploy, the chosen region, and how to roll back with the provider's own command.

**Pin every action.** Resolve the commit behind the newest release tag at scaffold time, and write it with the tag as a comment:

```sh
git ls-remote https://github.com/<owner>/<action> 'refs/tags/<tag>^{}' 'refs/tags/<tag>'
```

```yaml
- uses: <owner>/<action>@<40-character-sha> # <tag>
```

Do not copy a SHA or a version number from memory or from this file.

## 3. The repository

Ask whether it is public or private, and say what the answer changes (stack matrix, "What each GitHub plan allows"). Then one card, then:

```sh
gh repo create <owner>/<name> --private --source . --remote origin
```

Push the first commit to `main` only after the card for the repository is confirmed. Everything after it goes through pull requests.

## 4. Branch protection

One card for the ruleset. It requires a pull request and the `checks` job, and blocks deletion and force pushes. For a solo founder the approval count is 0: the pull request is where the pipeline gets to say no.

```sh
gh api -X POST repos/<owner>/<name>/rulesets --input ruleset.json
```

```json
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [{ "context": "checks" }]
      }
    }
  ]
}
```

Write `ruleset.json` to a temporary folder outside the project, and delete it afterwards. Check the fields against GitHub's current REST reference for rulesets before sending. With a second person on the team, set the approval count to 1 and `require_code_owner_review` to true.

Fallback: rulesets are not available on a private repository under GitHub Free. Say so, name the two ways out (a public repository, or GitHub Pro), and record "Branch protection: not available on this plan" in the closing summary.

## 5. Secret scanning and dependency updates

One card each.

```sh
# secret scanning with push protection
gh api -X PATCH repos/<owner>/<name> --input security.json
# security.json: {"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}

# Dependabot alerts
gh api -X PUT repos/<owner>/<name>/vulnerability-alerts
```

Fallback: on a private repository without GitHub Secret Protection, push protection cannot be turned on. Say so and record it in the closing summary.

## 6. Deploys by provider

The goal is the same everywhere: every pull request gets a preview, only the pipeline deploys production, and the repository holds no long-lived cloud key. The first choice is the provider's own Git integration, because it keeps every credential out of GitHub. Facts marked "verify" need a look at the provider's current documentation first.

### Vercel (W1, W2)

- Local: `vercel.json` with `"regions": ["fra1"]`.
- Card: the Vercel project, linked to the GitHub repository (`vercel link`, then `vercel git connect`).
- Result: a preview deployment for every pull request and a production deployment from `main`. No Vercel token sits in GitHub.
- Environment variables are added by the user in Vercel's interface or with `vercel env add`, which prompts them. Never pass a value on the command line.

### Cloudflare (W3, W4)

- Local: `wrangler.jsonc` with the Worker's name, the bindings, and for R2 the bucket's jurisdiction.
- Cards, one each: the D1 database (`wrangler d1 create <name> --jurisdiction eu`), the R2 bucket (`wrangler r2 bucket create <name> --jurisdiction eu`), and the Worker's connection to the repository through Workers Builds.
- Result: Workers Builds deploys `main` and gives each other branch a preview URL, posted on the pull request. Cloudflare creates its own token for the builds, so none sits in GitHub.
- The D1 and R2 jurisdiction cannot be changed later. Put that on the card.
- Secrets: the user runs `wrangler secret put <NAME>`, which prompts them.

### Neon (W1, W4)

- Card: the project (`neonctl projects create --name <name> --region-id aws-eu-central-1`). The region cannot be changed later.
- A database branch per pull request needs Neon's integration with the hosting provider or a Neon API key in GitHub (verify which the chosen hosting offers). An API key is a stored token: see section 8.

### Supabase (W2, M1)

- Card: the project, in one specific EU region (`supabase projects create <name> --region eu-central-1`). The CLI prompts the user for the database password. Do not pass it or read it.
- Local: migrations under `supabase/migrations/`. The first migration turns on row level security for every table and adds per-user policies. No table ships without it.
- Applying migrations from the pipeline: Supabase's GitHub integration (verify plan and availability), or a `supabase db push` job in the `production` environment with a stored access token (section 8).
- Only the publishable key goes in client code. The secret key stays in the host's secret store.

### Firebase (W5, M2)

- Cards, one each: the Firebase project, the Firestore database with location `eur3` (cannot be changed later), and the App Hosting backend in `europe-west4`, connected to the GitHub repository.
- Local: `firestore.rules` and `storage.rules` that deny by default and allow each user their own data. No "test mode" rules.
- Result: App Hosting builds and rolls out the live branch from GitHub with no key stored in GitHub. Previews for pull requests: verify what App Hosting offers on the check date. If it offers none, say so in the closing summary.
- Say that Firebase Authentication has no documented data location setting (stack matrix).

### AWS (W6, W7)

- Card: the Amplify Hosting app in `eu-central-1`, connected to the GitHub repository, with pull request previews on.
- Any job in GitHub Actions that touches AWS uses OIDC: GitHub's identity provider in the account, and a role whose trust policy accepts only `repo:<owner>/<name>:environment:production`. Creating the identity provider and the role are two more cards. No access key is created.
- A database billed by the hour goes on its card as "billed by the hour".

### Expo (M1, M2, M3)

- Local: `eas.json`, and either `.eas/workflows/` or a GitHub Actions job that calls EAS.
- Card: the EAS project (`eas init`).
- Checks (lint, types, tests) run in GitHub Actions on every pull request. Builds run on EAS. A preview for a pull request is an EAS Update on a branch channel.
- Calling EAS from GitHub Actions needs an `EXPO_TOKEN`, which is a stored token (section 8). Connecting the repository to the Expo GitHub app avoids it.
- Store submission stays a manual step that the user approves.

### Tauri and Electron (D1, D2)

- Local: a release workflow that builds on macOS, Windows, and Linux runners and uploads to a draft GitHub Release. For Tauri, use `tauri-apps/tauri-action`, pinned.
- The workflow's own `GITHUB_TOKEN` is short-lived. No cloud key is involved.
- Code-signing certificates and the updater's signing key are the user's. They add them as secrets in GitHub's interface. Until they do, the builds are unsigned, and the closing summary says so.

## 7. The production environment

One card: a GitHub environment named `production`, limited to the `main` branch.

```sh
gh api -X PUT repos/<owner>/<name>/environments/production --input environment.json
# environment.json: {"deployment_branch_policy":{"protected_branches":true,"custom_branch_policies":false}}
```

Required reviewers add a human approval to each deploy. They are available on public repositories on every plan, and on private repositories only with GitHub Enterprise. Where they are not available, the approval is the pull request into protected `main`. Say which of the two the project has.

When the provider's Git integration deploys production, GitHub's environment does not gate it. The gate is then the protected `main` branch plus the provider's own promotion or approval setting, if the plan has one (verify). Say so.

## 8. Stored tokens

OIDC or a provider Git integration comes first. When neither exists for a step, a long-lived token is the only way, and the rules are:

- The user creates the token in the provider's interface, with the narrowest scope the provider offers.
- The user stores it as a secret on the `production` environment, not as a repository secret, with `gh secret set <NAME> --env production`, which prompts them, or in GitHub's interface.
- The skill never sees it, and the workflow reads it only in the job that needs it.
- The closing summary lists it under "Stored tokens" with the reason and a date to rotate it.

## 9. What stays for the user

Name these in the closing summary. They complete the ten checks, and this skill does not create them.

- An uptime check on the production URL and error tracking in the app (check 10).
- A second person as code owner and reviewer, when there is one.
- The provider's spending alert or budget cap.
- A restore test for the database.
