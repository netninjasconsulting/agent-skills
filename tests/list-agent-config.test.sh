#!/bin/sh
# list-agent-config.test.sh: run the agent configuration reader against the loose-agents fixture.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/list-agent-config.test.sh
#
# Checks four things: the reader lists the agent files the fixture plants and
# nothing else, it reads the home folder only when it is given one, the masked
# view keeps the permission settings readable, and no output of any mode
# contains a planted value. Every planted value holds the marker FIXTUREVALUE.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
reader="$root/skills/agent-permissions-check/scripts/list-agent-config.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sh "$root/tests/fixtures/agent-permissions-check/make-repo.sh" "$work/fx" >/dev/null
repo="$work/fx/repo"
home="$work/fx/home"

failures=0
fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

expect_line() {
  # $1 = output, $2 = a line that must be present, $3 = label
  printf '%s\n' "$1" | grep -qxF -e "$2" || fail "$3: missing line $2"
}

expect_text() {
  # $1 = output, $2 = text that must be present, $3 = label
  printf '%s\n' "$1" | grep -qF -e "$2" || fail "$3: missing $2"
}

no_marker() {
  # $1 = output, $2 = label
  if printf '%s\n' "$1" | grep -qF -e FIXTUREVALUE; then
    fail "$2: a planted value leaked"
  fi
}

[ -f "$reader" ] || { echo "FAIL: the reader does not exist: $reader"; exit 1; }

# 1. The list, repository only.
list=$(sh "$reader" "$repo")
expect_line "$list" ".claude/settings.json:claude-code:settings:tracked" "list"
expect_line "$list" ".claude/settings.local.json:claude-code:settings:ignored" "list"
expect_line "$list" ".mcp.json:claude-code:mcp:tracked" "list"
expect_line "$list" "CLAUDE.md:claude-code:instructions:tracked" "list"
expect_line "$list" ".codex/config.toml:codex:settings:tracked" "list"
expect_line "$list" "AGENTS.md:shared:instructions:tracked" "list"
expect_line "$list" ".github/workflows/agent.yml:shared:workflow:tracked" "list"
printf '%s\n' "$list" | grep -q 'workflows/ci.yml' && fail "list: a workflow with no agent is listed"
printf '%s\n' "$list" | grep -q '\.env' && fail "list: an env file is listed"
printf '%s\n' "$list" | grep -q ':home$' && fail "list: a home file is listed without --home"
no_marker "$list" "list"

# 2. The list, with the stand-in home folder.
both=$(sh "$reader" --home "$home" "$repo")
expect_line "$both" "$home/.claude/settings.json:claude-code:settings:home" "list --home"
expect_line "$both" "$home/.claude.json:claude-code:mcp:home" "list --home"
expect_line "$both" "$home/.claude/.credentials.json:claude-code:credential-store:home" "list --home"
expect_line "$both" "$home/.codex/config.toml:codex:settings:home" "list --home"
expect_line "$both" "$home/.codex/auth.json:codex:credential-store:home" "list --home"
expect_line "$both" ".claude/settings.json:claude-code:settings:tracked" "list --home"
no_marker "$both" "list --home"

# Every listed path is inside the repository or the stand-in home folder.
printf '%s\n' "$both" | while IFS= read -r line; do
  path=${line%%:*}
  case "$path" in
    "$home"/*) ;;
    /*) echo "OUTSIDE $path" ;;
    *) [ -e "$repo/$path" ] || echo "MISSING $path" ;;
  esac
done > "$work/outside"
[ -s "$work/outside" ] && fail "list: a path outside the two folders, or a path that does not exist: $(cat "$work/outside")"

# 3. The masked view never shows a planted value, for any listed file.
printf '%s\n' "$both" | while IFS= read -r line; do
  path=${line%%:*}
  case "$path" in
    /*) file=$path ;;
    *) file="$repo/$path" ;;
  esac
  sh "$reader" --show "$file" 2>&1 || true
done > "$work/all-shown"
grep -qF -e FIXTUREVALUE "$work/all-shown" && fail "show: a planted value leaked from a listed file"
env_shown=$(sh "$reader" --show "$repo/.env")
no_marker "$env_shown" "show .env"
expect_text "$env_shown" "DATABASE_URL=" "show .env"
expect_text "$env_shown" "prod-db.example.com" "show .env"

# 4. The masked view keeps what the check needs.
settings=$(sh "$reader" --show "$repo/.claude/settings.json")
expect_text "$settings" "Bash(git push *)" "show settings"
expect_text "$settings" "bypassPermissions" "show settings"
expect_text "$settings" "enableAllProjectMcpServers" "show settings"
expect_text "$settings" "DEPLOY_TOKEN" "show settings"
expect_text "$settings" "echo fixture hook" "show settings"
printf '%s\n' "$settings" | grep -qE '^ +[0-9]+	' || fail "show settings: line numbers are missing"

codex=$(sh "$reader" --show "$repo/.codex/config.toml")
expect_text "$codex" "danger-full-access" "show codex"
expect_text "$codex" "never" "show codex"
expect_text "$codex" "DEPLOY_KEY" "show codex"
expect_text "$codex" "[mcp_servers.deploy.env]" "show codex"

mcp=$(sh "$reader" --show "$repo/.mcp.json")
for name in postgres search tickets DATABASE_URL Authorization @example/mcp-search mcp.example.com; do
  expect_text "$mcp" "$name" "show mcp"
done
expect_text "$mcp" "--api-key=<redacted>" "show mcp"

home_json=$(sh "$reader" --show "$home/.claude.json")
expect_text "$home_json" "notes" "show home .claude.json"
expect_text "$home_json" "NOTES_TOKEN" "show home .claude.json"
printf '%s\n' "$home_json" | grep -q 'dev@example.com' && fail "show home .claude.json: account details are shown"

workflow=$(sh "$reader" --show "$repo/.github/workflows/agent.yml")
expect_text "$workflow" "secrets.ADMIN_PERSONAL_ACCESS_TOKEN" "show workflow"
expect_text "$workflow" "pull_request_target" "show workflow"

# 5. A credential store is never shown.
for store in "$home/.codex/auth.json" "$home/.claude/.credentials.json"; do
  code=0
  out=$(sh "$reader" --show "$store" 2>&1) || code=$?
  [ "$code" -eq 3 ] || fail "show: a credential store did not exit 3 ($store, exit $code)"
  no_marker "$out" "show credential store"
  printf '%s\n' "$out" | grep -q 'credential store, not shown' || fail "show: no refusal message for $store"
done

# 6. Tokens where the shown keys expect none (Review Focus 1).
mkdir -p "$work/edge"
cat > "$work/edge/.mcp.json" <<'JSON'
{
  "mcpServers": {
    "a": { "command": "npx", "args": ["-y", "tool", "--token", "FIXTUREVALUE-separate-flag"] },
    "b": { "type": "http", "url": "https://user:FIXTUREVALUE-userinfo@mcp.example.com/v1?access_token=FIXTUREVALUE-query" },
    "c": { "command": "sh", "args": ["-c", "API_TOKEN=FIXTUREVALUE-inline-assignment run-server"] },
    "d": { "command": "run", "headers": { "X-Key": "FIXTUREVALUE-header" }, "apiKey": "FIXTUREVALUE-unknown-key" },
    "e": { "command": "ghp_FIXTUREVALUE0000notarealtoken0000" }
  }
}
JSON
edge=$(sh "$reader" --show "$work/edge/.mcp.json")
no_marker "$edge" "show edge mcp"
expect_text "$edge" "mcp.example.com" "show edge mcp"
expect_text "$edge" "run-server" "show edge mcp"

# 7. A broken settings file still prints masked (Review Focus 5).
printf '{\r\n  "permissions": {\r\n    "defaultMode": "bypassPermissions"\r\n  },\r\n  "env": {\r\n    "TOKEN": "FIXTUREVALUE-crlf",\r\n    "BROKEN": "FIXTUREVALUE-unterminated\r\n' > "$work/edge/settings.json"
broken=$(sh "$reader" --show "$work/edge/settings.json")
no_marker "$broken" "show broken settings"
expect_text "$broken" "bypassPermissions" "show broken settings"

cat > "$work/edge/config.toml" <<'TOML'
sandbox_mode = "read-only"
experimental_bearer_token = "FIXTUREVALUE-toml-top"
[mcp_servers.x]
command = "npx"
args = [
  "-y",
  "--password=FIXTUREVALUE-toml-flag",
]
env = { KEY = "FIXTUREVALUE-toml-inline" }
http_headers = { Authorization = "Bearer FIXTUREVALUE-toml-header" }
[mcp_servers.x.env]
command = "FIXTUREVALUE-toml-env-named-command"
TOML
toml=$(sh "$reader" --show "$work/edge/config.toml")
no_marker "$toml" "show edge toml"
expect_text "$toml" "read-only" "show edge toml"

# 8. No agent files, and no Git (Review Focus 3 and 4).
mkdir "$work/empty"
code=0
none=$(sh "$reader" "$work/empty") || code=$?
[ "$code" -eq 0 ] || fail "list: an empty folder did not exit 0"
[ -z "$none" ] || fail "list: an empty folder printed something"

cp -R "$repo" "$work/nogit"
rm -rf "$work/nogit/.git"
nogit=$(sh "$reader" "$work/nogit")
expect_line "$nogit" ".claude/settings.json:claude-code:settings:no-git" "list no-git"
printf '%s\n' "$nogit" | grep -vq ':no-git$' && fail "list no-git: a state other than no-git"

# 9. Usage errors.
code=0
sh "$reader" --show >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] || fail "usage: --show without a file did not exit 2"
code=0
sh "$reader" --home >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] || fail "usage: --home without a folder did not exit 2"

# 10. The reader writes nothing.
[ -z "$(git -C "$repo" status --porcelain)" ] || fail "the reader changed the repository"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "list-agent-config: all checks passed"
