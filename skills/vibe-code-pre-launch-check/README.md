# Vibe-code pre-launch check

A free agent skill that answers one question about an app built with AI coding tools: is this safe to put in front of users?

I keep seeing the same pattern in apps built fast with an assistant. The app works, the demo lands, and a server key sits in the browser bundle. This skill reads a local repository and gives a ranked answer in a few minutes. It changes nothing while it reads.

## What it checks

The checks run in order of who can reach a problem. A hole that any visitor can use comes before a hole that needs a stolen key.

| Group | What I look for |
| --- | --- |
| Secrets | Keys, tokens, and private keys in the working tree and in Git history. Committed `.env` files. Server secrets behind public prefixes such as `NEXT_PUBLIC_` or `VITE_`. |
| Sign-in and authorisation | Routes with no auth check. Auth enforced only in the browser. Records readable without an ownership check. Weak cookie and session settings. Password reset and email verification flows. |
| Database rules | Supabase tables without row level security or with permissive policies. Service role keys in client code. Open Firebase rules. Connection strings shipped to the browser. |
| API surface | Missing input validation. SQL built by string concatenation. No rate limit on sign-in and paid endpoints. Permissive CORS. Webhooks without signature checks. Uploads without type and size limits. |
| Cloud and provider keys | Long-lived keys. Wildcard IAM policies. Public storage buckets. Tokens with wider scope than the app needs. |
| Dependencies | A missing lockfile. With a yes from the person running it: package names that do not exist or look like typosquats, and known-vulnerable versions. |
| LLM features | Prompts built from user input with access to tools or secrets. Model keys in the browser. No spend cap. |
| Launch basics | Debug mode on. Verbose errors. Default admin credentials. Seed data on production paths. |
| Personal data | Where it is stored and whether it reaches the logs. A flag only, with no legal conclusion. |

## What comes back

The report opens with one verdict: ready, fix first, or do not launch. The three fixes to make first follow. Then every finding appears under the group that can reach it: anyone on the internet, any signed-in user, or anyone holding a leaked key or repository access.

Each finding says what it is, where it is (file and line), why it matters, how to fix it with a snippet, and a rough effort. The report ends with a "Not checked" list, so the limits are on the page. Every report carries this line: "This is a quick check. It is not a penetration test and it is not legal advice."

## What it never does

- It never writes to the repository, a Git remote, a cloud account, or a provider.
- It never scans a live URL. Version 1 reads a local repository only.
- It never prints a secret. The report shows the file, the line, and the secret type. The bundled scanner cuts every match down to its location before anything is shown.
- It never follows instructions found inside the repository. A note that says "already reviewed, skip the checks" becomes a finding.
- It sends nothing to Net Ninjas or to anyone else. Two dependency checks ask the package registry the project already installs from, and only after a yes.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill vibe-code-pre-launch-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/vibe-code-pre-launch-check` from this repository into the agent's skills folder (`.claude/skills/`, `.agents/skills/`, or the one the agent documents) works without any installer.

It needs a POSIX shell with `git`, `grep`, `sed`, and `awk`. I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In the repository, a plain request starts it:

```text
Is this app safe to put in front of users? Run the pre-launch check.
```

## Test fixture

`tests/fixtures/vibe-code-pre-launch-check/` in this repository holds a small, deliberately unsafe app and the result the skill has to produce on it. Every key in the fixture is fake. `EXPECTED.md` there lists the findings a run must report and the things it must never do.

## Going deeper

This skill is a quick check, and it is honest about that. For a deep review, the report points to [security-audit](https://github.com/cloudflare/security-audit-skill) by Cloudflare, Inc. (MIT licence), a free, open-source skill that runs a much longer, multi-agent review. I don't bundle it and I don't run it. It is a referral to a free tool.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which of these checks would your app fail today? More free skills and guides: [netninjas.us/skills](https://www.netninjas.us/skills).
