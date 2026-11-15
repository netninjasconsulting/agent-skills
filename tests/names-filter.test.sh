#!/bin/sh
# names-filter.test.sh: run the names-only filter that two skills use on env files.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/names-filter.test.sh
#
# The handover runbook generator and the AI feature architecture check read env
# files through one awk command that prints variable names and no values. This
# test takes the command from each SKILL.md and runs it on a file with the
# shapes that defeat a weaker filter: comments, a value that spans lines, and a
# line with no equals sign. Every planted value holds the marker FIXTUREVALUE.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

cat > "$work/.env" <<'ENV'
# OLD_DB_PASSWORD=FIXTUREVALUE-comment
#SESSION=FIXTUREVALUE-comment-no-space
DATABASE_URL=postgres://app:FIXTUREVALUE-url@db.example.com/app
export API_TOKEN="FIXTUREVALUE-export"
  INDENTED_KEY = FIXTUREVALUE-indented
PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
FIXTUREVALUE=value-shaped-line
FIXTUREVALUE-line-two-of-a-key
FIXTUREVALUE-line-three-of-a-key
-----END PRIVATE KEY-----"
FIXTUREVALUE-bare-line
EMPTY=
ENV

for skill in handover-runbook-generator ai-feature-architecture-check; do
  file="$root/skills/$skill/SKILL.md"
  [ -f "$file" ] || continue
  # The command sits in backticks, starts with "sed" or "awk", and ends with "<file>".
  # shellcheck disable=SC2016  # the backticks are literal text in the Markdown file
  filter=$(grep -oE '`(sed|awk) [^`]*<file>`' "$file" | head -n 1 | sed -e 's/^`//' -e 's/ <file>`$//')
  [ -n "$filter" ] || { fail "$skill: no names filter found in SKILL.md"; continue; }
  out=$(eval "$filter \"\$work/.env\"") || { fail "$skill: the filter exited with an error"; continue; }
  if printf '%s\n' "$out" | grep -qF -e FIXTUREVALUE; then
    fail "$skill: the filter printed a planted value"
  fi
  if printf '%s\n' "$out" | grep -qE 'BEGIN|END|PRIVATE KEY-'; then
    fail "$skill: the filter printed a line of a multi-line value"
  fi
  for name in DATABASE_URL API_TOKEN PRIVATE_KEY EMPTY; do
    printf '%s\n' "$out" | grep -qxF -e "$name=" || fail "$skill: the name $name is missing"
  done
done

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "names-filter: all checks passed"
