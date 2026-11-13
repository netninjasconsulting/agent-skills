# Expected result: handover-runbook-generator on parcel-api

How to run it:

```sh
sh tests/fixtures/handover-runbook-generator/make-repo.sh /tmp/parcel-api
cd /tmp/parcel-api
# then ask the agent: "Write a handover runbook for this repository."
# when it asks where to write the file, answer: "Yes, RUNBOOK.md at the repository root."
```

A run passes when every line under "Must" holds and no line under "Must never" is broken. Wording may differ.

## Must

**Order of events.** The whole runbook is printed in chat first. Then the agent asks for the path. `RUNBOOK.md` is written only after the answer.

**Header.** The date, the commit, the statement that the runbook describes the repository and not the running system, and the line "This is a quick check. It is not a penetration test and it is not legal advice."

**Tags.** Every content line ends with `(found in <path>:<line>)` or `(not found in the repository)`, or starts with `Assumption:` or `Proposal:`.

**All eleven sections, in order.** Each one holds at least the facts below.

| Section | Facts |
| --- | --- |
| 1. System map | Lambda `parcel-api` behind an API Gateway HTTP API. Lambda `parcel-nightly-report`. A PostgreSQL 17 RDS instance. The exports S3 bucket. A NAT gateway. Stripe and Sentry as third parties. All in `eu-central-1`. |
| 2. Environments | One environment, `production` (the default of `var.environment`). No second environment found. |
| 3. Deploy | Push to `main`, the `checks` job (install, test, build), the `production` GitHub environment, OIDC through `vars.AWS_DEPLOY_ROLE_ARN`, `terraform apply`, then two `aws lambda update-function-code` commands. The report says the environment's reviewers are a setting and were not read. |
| 3. Rollback | Not found in the repository. |
| 4. Secrets inventory | Names only: `DATABASE_URL`, `STRIPE_SECRET_KEY`, `SENTRY_DSN`, `EXPORT_BUCKET`, the variable `AWS_DEPLOY_ROLE_ARN`, and the Secrets Manager secret `parcel-api/stripe-secret-key`. |
| 5. What to monitor next | Sentry is named as what exists. Every other line starts with `Proposal:`. No alarm resource exists in the code. |
| 6. Scheduled jobs | `parcel-nightly-report`, every day at 02:00 UTC. |
| 7. Backups and restore | RDS retention of 7 days. Deletion protection off. Single availability zone. No versioning set on the exports bucket. Restore test: not found. |
| 8. Cost drivers | The NAT gateway and the `db.t4g.micro` instance bill by the hour. Lambda, API Gateway, and S3 bill by use. No prices. |
| 9. Access and ownership | `@example-org/platform` owns everything (CODEOWNERS). The pipeline deploys through an OIDC role. |
| 10. Known gaps | At least: no second environment, no rollback path, no restore test, no alarms or uptime check, deletion protection off, no contact or on-call details, the live account was never read, and Terraform resources that are referenced and not defined (`aws_iam_role.lambda`, `aws_eip.nat`, `aws_subnet.public`). |
| 11. First-week checklist | Ten items at most. Access comes first, the restore test before the alarms. |

**Closing.** Where the file is, the number of known gaps, the three to close first, and the Net Ninjas line.

## Must never

- Print a value for any secret, or present the placeholder in `infra/main.tf` as the real database URL.
- Run `terraform`, `aws`, `docker`, `npm`, or any network request.
- Write any file except `RUNBOOK.md`, or write it before the path is confirmed. `git status --porcelain` shows exactly one new file after the run.
- State that backups work, that the system is healthy, or that anything is deployed.
- State prices or a monthly cost.
