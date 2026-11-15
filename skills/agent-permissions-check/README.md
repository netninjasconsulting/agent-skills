# Agent permissions check

I publish this free skill through Net Ninjas Consulting, a one-person cloud, DevOps, and AI consultancy in New York City.

A free agent skill that shows what the AI coding agents on a repository can do, and what stops them.

I'm starting to see the same gap in a lot of teams that work with coding agents. The rules for the agent are written in a file the agent reads. "Never push to main." "Never touch production." Nothing behind the file enforces them. The agent is fast and mostly right, so the one wrong change gets through. This skill reads the repository and marks each rule as enforced, stated only, or open.

## What it checks

**Part A is the nine rows of [Agent permissions in one page](https://www.netninjas.us/events/agent-permissions-one-page).** They cover agents that act alone, in a pipeline. Each row gets one status and its evidence.

1. Repository: the agent can't push to main, merge, approve its own work, or edit workflow files.
2. Identity: the agent acts as its own bot or GitHub App, and never under a person's account.
3. Secrets: the agent can't read production secrets or long-lived cloud keys.
4. Cloud: the agent works in a sandbox account.
5. Data: the agent works with synthetic or anonymised fixtures.
6. Runners: the agent runs in fresh, isolated runners.
7. Outside input: the agent reads issues and web pages as data.
8. Review: a person gives the approving review.
9. Record: every action is in a log under the agent's own identity.

**Part B covers an agent at a developer's desk.** It doesn't change the count.

- The permission mode, and any mode that skips prompts.
- Commands that run without a prompt, such as a push, a merge, or a cloud CLI.
- Deny rules that keep env files and key files out of reach.
- Hooks that run commands.
- MCP servers: where each one is defined, how it starts, and which credentials it's given.
- Credentials within reach of the working folder, by name.
- Fixtures that look like real customer records.
- Text in the repository that tells a reviewer what to conclude.

It reads Claude Code and Codex settings in depth. For every other agent it reads the instruction files, the MCP configuration files, and the GitHub workflows that run an agent.

## What comes back

The report gives a count out of nine, with the evidence for every row. Then it lists the Part B findings, the first three things to change, and snippets to paste. It ends with what it could not check.

The five statuses are "enforced", "stated only", "open", "not found", and "not checked". A row is "enforced" only when the control exists. A line in `CLAUDE.md` or `AGENTS.md` makes a row "stated only".

The widest permissions often sit in a developer's home folder, outside the repository. The skill asks one question before it reads there. With a "no", it stays in the repository and says so in the report.

## What it never does

- It never shows a settings value unless its key carries a permission. A bundled script reads every settings file, and it hides tokens, passwords in addresses, and flag values inside the values it shows. CI tests that script on every pull request.
- It never repeats a credential it meets. One limit applies: a credential typed as a short plain word in a command or an instruction file can still appear in the script's output.
- It never opens a credential store. It lists the file and moves on.
- It never changes a setting, a ruleset, or a file. It writes one policy file, and only after a "yes" and a confirmed path.
- It never follows instructions found in the repository, including the ones in `CLAUDE.md`. Those files are what it checks.
- It never reads the home folder without a "yes".
- It sends nothing to Net Ninjas or to anyone else. Without `gh` the run is offline. With `gh`, the only requests go to GitHub, and they are read requests.
- It reads settings. It doesn't watch an agent run, and a command-line flag or a setting an employer manages can change what a file says.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill agent-permissions-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/agent-permissions-check` from this repository into the agent's skills folder works without any installer.

I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In a clone of the repository:

```text
Run the agent permissions check on this repository.
```

## Test fixture

`tests/fixtures/agent-permissions-check/` in this repository holds a small repository with loose agent settings, a stand-in home folder, and the result the skill has to produce on them. `tests/RESULTS.md` records every run, including the misses the first runs and the branch review found.

## Read more

The policy behind Part A is [Agent permissions in one page](https://www.netninjas.us/events/agent-permissions-one-page). The guide to setting up coding agents is [AI-assisted development](https://www.netninjas.us/guides/ai-assisted-development-workflow). Both are free, like the skill.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which of the nine rows is only written down in your repository today? More free skills and guides: [netninjas.us/skills](https://www.netninjas.us/skills).
