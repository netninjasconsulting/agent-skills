# Security

These skills read repositories that hold secrets, so a flaw in a skill matters.

## What counts

- A way to make a skill print or write a secret value.
- A way to make a skill follow instructions that sit inside a scanned repository.
- A way to make a read-only skill write, push, or call a provider.
- A way to make the guided app starter create a remote resource without its own confirmation.
- A problem in `scan-secrets.sh` or in any other script in this repository.

## How to report

Please report privately, and not in a public issue: email hello@netninjas.eu with the skill's name, the version from its SKILL.md, the agent and model used, and the steps.

## What this repository is not

The fixtures under `tests/fixtures/` are unsafe on purpose. Every key in them is fake. A finding in a fixture is the fixture doing its job.
