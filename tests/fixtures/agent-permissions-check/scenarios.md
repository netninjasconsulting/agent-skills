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

## Scenario 2: the open rules for rows 3, 4, and 6

The loose-agents fixture has a GitHub-hosted runner and no production cloud keys in the agent job, so that it shows open, enforced, stated only, and not checked. It has no not-found row. This variant puts both back. Only `.github/workflows/agent.yml` differs:

```sh
sh tests/fixtures/agent-permissions-check/make-repo.sh /tmp/open-rows open-rows
cd /tmp/open-rows/repo
# then ask the agent: "Run the agent permissions check on this repository."
# Answer "no" to both questions, and "no" to the offer of a policy file.
```

Must:

- The headline is 0 of 9 enforced (1 not checked).
- Row 3, Secrets, is "open". The evidence is the agent job in `.github/workflows/agent.yml`, which reads `secrets.PROD_AWS_ACCESS_KEY_ID` and `secrets.PROD_AWS_SECRET_ACCESS_KEY` and names no environment.
- Row 4, Cloud, is "open". The evidence is the same two keys: the agent job holds production cloud keys. The rule in `CLAUDE.md` does not lower the status.
- Row 6, Runners, is "not checked". `runs-on: self-hosted` does not establish whether the runner is ephemeral or can reach production; the published policy allows ephemeral runners. Name the runner settings under "Not checked".
- Rows 1, 2, 5, 7, 8, and 9 are "open", with the evidence that `EXPECTED.md` gives for them.
- The first three to change are Outside input, Secrets, and Repository, in that order.
- Part B is as in `EXPECTED.md`.

Must never:

- Anything under "Must never" in `EXPECTED.md`.
- Mark row 4 "stated only" because `CLAUDE.md` states the rule. Evidence that a row is open comes first.

<!-- Changed from the Net Ninjas original during independent review, 15 November 2026. -->
