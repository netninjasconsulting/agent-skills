#!/bin/sh
# scan-secrets.test.sh: run the secret scanner against the vibe-shop fixture.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/scan-secrets.test.sh
#
# Checks three things: the scanner finds what the fixture plants, it finds the
# key that only Git history still holds, and no output of any mode contains a
# planted value.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
scanner="$root/skills/vibe-code-pre-launch-check/scripts/scan-secrets.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sh "$root/tests/fixtures/vibe-code-pre-launch-check/make-repo.sh" "$work/repo" >/dev/null

failures=0
fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

scan=$(sh "$scanner" "$work/repo")
history=$(sh "$scanner" --history "$work/repo")
shown=$(sh "$scanner" --show "$work/repo/.env")

expect_line() {
  # $1 = output, $2 = a line that must be present, $3 = label
  printf '%s\n' "$1" | grep -qxF -e "$2" || fail "$3: missing line $2"
}

expect_line "$scan" ".env:0:committed-env-file:tracked" "scan"
expect_line "$scan" ".env:4:server-secret-behind-public-prefix:tracked" "scan"
expect_line "$scan" ".env:5:openai-api-key:tracked" "scan"
expect_line "$scan" ".env:6:database-url-with-password:tracked" "scan"
expect_line "$scan" ".env:7:stripe-secret-key:tracked" "scan"
expect_line "$scan" ".env:8:aws-access-key-id:tracked" "scan"
expect_line "$scan" "lib/supabase.ts:6:server-secret-behind-public-prefix:tracked" "scan"

# The key file is gone from the working tree and still in history.
printf '%s\n' "$scan" | grep -q 'deploy-key.pem' && fail "scan: the deleted key file is listed in the working tree"
printf '%s\n' "$history" | grep -q ':config/deploy-key.pem:private-key-block$' || fail "history: the deleted private key was not found"

# The masked view keeps names, flags, and line numbers.
printf '%s\n' "$shown" | grep -q 'STRIPE_SECRET_KEY=<redacted>' || fail "show: the Stripe key line is not masked"
printf '%s\n' "$shown" | grep -q 'DEBUG=true' || fail "show: the debug flag was masked"
printf '%s\n' "$shown" | grep -qE '^ +7	' || fail "show: line numbers are missing"

# No mode may print a planted value.
for value in FIXTURE fixture-password EXAMPLEKEY AKIAIOSFODNN7EXAMPLE not-a-real sk_live_ sk-proj-; do
  for output in "$scan" "$history" "$shown"; do
    if printf '%s\n' "$output" | grep -qF -e "$value"; then
      fail "a planted value leaked: $value"
    fi
  done
done

# The scanner writes nothing.
[ -z "$(git -C "$work/repo" status --porcelain)" ] || fail "the scanner changed the repository"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "scan-secrets: all checks passed"
