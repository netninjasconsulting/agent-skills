# Tests

Each skill ships with a fixture and the result it has to produce. A skill is a set of instructions for an agent, so the real test is a fresh agent that follows the skill on the fixture, compared by hand with `EXPECTED.md`.

| Skill | Fixture | Expected result |
| --- | --- | --- |
| `vibe-code-pre-launch-check` | `fixtures/vibe-code-pre-launch-check/vibe-shop/`, a small unsafe shop app | `fixtures/vibe-code-pre-launch-check/EXPECTED.md` |
| `gitops-hygiene-check` | `fixtures/gitops-hygiene-check/loose-pipeline/`, a repository with a loose pipeline | `fixtures/gitops-hygiene-check/EXPECTED.md` |
| `handover-runbook-generator` | `fixtures/handover-runbook-generator/parcel-api/`, a small AWS service | `fixtures/handover-runbook-generator/EXPECTED.md` |
| `guided-app-starter` | Scenarios, because the skill writes and creates things | `fixtures/guided-app-starter/scenarios.md` |

The fixtures are unsafe on purpose. Every key in them is fake, and none of them is meant to run.

## Running a fixture

A fixture cannot hold its own `.git` folder inside this repository, so each one has a `make-repo.sh` that copies it to a new folder and commits it.

```sh
sh tests/fixtures/vibe-code-pre-launch-check/make-repo.sh /tmp/vibe-shop
```

Then, in a new agent session with only the skill under test installed:

1. Open the new folder.
2. Give the request from the top of the fixture's `EXPECTED.md`.
3. Compare the result with "Must" and "Must never", line by line.
4. Run `git status --porcelain` in the folder. A read-only skill leaves it empty.
5. Add a row to `RESULTS.md`, pass or fail.

Use a fresh session each time. An agent that has read `EXPECTED.md` is not a test.

## What runs without an agent

```sh
node scripts/validate.mjs       # format and repository rules for every skill
sh tests/scan-secrets.test.sh   # the secret scanner against the vibe-shop fixture
```

Both run in CI on every pull request.

## Before a release

1. Run every fixture on a machine that has never had the skills installed, with the install command from the README.
2. Re-check each third-party LICENSE file and author name.
3. Re-check every provider fact in `skills/guided-app-starter/references/stack-matrix.md`, and update its date.
4. Compare the ten checks and the score bands with the published checklist.
5. Record all of it in `CHANGELOG.md` and `RESULTS.md`.

## Alerts on the fixtures

GitHub's own scanners read the fixtures like any other files. A secret scanning or Dependabot alert that points into `tests/fixtures/` is expected: the values are fake and the old versions are there on purpose.
