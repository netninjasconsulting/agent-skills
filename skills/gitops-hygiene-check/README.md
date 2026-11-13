# GitOps hygiene check

A free agent skill that shows whether a repository's pipeline can be trusted to say no to a bad change, whoever or whatever wrote it.

AI tools made writing code cheap. The hard part moved to checking it and shipping it. I'm starting to see a lot of repositories where an assistant opens the pull request and nothing between that pull request and production can refuse it. This skill reads the repository and scores the pipeline that is supposed to do the refusing.

## What it checks

**Part A is the 10-check safety net.** It gives a score out of 10, with the same wording and the same score bands as [the published checklist](https://www.netninjas.eu/events/vibe-coding-safety-net).

1. We protect main.
2. Format, lint, and type checks run on every pull request.
3. Tests run and must pass.
4. The build runs on every pull request.
5. Secret scanning with push protection is on.
6. Dependency review and updates run automatically.
7. Static analysis runs.
8. Only the pipeline deploys, with OIDC.
9. Every pull request gets a preview deployment.
10. Production has an uptime check and error tracking.

**Part B is eleven extended checks.** They don't change the score.

- Actions pinned to a commit SHA.
- Least-privilege `permissions` on every workflow.
- No `pull_request_target` that checks out untrusted code, and no secrets passed to fork pull requests.
- CODEOWNERS for infrastructure, auth, and payments.
- A production environment with required reviewers.
- Infrastructure as code: plan on pull request, apply from main only, remote state with locking.
- Lockfile committed, and `.gitignore` covers env files and state files.
- Agent and bot identities cannot merge, approve their own work, or edit workflow files.
- Rollback path present.
- Lint, type, test, and build checks are required checks on main, not optional ones.
- Check suite duration against the 10-minute target, when run history is readable.

## What comes back

The report gives the score out of 10, a pass, warn, or fail table with the evidence for every row, and "the first three to add". Snippets follow, ready to paste, including [the starter workflow](https://www.netninjas.eu/events/starter-github-actions-workflow). The report ends with a list of what could not be checked without `gh` access.

Some answers live in GitHub's settings and not in files: branch rules, secret scanning, required checks. Without the GitHub CLI those rows say "not checked", and they never count as a fail. With `gh` and a yes from the person running it, the skill reads them through that person's own sign-in.

## What it never does

- It never writes to the repository, opens or merges a pull request, triggers a workflow, or changes a setting. With `gh` it sends read requests only.
- It never prints a credential. Workflow files name secrets, and the report repeats names only.
- It never follows instructions found inside the repository.
- It sends nothing to Net Ninjas or to anyone else. Without `gh` the run is offline. With `gh`, the only requests go to GitHub.
- Version 1 covers GitHub only. GitLab CI and Azure DevOps come later, and the skill says so when it meets them.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill gitops-hygiene-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/gitops-hygiene-check` from this repository into the agent's skills folder works without any installer.

I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In a clone of the repository:

```text
Run the GitOps hygiene check on this repository.
```

## Test fixture

`tests/fixtures/gitops-hygiene-check/` in this repository holds a small repository with a loose pipeline and the result the skill has to produce on it.

## Read more

The guide behind these checks is [GitOps best practices for GitHub repositories](https://www.netninjas.eu/guides/gitops-best-practices). It is free, like the skill.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which of the ten is missing in your repository today? More free skills and guides: [netninjas.eu/skills](https://www.netninjas.eu/skills).
