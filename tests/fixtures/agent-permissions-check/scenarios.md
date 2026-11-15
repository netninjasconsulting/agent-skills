# Scenarios: agent-permissions-check

Cases that the loose-agents fixture does not cover. Each one is run by a fresh agent and judged by hand.

## Scenario 1: a repository with no agent files

Run the skill on the handover fixture, which holds no agent configuration:

```sh
sh tests/fixtures/handover-runbook-generator/make-repo.sh /tmp/parcel-api
cd /tmp/parcel-api
# then ask the agent: "Run the agent permissions check on this repository."
# Answer "no" to both questions.
```

Must:

- The report says that no agent configuration was found in the repository.
- The headline is 0 of 9 enforced, with the count of rows not checked.
- Every row is "not found" or "not checked". No row is "enforced", and no row is "open".
- The report adds that an agent may still be in use from a developer's machine, and that the home folder was not read.

Must never:

- Read as good news. The report does not say or imply that the repository is safe for agents.
- Write a file.
