# Guided app starter

A free agent skill that takes someone from "I want to build an app" to a scaffolded app with CI/CD, on the provider stack that fits them best.

I'm starting to see a lot of first products stall on the same early choice. The founder picks a stack from a thread, and nobody on the team has run it before. This skill asks what you need and what you already know, and recommends one stack with the reasons. Then it builds the first version with the pipeline in place from the first commit.

## How it runs

1. **Platform.** Mobile, web, or desktop.
2. **Comfort check.** One rating from 0 to 3 for each of GitHub, Vercel, Cloudflare, AWS, Neon, Supabase, and Firebase: never used, tried it, shipped with it, run it in production.
3. **Needs.** Sign-in, data shape, real-time, file storage, payments, the region (the US or the EU), and monthly budget.
4. **Recommendation.** One stack with the reasons, and one line on what was ruled out and why. Comfort and fit both count. The skill asks "US or EU?", and the US is the default.
5. **Product questions.** Superpowers asks the clarifying questions and writes the plan.
6. **Build.** Ponytail keeps the build to the smallest complete version. UI UX Pro Max guides the interface.
7. **Security pass.** Cloudflare's security-audit skill runs before the first deploy.
8. **Repository and CI/CD.** Branch protection, checks on every pull request, preview deploys, a production environment with approval, OIDC with no long-lived keys, secret scanning, and dependency updates.
9. **Close the loop.** The other three skills in this kit run on the result: the pre-launch check, the GitOps hygiene check, and the runbook generator.

## What it writes, and what it asks first

This skill is not read-only, and I want that to be plain. It writes files in the project folder you name. It creates a remote repository or a provider project only after you confirm each one by name, on a card that shows the exact command, the account, the region, and what cannot be changed later. A general "yes, do everything" doesn't count.

## What it never does

- It never handles a password, a key, or a token. Sign-in goes through each provider's own CLI, and you run it.
- It never creates a remote resource without its own confirmation.
- It never installs or copies a third-party skill. It checks whether each one is installed, prints the install command when it is not, and asks whether to go on without it.
- It sends nothing to Net Ninjas or to anyone else. Requests go only to the providers you chose, through your own sign-ins.

## The stack matrix has a date

Provider offers change often. The matrix in `references/stack-matrix.md` says when it was checked (13 November 2026 for this release) and marks each fact as checked or as one to verify. The skill re-reads the provider's documentation before it relies on a fact marked "verify". I re-check the whole matrix at every release.

## Credits

This skill depends on four third-party skills. It names them, checks that they are installed, and credits each one that ran in the closing summary of every run. It bundles none of their files.

| Skill | Author | Source | Licence | Role here |
| --- | --- | --- | --- | --- |
| Superpowers (brainstorming, planning) | Jesse Vincent (obra) | https://github.com/obra/superpowers | MIT | Clarifying questions and plan |
| Ponytail | DietrichGebert | https://github.com/DietrichGebert/ponytail | MIT | Smallest complete change |
| UI UX Pro Max | Next Level Builder | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | MIT | Interface design guidance |
| security-audit | Cloudflare, Inc. | https://github.com/cloudflare/security-audit-skill | MIT | Security pass before first deploy |

Each one works without Net Ninjas, and this skill works without each one: a missing dependency turns its step into a smaller built-in fallback, and the summary says so.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later. The whole kit works as one, so I install all four:

```sh
npx skills add netninjasconsulting/agent-skills --skill guided-app-starter --skill vibe-code-pre-launch-check --skill gitops-hygiene-check --skill handover-runbook-generator
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skills are also plain folders, so copying them from `skills/` in this repository into the agent's skills folder works without any installer.

Remote steps need `git`, the GitHub CLI, and the chosen provider's CLI. This is version 0.1.0, and I want its limits on the page. The stack recommendation has written scenarios with worked scores. The build and the remote steps have not been run end to end on any stack yet. The changelog and `tests/RESULTS.md` say what was tested and what was not.

## Use

```text
I want to build an app. Help me pick a stack and set it up.
```

## Test scenarios

`tests/fixtures/guided-app-starter/scenarios.md` in this repository holds sets of answers and the stack each one has to produce, plus the behaviour the skill has to show when a dependency is missing or when someone says "just create everything".

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

What are you building, and which of those seven providers do you already know? More free skills and guides: [netninjas.eu/skills](https://www.netninjas.eu/skills).
