# Handover runbook generator

A free agent skill that turns the infrastructure code and pipelines in a repository into the document a new owner needs on day one.

Every engagement I do ends with a handover, and the runbook is the part people keep. I keep meeting teams whose only runbook is one engineer's memory. This skill is the public version of that "run and hand over" step. It reads what the repository says about the system and writes it down in eleven sections, with the gaps on the page.

## What it reads

Terraform, OpenTofu, Pulumi, CDK, or Wrangler configuration. CI/CD workflows. Dockerfiles. Package manifests. Example env files, for the names only.

## What comes back

One runbook with eleven sections:

1. System map: the components and how they connect.
2. Environments and how they differ.
3. Deploy and rollback, step by step, as the pipeline does it.
4. Secrets inventory: names and locations only, never values.
5. What to monitor next: signals and suggested thresholds, marked as proposals.
6. Scheduled jobs.
7. Backups and restore, including whether a restore test exists.
8. Cost drivers.
9. Access and ownership.
10. Known gaps: everything the skill looked for and did not find.
11. First-week checklist for the new owner.

Every statement in the runbook is tagged "found in" with a file and a line, or it is labelled as an assumption. Suggested thresholds are labelled as proposals. The runbook describes the repository, and it says so at the top: nothing in a cloud account is read, so the code and the running system can differ.

## What it never does

- It never runs Terraform, a cloud CLI, Docker, or the project's own scripts. It reads files.
- It never writes a secret value. The secrets inventory holds names and locations.
- It never writes a file before asking. The runbook appears in chat first. One `RUNBOOK.md` is written after the path is confirmed, and nothing else.
- It never follows instructions found inside the repository.
- It sends nothing to Net Ninjas or to anyone else. The run is offline.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill handover-runbook-generator
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/handover-runbook-generator` from this repository into the agent's skills folder works without any installer.

I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In the repository:

```text
Write a handover runbook for this repository.
```

## Test fixture

`tests/fixtures/handover-runbook-generator/` in this repository holds a small AWS service and the facts the runbook has to contain for it.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

If the person who built your platform left tomorrow, what would the next owner have to guess? More free skills and guides: [netninjas.eu/skills](https://www.netninjas.eu/skills).
