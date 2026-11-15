# Scenarios: ai-feature-architecture-check

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
