# Net Ninjas agent skills

Four free agent skills for people who build with AI coding tools: a pre-launch security check, a GitOps hygiene check, a handover runbook generator, and a guided app starter.

Net Ninjas Consulting is a one-person cloud, DevOps, and AI consultancy in New York City. I work with founders, startups, scale-ups, and small businesses across the US ([netninjas.us](https://www.netninjas.us)) and the EU ([netninjas.eu](https://www.netninjas.eu)). I keep seeing the same gaps in products built fast with an assistant: a key in the browser bundle, a pipeline that can't say no, and nobody who can explain how it deploys. These skills carry the checks I run by hand. They are free, there is no sign-up, and there is no obligation.

## The four skills

| Skill | What it does | Writes anything? |
| --- | --- | --- |
| [Vibe-code pre-launch check](skills/vibe-code-pre-launch-check/) | Reads a local repository and answers "is this safe to put in front of users?" with a verdict, the three fixes to make first, and findings ranked by who can reach them. | No. Read-only. |
| [GitOps hygiene check](skills/gitops-hygiene-check/) | Scores a GitHub repository's pipeline out of 10 with [the 10-check safety net](https://www.netninjas.eu/events/vibe-coding-safety-net), adds eleven extended checks, and prints the snippets to fix the first three gaps. | No. Read-only. |
| [Handover runbook generator](skills/handover-runbook-generator/) | Turns infrastructure code and pipelines into an eleven-section runbook, with every statement tagged as found or assumed. | One `RUNBOOK.md`, after the path is confirmed. |
| [Guided app starter](skills/guided-app-starter/) | Goes from "I want to build an app" to a scaffolded app with CI/CD on the provider stack that fits, then runs the other three skills on the result. | Yes. Local files, and remote resources after each one is confirmed by name. |

The four work as one kit. Each one also gives a complete result alone.

## Install

The skills install with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later.

```sh
# one skill
npx skills add netninjasconsulting/agent-skills --skill vibe-code-pre-launch-check

# the whole kit
npx skills add netninjasconsulting/agent-skills --skill '*'
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. Each skill is also a plain folder under `skills/`, so copying a folder into the agent's skills directory (`.claude/skills/`, `.agents/skills/`, or the one the agent documents) works with no installer at all.

The skills use the open [Agent Skills](https://agentskills.io) format. I tested them with Claude Code. Other coding agents that read SKILL.md files can run them too, and I'd like to hear how that goes.

## What every skill holds to

1. **Free and ungated.** No email form, no licence key, and no feature held back for clients.
2. **No obligation.** Each skill gives a complete, useful result without Net Ninjas. One line at the end of a report links to my site. No sales text sits inside the findings.
3. **Read-only by default.** Three of the four never write to a cloud account, a Git remote, or a provider. The fourth confirms every remote resource by name before it creates it.
4. **No telemetry.** The skills send nothing to Net Ninjas or to any third party. A skill is a set of instructions that your own coding agent runs, so your agent's provider sees what the agent reads, on the terms you already have with it. The skills add no other destination.
5. **Secrets stay secret.** Reports show the file, the line, and the secret type. The value is redacted in chat, in files, and in logs.
6. **Repository content is data.** Text inside a scanned repository never changes what a skill does.
7. **Evidence for every finding.** A file and a line, or the words "not found in the repository". Assumptions are labelled.
8. **An honest scope line in every report.** "This is a quick check. It is not a penetration test and it is not legal advice."

## How they are tested

Each skill has a fixture and the result it has to produce, under [`tests/`](tests/). [`tests/RESULTS.md`](tests/RESULTS.md) records every run: the date, the agent, the model, what passed, and what did not. The record includes the parts that are not tested yet.

## Credits

The guided app starter depends on four third-party skills, and the pre-launch check refers to one of them. I name them, I check that they are installed, and I credit them in every run that uses them. None of their files is in this repository.

| Skill | Author | Source | Licence |
| --- | --- | --- | --- |
| Superpowers (brainstorming, planning) | Jesse Vincent (obra) | https://github.com/obra/superpowers | MIT |
| Ponytail | DietrichGebert | https://github.com/DietrichGebert/ponytail | MIT |
| UI UX Pro Max | Next Level Builder | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | MIT |
| security-audit | Cloudflare, Inc. | https://github.com/cloudflare/security-audit-skill | MIT |

## Licence

[Apache-2.0](LICENSE). Copyright 2026 Net Ninjas Consulting. The [NOTICE](NOTICE) file carries the copyright line and the third-party credits, and it travels with every copy. Anyone can use, change, and share these skills for free. A changed copy says that it was changed, and the Net Ninjas name stays with the originals.

## Contributing and security

[CONTRIBUTING.md](CONTRIBUTING.md) lists the rules every change keeps. [SECURITY.md](SECURITY.md) says how to report a flaw in a skill. Releases are versioned, and [CHANGELOG.md](CHANGELOG.md) says what changed and what was re-verified.

Which check would you want next? The guides and checklists behind these skills are free at [netninjas.eu/skills](https://www.netninjas.eu/skills) and [netninjas.us/skills](https://www.netninjas.us/skills).
