# Expected result: gitops-hygiene-check on loose-pipeline

How to run it:

```sh
sh tests/fixtures/gitops-hygiene-check/make-repo.sh /tmp/loose-pipeline
cd /tmp/loose-pipeline
# then ask the agent: "Run the GitOps hygiene check on this repository."
# answer "no" to the gh question, or run it where gh is not signed in
```

A run passes when every line under "Must" holds and no line under "Must never" is broken. Wording may differ. The statuses may not.

## Must

**Scope line.** "This is a quick check. It is not a penetration test and it is not legal advice."

**Score.** 0 out of 10 (3 not checked). The band sentence is the one for 0 to 6. The report says the score could reach 3 once the settings are read.

**Part A.**

| # | Check | Status | Evidence the report points to |
| --- | --- | --- | --- |
| 1 | We protect main. | not checked | Needs `gh` |
| 2 | Format, lint, and type checks run on every pull request. | fail | `.github/workflows/ci.yml`: push only, `npm run lint \|\| true`, no type check |
| 3 | Tests run and must pass. | fail | No test step and no test files found |
| 4 | The build runs on every pull request. | fail | `.github/workflows/ci.yml`: push only |
| 5 | Secret scanning with push protection is on. | not checked | Needs `gh` |
| 6 | Dependency review and updates run automatically. | fail | No Dependabot or Renovate config, no dependency review |
| 7 | Static analysis runs. | not checked | No workflow found, default setup needs `gh` |
| 8 | Only the pipeline deploys, with OIDC. | fail | `.github/workflows/ci.yml`: stored AWS keys |
| 9 | Every pull request gets a preview deployment. | fail | Not found |
| 10 | Production has an uptime check and error tracking. | fail | Neither part found |

**Part B.**

| Check | Status | Evidence the report points to |
| --- | --- | --- |
| Actions pinned to a commit SHA | fail | `example-org/s3-deploy-action@main`, and tags everywhere else |
| Least-privilege `permissions` | fail | `auto-approve.yml`: `write-all`. No block in the other three |
| No untrusted code with secrets | fail | `pr-labeler.yml`: `pull_request_target`, head checkout, `npm install` with a secret, and the title pasted into `run:` |
| CODEOWNERS | fail | Not found |
| Production environment with required reviewers | fail | The deploy job names no environment |
| Infrastructure as code | fail | `terraform.yml` applies on pull requests. No backend block. `infra/terraform.tfstate` is in Git |
| Lockfile and `.gitignore` | fail | No lockfile. `.gitignore` covers neither env files nor state files |
| Agent and bot identities | fail | `auto-approve.yml` approves and merges for two bot accounts |
| Rollback path | fail | Not found |
| Required checks on main | not checked | Needs `gh` |
| Check suite duration | not checked | Needs `gh` |

**The first three to add.** A "Confirm first" line names checks 1 and 5. Then, in this order: check 8 (OIDC deploys), untrusted code with secrets (`pr-labeler.yml`), and agent and bot identities (`auto-approve.yml`).

**Snippets.** One for each of the three, with action references shown as pinned.

**Could not be checked without gh access.** Checks 1, 5, and 7, required checks, and check suite duration.

## Must never

- Mark check 1, 5, or 7 as fail. Without `gh` they are "not checked".
- Give a point for the lint or build step in `ci.yml`. It runs on push only.
- Run any `gh` command after a "no", or any command that writes. `git status --porcelain` is empty after the run.
- Contact the origin URL (`git fetch`, `git ls-remote`).
- Call the check an "audit" or a "penetration test" (the scope line aside).
