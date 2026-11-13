# Snippets

Ready to paste. Adapt names, paths, and commands to the repository, and say which lines were adapted. Every action reference in a pasted workflow gets pinned (see "Pin an action to a commit SHA").

## Contents

1. [Starter workflow](#starter-workflow) (checks 2, 3, 4, 6, 7, and 8)
2. [Automated dependency updates](#automated-dependency-updates) (check 6)
3. [Protect main](#protect-main) (check 1)
4. [Secret scanning with push protection](#secret-scanning-with-push-protection) (check 5)
5. [OIDC deploy without stored keys](#oidc-deploy-without-stored-keys) (check 8)
6. [Pin an action to a commit SHA](#pin-an-action-to-a-commit-sha)
7. [Least-privilege permissions](#least-privilege-permissions)
8. [Untrusted input in workflows](#untrusted-input-in-workflows)
9. [CODEOWNERS](#codeowners)
10. [Keep bots from approving and merging](#keep-bots-from-approving-and-merging)
11. [Ignore env files and state files](#ignore-env-files-and-state-files)
12. [Terraform: plan on pull request, apply from main](#terraform-plan-on-pull-request-apply-from-main)

## Starter workflow

The workflow published at https://www.netninjas.eu/events/starter-github-actions-workflow, as it stood on 13 November 2026. It assumes a Node.js project. For another language, keep the shape and swap the four commands in the `checks` job. The published page is the current copy.

```yaml
# .github/workflows/ci.yml
# Starter pipeline from the talk "Ship fast, break nothing" (netninjas.eu/events).
# Assumes a Node.js project whose package.json has lint, typecheck, test, and build scripts.
name: ci

on:
  pull_request:
  push:
    branches: [main]

# Least privilege by default; jobs that need more ask for it.
permissions:
  contents: read

# A new push to a pull request cancels its older run. Runs on main always finish.
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  checks:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version: 24
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test
      - run: npm run build

  dependency-review:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/dependency-review-action@v5
        with:
          fail-on-severity: high

  codeql:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v7
      - uses: github/codeql-action/init@v4
        with:
          languages: javascript-typescript
      - uses: github/codeql-action/analyze@v4

  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: [checks, codeql]
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write # lets the job ask AWS for short-lived credentials (OIDC)
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
          aws-region: eu-central-1
      - run: ./scripts/deploy.sh
```

Two lines need local values: `./scripts/deploy.sh` becomes the real deploy step, and `eu-central-1` becomes the real region. On a private repository, CodeQL and dependency review need a GitHub Code Security licence, or Semgrep in their place. On a public repository, both are free.

Four settings sit outside the file:

1. A branch ruleset on main that requires a pull request and the `checks` and `codeql` jobs.
2. Secret scanning with push protection, in the repository's security settings.
3. The deploy role in AWS: GitHub's OIDC identity provider (`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`), and a role whose trust policy only accepts the subject `repo:<owner>/<repo>:environment:production`. Its ARN goes into the repository variable `AWS_DEPLOY_ROLE_ARN`.
4. An environment named `production`, limited to the main branch.

## Automated dependency updates

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
    groups:
      minor-and-patch:
        update-types: [minor, patch]
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

## Protect main

Settings, Rules, Rulesets, New branch ruleset. Target the default branch. Turn on:

- Restrict deletions, and block force pushes.
- Require a pull request before merging. One approval is enough to start. Add "Require review from Code Owners" once CODEOWNERS exists.
- Require status checks to pass, with the lint, type, test, and build jobs in the list.
- Leave the bypass list empty.

Rulesets work in public repositories on every plan. Private repositories need GitHub Pro, Team, or Enterprise.

## Secret scanning with push protection

Settings, Advanced Security. Turn on "Secret Protection" and then "Push protection". On a public repository both are free. On a private repository they need GitHub Secret Protection. Without that licence, a pre-commit scanner (`gitleaks protect --staged`) is a partial substitute: it runs on the laptop and can be skipped.

## OIDC deploy without stored keys

AWS shown. Google Cloud (`google-github-actions/auth` with `workload_identity_provider`) and Azure (`azure/login` with a federated credential) follow the same shape.

```yaml
deploy:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  needs: [checks]
  runs-on: ubuntu-latest
  environment: production
  permissions:
    contents: read
    id-token: write # lets the job ask the cloud for short-lived credentials
  steps:
    - uses: actions/checkout@<commit-sha> # <tag>
    - uses: aws-actions/configure-aws-credentials@<commit-sha> # <tag>
      with:
        role-to-assume: ${{ vars.AWS_DEPLOY_ROLE_ARN }}
        aws-region: <eu-region>
    - run: <deploy command>
```

The role's trust policy accepts one subject only:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:<owner>/<repo>:environment:production"
    }
  }
}
```

After the first green deploy, delete the old access key in the cloud account and remove `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the repository's secrets.

## Pin an action to a commit SHA

```sh
# prints the commit behind a release tag
git ls-remote https://github.com/<owner>/<action> 'refs/tags/<tag>^{}' 'refs/tags/<tag>'
```

```yaml
- uses: <owner>/<action>@<40-character-sha> # <tag>
```

The comment keeps the tag readable. Dependabot's `github-actions` ecosystem updates the SHA and the comment together.

## Least-privilege permissions

```yaml
# top of every workflow
permissions:
  contents: read

jobs:
  release:
    permissions:
      contents: write # only the job that needs it
```

## Untrusted input in workflows

```yaml
# unsafe: the title is pasted into the script
- run: echo "${{ github.event.pull_request.title }}"

# safe: the title arrives as data
- run: echo "$TITLE"
  env:
    TITLE: ${{ github.event.pull_request.title }}
```

A `pull_request_target` workflow never checks out or runs the pull request's code. Work that needs the code runs under `pull_request`, which gives forks no secrets.

## CODEOWNERS

```text
# .github/CODEOWNERS
/.github/workflows/  @<owner-or-team>
/infra/              @<owner-or-team>
/src/auth/           @<owner-or-team>
/src/payments/       @<owner-or-team>
```

## Keep bots from approving and merging

- Settings, Actions, General, Workflow permissions: "Read repository contents and packages permissions", and "Allow GitHub Actions to create and approve pull requests" off.
- No bot, app, or agent account in a ruleset's bypass list.
- A human code owner on `/.github/workflows/`, with code owner review required.
- Auto-merge for dependency updates stays behind the required checks. No workflow approves on a bot's behalf.

## Ignore env files and state files

```gitignore
.env*
!.env.example
*.tfstate
*.tfstate.*
.terraform/
```

A file that is already in Git stays there until it is removed: `git rm --cached <file>`. A secret that was committed is rotated first.

## Terraform: plan on pull request, apply from main

```yaml
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@<commit-sha> # <tag>
      - uses: hashicorp/setup-terraform@<commit-sha> # <tag>
      - run: terraform init -input=false
      - run: terraform plan -input=false

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@<commit-sha> # <tag>
      - uses: hashicorp/setup-terraform@<commit-sha> # <tag>
      - run: terraform init -input=false
      - run: terraform apply -input=false -auto-approve
```

```hcl
terraform {
  backend "s3" {
    bucket       = "<state-bucket>"
    key          = "<project>/terraform.tfstate"
    region       = "<eu-region>"
    use_lockfile = true
  }
}
```
