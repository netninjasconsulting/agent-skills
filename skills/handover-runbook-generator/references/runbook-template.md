# Runbook template

The layout of the runbook, and for each section what belongs in it and where to look. Text in angle brackets is replaced. Guidance lines that start with "Look for" stay out of the runbook.

Every line of content ends with `(found in <path>:<line>)`, or starts with `Assumption:` or `Proposal:`. A line that reports an absence ends with `(not found in the repository)`: an absence has no file and no line.

````markdown
# Runbook: <system name>

Generated on <date> from commit `<short sha>` of `<repository>`.

This runbook describes what the repository says. It does not describe what is running: nothing in a cloud account or a provider was read. Lines that start with "Assumption:" are inferred, and lines that start with "Proposal:" are suggestions. This is a quick check. It is not a penetration test and it is not legal advice.

## 1. System map

<One line per component: what it is, what it runs on, and its name in the code.>

<One line per connection: which component calls or reads which, and over what.>

```mermaid
flowchart LR
  <only components and connections listed above>
```

## 2. Environments and how they differ

| Environment | How it is selected | What differs |
| --- | --- | --- |
| <name> | <workspace, tfvars file, stack, branch, or wrangler env> | <region, sizes, counts, domains, flags> |

## 3. Deploy and rollback

### Deploy

1. <Trigger: what starts the pipeline.>
2. <Each job and step in order, as the pipeline runs them, with approvals and the identity it deploys as.>

### Rollback

1. <Each step the pipeline or the docs give for going back.>

## 4. Secrets inventory

| Name | Used by | Set in | Evidence |
| --- | --- | --- | --- |
| <NAME> | <component or job> | <CI secret, environment secret, secret manager path, host setting> | <path:line> |

## 5. What to monitor next

- Proposal: <signal>, alert at <threshold>, because <the component it protects> (found in <path>:<line>).

## 6. Scheduled jobs

| Job | Schedule (UTC) | What it runs | Evidence |
| --- | --- | --- | --- |

## 7. Backups and restore

- <Each data store, what the code sets for backups, and the retention.>
- Restore test: <what the repository shows, or "Not found in the repository.">

## 8. Cost drivers

- <Each resource that bills by the hour or by size, with its size or class.>

## 9. Access and ownership

- <Who owns what, who can deploy, and which identities the pipeline uses.>

## 10. Known gaps

- <Everything that was looked for and not found, one line each.>

## 11. First-week checklist

- [ ] <One action per line, most urgent first.>
````

## What belongs in each section

### 1. System map

Look for compute (functions, containers, services, Workers), data stores (databases, buckets, queues, caches, KV), entry points (API gateways, load balancers, routes, domains), and third-party services named in manifests and env names (payments, email, error tracking, auth, LLM providers).

A connection needs evidence: an env var that passes one resource's address to another, an IAM policy, a binding, a security group rule, an SDK import next to a matching env name. A connection that is only likely is an `Assumption:` line and stays out of the diagram.

The Mermaid diagram uses only what the lists above name. Leave the diagram out when there are fewer than three components.

### 2. Environments and how they differ

Look for Terraform workspaces and `*.tfvars` files, `Pulumi.<stack>.yaml`, CDK stages, `[env.<name>]` in Wrangler config, GitHub `environment:` names, and branch-based deploys. One environment is a finding: write the row, and add "No second environment found" to section 10.

### 3. Deploy and rollback

Write the deploy as the pipeline does it, step by step: the trigger, the checks that gate it, the approval (a GitHub environment with reviewers shows only as a name in the file: say that the reviewers are a setting and were not read), the identity (OIDC role or stored secret name), and each deploy command.

For rollback, look for a rollback job, a `workflow_dispatch` input that takes a version or ref, a script, or a documented provider command. If none exists, write "Not found in the repository." and add it to sections 10 and 11. Do not describe a rollback nobody wrote down.

### 4. Secrets inventory

Names and locations only. Sources: `secrets.<NAME>` and `vars.<NAME>` in workflows, env files (names through the filter in the ground rules), secret manager resources in infrastructure code, `wrangler secret` names in docs, and `process.env.<NAME>` or the language's equivalent for names no file declares. A name the code reads and no file sets is a gap.

### 5. What to monitor next

Proposals only, one per component that exists in the code. Starting thresholds:

| Component | Signal | Proposed threshold |
| --- | --- | --- |
| HTTP service or API | Share of 5xx responses | Above 1% for 5 minutes |
| HTTP service or API | 95th percentile response time | Above 1 second for 10 minutes |
| Function | Errors and throttles | Error rate above 1% for 5 minutes, or any throttle |
| Relational database | CPU, free storage, connections | CPU above 80% for 10 minutes, free storage below 20%, connections above 80% of the limit |
| Queue | Age of the oldest message, dead-letter count | Older than 5 minutes, or any message in the dead-letter queue |
| Scheduled job | Missed or failed run | One missed run |
| Certificate or domain | Days to expiry | Fewer than 21 days |
| Whole account | Daily spend | Above 150% of the 7-day average |
| Public endpoint | Uptime check from outside | Two failed checks in a row |

Say what already exists first (an error tracking SDK, an alarm resource), with its evidence.

### 6. Scheduled jobs

Look for `schedule:` in workflows, EventBridge or CloudWatch rules, Cloud Scheduler jobs, `[triggers] crons` in Wrangler config, Kubernetes CronJobs, and cron libraries in the code. Convert each schedule to UTC and plain words.

### 7. Backups and restore

For each data store, write what the code sets: retention, point-in-time recovery, versioning, deletion protection, replication. Then answer the restore question from the repository alone: is there a restore script, a restore workflow, or a written restore test with a date? If not, "Restore test: Not found in the repository." goes here and into sections 10 and 11.

### 8. Cost drivers

List what bills by the hour or by provisioned size, with the class or size from the code: database instances, NAT gateways, load balancers, provisioned concurrency, always-on containers, clusters, dedicated IPs. Then what bills by use: functions, storage, data transfer, logs, third-party APIs. No prices: they change, and nothing here read a bill.

### 9. Access and ownership

Look for `CODEOWNERS`, the roles and policies the pipeline assumes, IAM users and access keys in the code, admin lists, and contacts in the README. People named only in commit history are not owners: leave them out.

### 10. Known gaps

Everything this skill looked for and did not find, plus anything risky it did find. Always consider: a second environment, a rollback path, a restore test, alarms, an uptime check, on-call or contact details, a lockfile, remote state with locking, deletion protection on data stores, secrets the code reads and no file sets, and the live state of the cloud account (never read).

### 11. First-week checklist

Ten items at most, most urgent first, each one traceable to a line above. Start with access (can the new owner deploy and reach the logs?), then the gaps that lose data (restore test), then the gaps that hide failures (alarms), then the rest.
