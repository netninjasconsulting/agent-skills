# Evidence rules

How to decide pass, warn, fail, or not checked for each check. `{owner}/{repo}` comes from `git remote get-url origin`. `<default>` is the default branch.

Every `gh` command below is a read. Run them only after the yes from SKILL.md step 1. A `403` or `404` from a settings endpoint means the signed-in user may not read that setting: the status is "not checked", with the command as evidence.

## Rules that apply to every check

- A workflow step counts only when it can fail the run. A step that ends in `|| true`, or that has `continue-on-error: true` on the step or the job, does not count.
- "On every pull request" means a workflow triggered by `pull_request` with no path or branch filter that leaves pull requests into `<default>` out. `push` alone does not count. `pull_request_target` does not count either (see Part B).
- A check that a GitHub setting can satisfy is "not checked" when the files show nothing and `gh` was not used. It is never a fail on file evidence alone.
- A reusable workflow (`uses: ./.github/workflows/x.yml` or `owner/repo/.github/workflows/x.yml@ref`) is read like the job that calls it when it sits in this repository. A remote one is noted as an assumption.

## Part A: the 10-check safety net

### 1. We protect main.

- **gh:** `gh api repos/{owner}/{repo}/rules/branches/<default>` lists the rules in force on the branch. Classic protection: `gh api repos/{owner}/{repo}/branches/<default>/protection`.
- **Pass:** a `pull_request` rule (or classic `required_pull_request_reviews`) on the default branch, and no bypass that covers everyone.
- **Warn:** rules exist, and they do not require a pull request, or administrators and a broad bypass list skip them.
- **Fail:** `gh` answers and no rule applies to the default branch.
- **Not checked:** no `gh`. Where to look: Settings, Rules, Rulesets.
- Rulesets work in public repositories on every plan. In private repositories they need GitHub Pro, Team, or Enterprise. Say so when the repository is private and the answer is "no rules".

### 2. Format, lint, and type checks run on every pull request.

- **Files:** a pull request workflow that runs a formatter check or a linter, and a type checker when the language has one. Look for `lint`, `eslint`, `biome`, `prettier --check`, `ruff`, `flake8`, `rubocop`, `golangci-lint`, `cargo clippy`, `cargo fmt --check`, `tsc`, `typecheck`, `mypy`, `pyright`. Follow `npm run <script>` into `package.json` to see what the script runs.
- **Pass:** lint and, for a typed language, type checks run on every pull request and can fail the run.
- **Warn:** one of the two is missing, or both run only on some paths.
- **Fail:** they run only on `push`, they cannot fail the run, or they are not found in the repository.

### 3. Tests run and must pass.

- **Files:** a test step on every pull request (`test`, `vitest`, `jest`, `pytest`, `go test`, `cargo test`, `rspec`, `phpunit`), and at least one test file in the repository.
- **Pass:** tests run on every pull request and can fail the run.
- **Warn:** the step runs and no test files are found in the repository, or tests cover only part of a monorepo.
- **Fail:** no test step on pull requests, or the step cannot fail the run.

### 4. The build runs on every pull request.

- **Pass:** a build step (`build`, `next build`, `vite build`, `tsc -b`, `docker build`, `go build`, `cargo build`) on every pull request that can fail the run. A preview deployment that builds every pull request also counts.
- **Fail:** the build runs only on `push`, or it is not found in the repository.

### 5. Secret scanning with push protection is on.

- **gh:** `gh api repos/{owner}/{repo} --jq .security_and_analysis`. Read `secret_scanning.status` and `secret_scanning_push_protection.status`.
- **Pass:** both are `enabled`.
- **Warn:** scanning is on and push protection is off. Also a warn: a scanner in the repository (`gitleaks`, `trufflehog`, a pre-commit hook) with the GitHub setting unread, because it finds a secret after the commit exists.
- **Fail:** `gh` answers and both are `disabled`.
- **Not checked:** no `gh`, or the field is missing from the answer (only administrators see it). Where to look: Settings, Advanced Security.
- Push protection is free on public repositories. On private repositories it needs GitHub Secret Protection.

### 6. Dependency review and updates run automatically.

Three parts: alerts, update pull requests, and a review of new dependencies on every pull request.

- **Files:** `.github/dependabot.yml` or a Renovate config (`renovate.json`, `renovate.json5`, `.renovaterc`, `.github/renovate.json`) for updates. `actions/dependency-review-action` in a pull request workflow for the review.
- **gh:** `gh api repos/{owner}/{repo}/vulnerability-alerts` answers `204` when alerts are on and `404` when they are off.
- **Pass:** update config and dependency review are both present. Alerts are on, or unread.
- **Warn:** one of the two file parts is present.
- **Fail:** neither file part is found in the repository.
- Dependency review is free on public repositories. On private repositories it needs GitHub Code Security.

### 7. Static analysis runs.

- **Files:** `github/codeql-action` (`init` and `analyze`), Semgrep, SonarQube, or another analyser in a workflow that runs on pull requests or on a schedule.
- **gh:** `gh api repos/{owner}/{repo}/code-scanning/default-setup --jq .state` answers `configured` for CodeQL default setup, which needs no workflow file.
- **Pass:** an analyser workflow, or default setup `configured`.
- **Fail:** `gh` answers `not-configured` and no workflow is found.
- **Not checked:** no workflow and no `gh`. Where to look: Settings, Advanced Security, Code scanning.

### 8. Only the pipeline deploys, with OIDC.

- **Files:** find the jobs that deploy. Then read how they sign in.
  - OIDC: `permissions: id-token: write` together with `aws-actions/configure-aws-credentials` and `role-to-assume`, `google-github-actions/auth` and `workload_identity_provider`, or `azure/login` with `client-id` and no `creds`.
  - Stored keys: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `credentials_json`, `GOOGLE_CREDENTIALS`, `AZURE_CREDENTIALS`, a kubeconfig secret.
  - Stored provider tokens: `VERCEL_TOKEN`, `CLOUDFLARE_API_TOKEN`, `NETLIFY_AUTH_TOKEN`, `FIREBASE_TOKEN`, `FLY_API_TOKEN`, `EXPO_TOKEN`.
  - Provider Git integration: no deploy job at all, and a provider config file (`vercel.json`, `wrangler.*`, `netlify.toml`, `amplify.yml`, `apphosting.yaml`). With `gh`: `gh api repos/{owner}/{repo}/deployments --jq '.[].creator.login'` shows the provider's app as the creator.
- **Pass:** every deploy job uses OIDC and no stored cloud key appears in any workflow. Also a pass: `gh` shows that the provider's Git integration creates the deployments and no deploy token appears in any workflow.
- **Warn:** the pipeline deploys with a stored provider token. Also a warn: a provider config file suggests a Git integration and `gh` was not used.
- **Fail:** a deploy job uses stored cloud keys, or no deploy path is found in the repository (somebody deploys by hand).
- A `deploy` script in `package.json` or a `Makefile` shows that a laptop can deploy. Mention it as a note. It does not change the status.

### 9. Every pull request gets a preview deployment.

- **Files:** a pull request workflow that deploys a preview (`wrangler versions upload`, `wrangler preview`, `vercel deploy` without `--prod`, a per-pull-request environment, a review app).
- **gh:** `gh api "repos/{owner}/{repo}/deployments?per_page=20" --jq '.[].environment'` shows environments such as `Preview`.
- **Pass:** a preview workflow on pull requests, or `gh` shows preview deployments.
- **Warn:** a provider config file suggests a Git integration that creates previews, and `gh` was not used.
- **Fail:** neither is found, and the deploy path is the repository's own workflow.

### 10. Production has an uptime check and error tracking.

Two parts.

- **Error tracking, files:** an error tracking SDK in the manifests or the code (`@sentry/*`, `sentry-sdk`, `bugsnag`, `rollbar`, `honeybadger`, `@datadog/browser-rum`, an OpenTelemetry exporter with a configured endpoint).
- **Uptime check, files:** a monitor defined in code (`aws_route53_health_check`, `cloudflare_healthcheck`, `checkly.config.*`, a Better Stack, UptimeRobot, or Datadog monitor resource, or a scheduled workflow that requests the production URL and fails on a bad answer).
- **Pass:** both parts are found.
- **Warn:** one part is found. Uptime checks often live in a dashboard, so say that the other part may exist outside the repository.
- **Fail:** neither part is found in the repository.

## Part B: extended checks

Report these in this order.

### 1. Actions pinned to a commit SHA

- Read every `uses:` line. A pinned reference ends in a 40-character commit SHA. Tags (`@v4`), branches (`@main`), and short SHAs are not pinned. Local actions (`./`) and `docker://` images with a digest are fine.
- **Pass:** every reference is pinned. **Warn:** only `actions/*` and `github/*` references use tags. **Fail:** any third-party action uses a tag or a branch. Give the count and the first three places.

### 2. Least-privilege `permissions` on every workflow

- **Pass:** every workflow sets `permissions` at the top level to read-only scopes or `{}`, and jobs raise only what they use.
- **Warn:** some workflows have no `permissions` block. With `gh`: `gh api repos/{owner}/{repo}/actions/permissions/workflow --jq .default_workflow_permissions` answers `read` or `write`, which is what those workflows get.
- **Fail:** `permissions: write-all`, or a write scope at the top level that only one job needs.

### 3. No untrusted code with secrets

- **Fail** when any of these is found:
  - A `pull_request_target` or `workflow_run` workflow that checks out the pull request's code (`ref: ${{ github.event.pull_request.head.sha }}`, `head.ref`, or `refs/pull/.../merge`) and then installs, builds, or runs it.
  - Secrets passed to a job that forks can trigger.
  - Text the author controls placed straight into a `run:` script: `${{ github.event.pull_request.title }}`, `.body`, `.head.ref`, `github.event.issue.title`, `github.event.comment.body`, `github.head_ref`. The fix is to pass it through `env:`.
- **Pass:** none found. A `pull_request_target` workflow that only labels or comments, and never checks out the head, is fine.

### 4. CODEOWNERS for infrastructure, auth, and payments

- **Pass:** a `CODEOWNERS` file whose patterns cover the infrastructure code, `.github/workflows/`, and the auth and payment code, each with a person or team that is not a bot.
- **Warn:** the file exists and leaves one of those areas out, or uses only `*`.
- **Fail:** not found in the repository.
- CODEOWNERS only blocks a merge when the branch rules require code owner review. Read that from check A1's `gh` answer when it is there.

### 5. A production environment with required reviewers

- **Files:** the deploy job names `environment: production` (or another production name).
- **gh:** `gh api repos/{owner}/{repo}/environments --jq '.environments[] | {name, protection_rules, deployment_branch_policy}'`.
- **Pass:** the environment exists, has `required_reviewers`, and limits deployments to the default branch.
- **Warn:** the environment exists without reviewers, or without a branch limit.
- **Fail:** the deploy job names no environment.
- **Not checked:** the job names an environment and `gh` was not used.
- On GitHub Free, Pro, and Team, required reviewers work only in public repositories. A private repository needs GitHub Enterprise for them. Say so instead of failing a private repository on a plan that cannot turn them on.

### 6. Infrastructure as code: plan on pull request, apply from main only, remote state with locking

Only when the repository has Terraform, OpenTofu, Pulumi, or CDK code. Otherwise write "No infrastructure code found in the repository."

- **Pass:** `plan` or `preview` runs on pull requests. `apply`, `up`, or `deploy` runs only from the default branch. State sits in a remote backend with locking (`backend "s3"` with `use_lockfile` or `dynamodb_table`, `gcs`, `azurerm`, `cloud`, `remote`, Pulumi Cloud).
- **Fail:** `apply` on a pull request trigger, `-auto-approve` outside the default branch, no backend block (local state), or a state file in Git (`git ls-files | grep -E '\.tfstate'`).
- **Warn:** anything in between.

### 7. Lockfile committed, and `.gitignore` covers env files and state files

- **Pass:** each manifest has its lockfile in Git, and `.gitignore` covers `.env*` (with an exception for the example file) and, when there is infrastructure code, `*.tfstate*` and `.terraform/`.
- **Fail:** a lockfile is missing or ignored, or `git ls-files` shows an env file or a state file.
- **Warn:** the files are clean today and `.gitignore` does not cover them.

### 8. Agent and bot identities cannot merge, approve their own work, or edit workflow files

- **Fail** when any of these is found:
  - A workflow that approves or merges pull requests with the workflow token or a bot token (`gh pr review --approve`, `gh pr merge`, an auto-approve action, `pull-requests: write` used to approve).
  - With `gh`: `gh api repos/{owner}/{repo}/actions/permissions/workflow --jq .can_approve_pull_request_reviews` answers `true`.
  - With `gh`: a bot, an app, or an agent's account in a ruleset's bypass list.
- **Pass:** none of those, and `.github/workflows/` has a human code owner (check B4).
- **Warn:** none of those found in files, `gh` not used, and workflow files have no code owner.
- Auto-merge of dependency updates after the required checks pass is fine when a ruleset still demands those checks. Approving on the bot's behalf is not.

### 9. Rollback path present

- **Pass:** a way to put the previous version back that does not need a new change: a `workflow_dispatch` deploy with a version or ref input, a rollback job or script, or a written runbook that names the provider's rollback command.
- **Warn:** the provider offers instant rollback (Vercel, Cloudflare Workers, Amplify, App Hosting) and nothing in the repository says how the team uses it.
- **Fail:** not found in the repository.

### 10. Lint, type, test, and build checks are required checks on main

- **gh:** the `required_status_checks` rule from check A1's answer. Compare its contexts with the job names from checks A2, A3, and A4.
- **Pass:** every one of those jobs is required. **Warn:** some are. **Fail:** `gh` answers and none are.
- **Not checked:** no `gh`. Where to look: the ruleset's "Require status checks to pass" list.

### 11. Check suite duration against the 10-minute target

- **gh:** `gh run list --branch <default> --workflow <ci file> --status success --limit 20 --json startedAt,updatedAt`. Take the median of `updatedAt` minus `startedAt`.
- **Pass:** the median is 10 minutes or less. **Warn:** above 10 minutes. State the median in minutes.
- **Not checked:** no `gh`, or fewer than five successful runs.
