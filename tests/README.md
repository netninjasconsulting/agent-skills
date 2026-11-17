# Tests

Each skill ships with a fixture and the result it has to produce. A skill is a set of instructions for an agent, so the real test is a fresh agent that follows the skill on the fixture, compared by hand with `EXPECTED.md`.

| Skill | Fixture | Expected result |
| --- | --- | --- |
| `vibe-code-pre-launch-check` | `fixtures/vibe-code-pre-launch-check/vibe-shop/`, a small unsafe shop app | `fixtures/vibe-code-pre-launch-check/EXPECTED.md` |
| `gitops-hygiene-check` | `fixtures/gitops-hygiene-check/loose-pipeline/`, a repository with a loose pipeline | `fixtures/gitops-hygiene-check/EXPECTED.md` |
| `handover-runbook-generator` | `fixtures/handover-runbook-generator/parcel-api/`, a small AWS service | `fixtures/handover-runbook-generator/EXPECTED.md` |
| `guided-app-starter` | Scenarios, because the skill writes and creates things | `fixtures/guided-app-starter/scenarios.md` |
| `agent-permissions-check` | `fixtures/agent-permissions-check/loose-agents/`, a repository with loose agent settings, and `home/`, a stand-in home folder | `fixtures/agent-permissions-check/EXPECTED.md`, and `scenarios.md` for a repository with no agent files and for the `open-rows` variant of the fixture |
| `ai-feature-architecture-check` | `fixtures/ai-feature-architecture-check/support-copilot/`, a small support app with two AI features | `fixtures/ai-feature-architecture-check/EXPECTED.md`, and `scenarios.md` for a repository with no model call |
| `serverless-deploy-check` | `fixtures/serverless-deploy-check/quickship/`, a delivery tracking app on all four platforms | `fixtures/serverless-deploy-check/EXPECTED.md`, and `scenarios.md` for a repository with none of the four platforms (`plain-cli/`), Vercel and Supabase only, E1 as a warn, and a Lambda function defined in AWS CDK (`cdk/`) |
| `kubernetes-workload-check` | `fixtures/kubernetes-workload-check/fleetboard/`, a fleet-tracking product with plain manifests, Kustomize overlays, a Helm chart, and Argo CD objects, and `fake-kubectl/`, a stand-in `kubectl` for the cluster pass | `fixtures/kubernetes-workload-check/EXPECTED.md`, and `scenarios.md` for a repository with no workload, the fixture with `helm` and `kubectl` off the path, the fixture with the CPU request of `api` removed, the fixture with `argocd/` removed, and the fixture with symbolic links that stay inside the repository and one that points outside it |

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

The Kubernetes fixture needs more setup than this: `helm` and `kubectl` on the path, and a wrapper that sends every `kubectl` command except `kustomize` to the stand-in. `fixtures/kubernetes-workload-check/EXPECTED.md` gives the setup and the three ways to run it.

## What runs without an agent

```sh
node scripts/validate.mjs
node tests/validate.test.mjs       # format and repository rules for every skill
sh tests/scan-secrets.test.sh   # the secret scanner against the vibe-shop fixture
sh tests/list-agent-config.test.sh   # the agent configuration reader against the loose-agents fixture
sh tests/read-serverless-config.test.sh   # the serverless configuration reader against the quickship fixture and its attack files
sh tests/read-k8s-objects.test.sh   # the Kubernetes object reader against the fleetboard fixture and its attack files; its render cases need helm and kubectl
sh tests/read-cluster-usage.test.sh   # the cluster usage script against a stand-in kubectl, which never contacts a cluster
sh tests/names-filter.test.sh   # the names-only filter that two skills use on env files
```

All eight commands run in CI on every pull request. Before the Kubernetes tests, CI installs `kubectl` v1.37.2 and `helm` v4.3.2, each checked against a SHA-256 written in `.github/workflows/ci.yml`, so the reader's render cases and the cluster script's flag classification run there and are not skipped. The validator mutation suite includes the starter's default permissions, redacted quotation, and package approval rules. Scenarios 10 to 12 cover the corresponding agent behaviour and security check requirements; these scenarios have not been run yet.

## Before a release

1. Run every fixture on a machine that has never had the skills installed, with the install command from the README.
2. Re-check each third-party LICENSE file and author name.
3. Re-check every provider fact in `skills/guided-app-starter/references/stack-matrix.md`, `skills/serverless-deploy-check/references/platforms.md`, and `skills/kubernetes-workload-check/references/fields.md`, and update their dates.
4. Compare the ten checks and the score bands with the published checklist.
5. Record all of it in `CHANGELOG.md` and `RESULTS.md`.

## Alerts on the fixtures

GitHub's own scanners read the fixtures like any other files. A secret scanning or Dependabot alert that points into `tests/fixtures/` is expected: the values are fake and the old versions are there on purpose.
