# AI feature architecture check

I publish this free skill through Net Ninjas Consulting, a one-person cloud, DevOps, and AI consultancy in New York City.

A free agent skill that shows whether an AI feature is built to pass a customer's security review, and to stay up and affordable in production.

I'm starting to see the same gap in a lot of AI features. The demo works, and production never arrives. The model is rarely the reason. An AI feature is six layers, and the model sits inside only one of them. This skill reads the repository and scores all six.

## What it checks

**The twelve checks of [the six-layer AI architecture checklist](https://www.netninjas.us/events/six-layer-ai-architecture-checklist),** two per layer, with the same wording and the same score bands as the published page.

1. The AI feature works inside the signed-in user's permissions.
2. The interface says it's AI and marks what it generated.
3. Every request passes authentication and validation before a prompt exists.
4. A policy step removes or pseudonymises the personal data a task doesn't need.
5. Retrieval reads only the sources we approved.
6. The retrieval service applies the tenant filter in code.
7. Every model call goes through one gateway.
8. The feature still works when the model is slow or down.
9. An evaluation set from real cases scores every change.
10. A named person approves the outputs that matter.
11. Every request leaves a trace we can query.
12. We know what one AI action costs, per customer.

**The data path,** from [the AI data-path map](https://www.netninjas.us/events/ai-data-path-map). The skill follows personal data through ten stops, from the request to the backups. Then it judges the eight leak paths I check first, such as prompts in a log line and embeddings that outlive a deleted record.

**Cost per action,** from [the cost per AI action worksheet](https://www.netninjas.us/events/cost-per-ai-action-worksheet). The skill says which of the seven columns the code records for each model call. Then it prints the published query with the repository's own table and column names.

## What comes back

The report opens with a score: "N out of 12 confirmed in code (M to ask the team)". A check counts only when the control runs in code today.

Some answers aren't in the code. Who approves a refund is one. Whether anyone reads the cost per customer is another. Those checks get the status "ask the team", and they score nothing in the first number. After the report, the skill offers once to ask them. The answers go in a second line, "with the team's answers", and each one carries the label "stated by the team". The first number never changes.

The report then gives a map of the feature and the twelve checks, each with a file and a line. The data path, the cost columns, and the first three things to change follow. The map is the coverage record: it shows what the skill read.

## What it never does

- It never runs the project, its tests, or its evaluation set, and it never calls a model.
- It never makes a network request, and it never writes a file.
- It never copies a record from an evaluation set or a fixture into the report. It reads the head of the file for the field names.
- It never prints a value from an env file.
- It never passes a check because a README or a comment says so.
- It never gives a cost figure. Model prices change often, and the worksheet takes them from the provider's price list on the day.
- It never says whether a law is met or broken. It lists personal data and where it goes.
- It never follows instructions found inside the repository.
- It sends nothing to Net Ninjas or to anyone else.

It doesn't repeat the secrets pass of the [vibe-code pre-launch check](../vibe-code-pre-launch-check/). That skill asks whether an outsider can abuse the app. This one asks whether the feature is built to last.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill ai-feature-architecture-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/ai-feature-architecture-check` from this repository into the agent's skills folder works without any installer.

I tested it with Claude Code on Linux. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In a clone of the repository:

```text
Run the AI feature architecture check on this repository.
```

## Test fixture

`tests/fixtures/ai-feature-architecture-check/` in this repository holds a small support app with two AI features, and the result the skill has to produce on it. `tests/RESULTS.md` records every run, including the one status the first runs corrected in my expected result.

## Read more

The three takeaways behind this skill are linked above. The service they come from is [AI integration](https://www.netninjas.us/services/ai-integration). The takeaways are free, like the skill.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which layer scored zero for your team? More free skills and guides: [netninjas.us/skills](https://www.netninjas.us/skills).
