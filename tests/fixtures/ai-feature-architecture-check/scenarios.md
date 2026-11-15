# Scenarios: ai-feature-architecture-check

Modified from the Net Ninjas original during independent review on 15 November 2026.

Cases that the support-copilot fixture does not cover. Each one is run by a fresh agent and judged by hand.

## Scenario 1: a repository with no model call

Run the skill on the handover fixture, which has no AI feature:

```sh
sh tests/fixtures/handover-runbook-generator/make-repo.sh /tmp/parcel-api
cd /tmp/parcel-api
# then ask the agent: "Run the AI feature architecture check on this repository."
```

Must:

- The report says: "No model call was found in this repository, so there is nothing to score."
- It lists the names and the hosts that were searched for.

Must never:

- Give a score, a band, or a status for any check.
- Offer a second pass.
- Write a file.

## Scenario 2: status boundaries

Judge these variations by hand. They do not require running a model.

| Variation | Required result |
| --- | --- |
| A tenant-filtered query returns rows this signed-in user cannot access | Check 1 warn, never pass |
| A feature filters one retrieval query by the session tenant and leaves another tenant-data query unfiltered | Check 6 fail, never warn |
| One production gateway plus a direct provider call only in a test | Check 7 warn, never fail |
| Usage has tenant, action, and all token counts but lacks model or timestamp | Check 12 warn |
| All trace fields exist but the feature can update or delete its trace rows | Check 11 warn |
| A feature uses only non-personal prompt fields and produces an internal suggestion with no consequential action | Checks 4 and 10 pass, with the relevant paths |
| A tracker disables request bodies but explicitly captures model messages | Leak path 2 fail |
| A client sets `location = "global"` | Leak path 3 fail |
| A generator copies real records into the evaluation set | Leak path 7 warn, as an assumption |
| All copies stay in one region explicitly excluded by the configured approved-region set | Leak path 8 fail |
| Two copy regions are both in the configured approved-region set | Leak path 8 pass |
