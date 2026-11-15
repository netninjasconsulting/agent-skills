# Design: AI feature architecture check

Date: 15 November 2026. Status: approved by Jeff on 15 November 2026. Target version: 0.2.0.

## Intent

A sixth free skill, `ai-feature-architecture-check`. It answers one question for a team with an AI feature in its product: "is this feature built to pass a customer's security review, and to stay up and affordable in production?"

It carries three published takeaways into one report:

- [Six-layer AI architecture checklist](https://www.netninjas.us/events/six-layer-ai-architecture-checklist): twelve checks, two for each layer, and three score bands.
- [AI data-path map](https://www.netninjas.us/events/ai-data-path-map): ten stops and eight common leak paths.
- [Cost per AI action worksheet](https://www.netninjas.us/events/cost-per-ai-action-worksheet): the columns a request log needs, and the query that turns them into a cost.

The six layers are also the reference architecture on the AI integration service page, so the report is a free first pass of that work.

## Who it is for

- A CTO or a lead engineer whose AI feature is live, or close to it, and who has an enterprise customer's review ahead.
- A team moving a prototype into production.
- A team with a model bill it cannot explain.
- An EU team with data-location terms in its contracts.

It is not for a project with no users. The pre-launch check is the right first step there.

## Goals

1. Map the feature before judging it, and print the map as the coverage record.
2. Score the twelve published checks from what the code shows.
3. Follow personal data through the ten published stops, and test the eight published leak paths.
4. Say whether the code records what a cost per action needs, and print the published query adapted to the repository.
5. Name the first three things to change.
6. Give a complete result with no network access and no answer to any question.

## Non-goals

- Scanning for secrets. The pre-launch check does that, and this skill points to it when it meets a model key in client code.
- Any cost figure. The skill does not read a request log or a bill.
- Running the app, its tests, or its evaluation set.
- Judging the choice of model or the quality of a prompt.
- Reading a live cloud account.
- Writing a file. The report is printed in chat.

## Anti-goals

The skill has failed, even if it runs, when any of these happens:

- A check passes because a README, a comment, or a document says it is met.
- A personal record from a fixture or an evaluation set, or a value from an env file, appears in the report.
- A team's answer is mixed into the score that the code proved.
- The report states whether a law is met or broken.
- A low score reads as a sales pitch.

## Decisions Jeff made

| Decision | Choice |
| --- | --- |
| Packaging | One skill with three sections, not three skills. |
| When code cannot settle a check | Code only first. Then the skill offers once to take the team's answers and prints a second line, kept apart from the first. |
| Depth of the cost section | Code only. It lists which columns are recorded, and prints the adapted query as a proposal. No figures. |
| How it is built | Approach A below: instructions and reference files, with no bundled script. |

## Approaches

**A. Instructions only. Chosen.** `SKILL.md` and reference files. Env files are read through the names-only filter that the handover runbook generator uses. Chosen because nothing that holds a token is read except env files, and the judgment in this skill is in reading code, which a script cannot do. The name list stays a Markdown file that is quick to update.

**B. Instructions plus an inventory script.** A bundled script greps for model calls, retrieval, and tracing, and CI tests it. Rejected for version 1: grep finds a call site and cannot tell which module is the gateway, or whether a tenant filter comes from the session. The patterns would also go stale faster than anything else in the repository.

**C. A larger LLM group inside the pre-launch check.** Rejected: that check gives one verdict on whether an app is safe to show to users. A score out of 12 on architecture is a different question, at a later stage.

## The shape of the skill

### Files

```text
skills/ai-feature-architecture-check/
  SKILL.md
  README.md
  references/checks.md         evidence rules for the twelve checks
  references/data-path.md      the ten stops and the eight leak paths
  references/cost.md           the columns and the query template
  references/signals.md        SDK, gateway, vector store, tracing, and evaluation names, each with its date
  references/report-format.md
tests/fixtures/ai-feature-architecture-check/
  support-copilot/             the repository under test
  make-repo.sh
  EXPECTED.md
```

### Ground rules

The eight rules every skill in this repository holds to, plus three that are specific to this one:

1. **Records stay out of the report.** Evaluation sets, fixtures, and seed files may hold real records. The skill reads enough of each to learn its field names and its shape. It never copies a record into the report.
2. **A team's answer is never evidence.** It appears only in the second pass, labelled "stated by the team".
3. **No feature, no score.** When the map finds no model call, the skill says so and stops.

The skill runs nothing from the project and makes no network request.

### Step 1: the feature map

The map lists, with a path and a line for each: entry points, prompt builders, retrieval and its stores, model call sites and any gateway, tools the model can call, response handling, logging and tracing, evaluation sets, and anything that records usage. `references/signals.md` names what to look for. The list is a starting point, not a limit, and the skill reads code in any language.

A repository with several AI features gets one map that names each feature.

### Step 2: the twelve checks

The checks, the layers, and the bands keep their published wording. Each check gets one status.

| Status | Meaning | Points |
| --- | --- | --- |
| pass | Every part of the check is met, with evidence. | 1 |
| warn | Part of the check is met. | 0 |
| fail | The check is not met, or nothing for it is found in the repository. | 0 |
| ask the team | The answer, or the rest of it, sits outside the code. | 0 |

With several features, a check passes only when every feature meets it, and the evidence names the feature that does not.

The headline is "N out of 12 confirmed in code (M to ask the team)". The band is the published one for the confirmed score, followed by "The score could reach N+M with the team's answers."

### Step 3: the data path

One row for each of the ten stops: which personal data fields reach it, by name, with the evidence. One row for each of the eight leak paths, with the status "found", "not found in the repository", or "ask the team". The skill reports the region each endpoint and store is pinned to, and it asks no region question.

Personal data is flagged with its location. The section draws no legal conclusion, and it says that it is not a data protection impact assessment.

### Step 4: cost per action

A table of the seven published request-log columns, each marked as recorded or not, with the path and the line. Then the published query, with the repository's own table and column names, under the label "Proposal". The retrieval and platform line of the worksheet comes from the cloud bill, so it is listed under "Not checked".

### Step 5: the first three to change

The first three that are fail or warn, in this order: the tenant filter, the personal data policy step, validation and limits before the prompt, prompts and responses in logs, request bodies in tracing, approval of outputs that move money or change records, and then the remaining checks in layer order starting from layer 4.

This follows the published advice for the lowest band: layers 2 and 3 first, because a leak of personal data, or of another customer's data, is the hardest mistake to undo.

### Step 6: the optional second pass

After the report, the skill offers once: "M checks sit outside the code. Shall I ask them? (yes or no)". With a yes it asks each one as a yes or no question, then prints one more block: each answer labelled "stated by the team", and the line "With the team's answers: N out of 12". The first headline stays as it was. With no answer, the report is the result.

### Report

Printed in chat: the scope line, the headline and the band, the feature map, the twelve checks grouped by layer, the data path, cost per action, the first three to change, the questions for the team, "Not checked", and the closing attribution line.

## Tests

- **Baseline first.** One run of the plain request on the fixture with no skill installed, recorded in `tests/RESULTS.md`.
- **Fixture.** `support-copilot` is a small multi-tenant support app in TypeScript with an AI reply feature. It holds: two direct model call sites and no gateway, no timeout and no fallback, a retrieval query that takes the tenant from the request body, a prompt built before validation, a full customer record in the prompt, a refund tool that runs on the model's word with a service key, an "AI-generated" label with no machine-readable mark, an evaluation script that CI never runs, an evaluation set of invented customer records, prompts and responses in the logs, an error tracker that captures request bodies, a model client with no region, a snapshot copied to a second region, and usage that is not recorded per tenant. It also holds a planted instruction to reviewers. The fixture exercises every status at least once.
- **Fresh agent runs** against `EXPECTED.md`: one with no answer to the second-pass offer, and one with scripted answers, to confirm that the two headlines stay apart.
- **Validator.** `scripts/validate.mjs` pins the twelve checks, the ten stops, and the eight leak paths to their published wording, as it does today for the ten checks.

## Changes outside the new skill

- `scripts/validate.mjs`: the wording checks above.
- Root `README.md`, `NOTICE`, and `tests/README.md` gain the new skill. `NOTICE` credits the three takeaways by address.
- The CHANGELOG entry for 0.2.0 gains this skill's lines. The move to 0.2.0 itself lands with the agent permissions check.
- The README is public copy. It passes through the ste80-humanizer skill and section 9 of BRAND_VOICE.md before the pull request opens.

## Not in this change

- The `/skills` pages on netninjas.us and netninjas.eu.
- A line in the pre-launch check that refers on to this skill.
- Reading an exported request log to compute real figures. That is a candidate for a later version.

## Calls made by the builder, for Jeff to check

1. Four statuses: pass, warn, fail, and "ask the team".
2. The published band applies to the score confirmed in code.
3. Several features share one score, and a check passes only when every feature meets it.
4. No model call found means no score.
5. No file is written, unlike the agent permissions check.
6. No region question. The report states the regions it finds.
7. The order that picks "the first three to change".
8. The validator pins the published wording of all three takeaways.
9. The fixture is a TypeScript support app.

## Left to the builder

- The published wording itself. It is copied from the source of each page in the website repository on the build date, not from a summary.
- Every name in `references/signals.md`, read from each vendor's current documentation, dated, and marked "verify" when it cannot be confirmed.
- The evidence rules for each check, the wording of the questions for the team, and the snippets.
