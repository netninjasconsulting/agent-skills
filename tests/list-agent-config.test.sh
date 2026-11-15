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
expect_line "$list" ".env:shared:env:ignored" "list"
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

# 7a. Findings of the branch review, one case each. Every value holds the marker.
r="$work/review"
mkdir -p "$r/wf/.github/workflows" "$r/wf/packages/api"

# A flag and its value on separate lines, in JSON and in TOML.
cat > "$r/c1.json" <<'JSON'
{
  "mcpServers": {
    "x": {
      "command": "npx",
      "args": [
        "-y",
        "srv",
        "--api-key",
        "FIXTUREVALUE-c1-json",
        "--header",
        "X-API-Key: FIXTUREVALUE-c1-header",
        "after"
      ]
    }
  }
}
JSON
cat > "$r/c1.toml" <<'TOML'
[mcp_servers.x]
command = "npx"
args = [
  "srv",
  "--token",
  "FIXTUREVALUE-c1-toml",
  "after",
]
TOML
# A JSON value that spans lines.
cat > "$r/c2.json" <<'JSON'
{
  "env": { "PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----
FIXTUREVALUE-c2-body
-----END PRIVATE KEY-----" },
  "command": "start
FIXTUREVALUE-c2-middle
FIXTUREVALUE-c2-tail",
  "type": "kept"
}
JSON
# A bracket inside a TOML string or comment.
cat > "$r/c3.toml" <<'TOML'
[mcp_servers.a]
args = ["a[", "b"]
secret = "FIXTUREVALUE-c3-after-string"
command = "x" # [ a note
other = "FIXTUREVALUE-c3-after-comment"
[mcp_servers.a.env]
KEY = "FIXTUREVALUE-c3-env"
TOML
# Comments.
cat > "$r/c4.env" <<'ENV'
# DB_PASS=FIXTUREVALUE-c4-env
#SESSION=FIXTUREVALUE-c4-env2
MULTI="first
FIXTUREVALUE-c4-env-multiline
last"
NAME=value
ENV
cat > "$r/c4.toml" <<'TOML'
# token = "FIXTUREVALUE-c4-toml"
sandbox_mode = "read-only"
TOML
cat > "$r/c4.json" <<'JSON'
{
  // "token": "FIXTUREVALUE-c4-json-line"
  /* FIXTUREVALUE-c4-json-block
     FIXTUREVALUE-c4-json-block2 */
  "env": {
    // }
    "command": "FIXTUREVALUE-c4-brace-in-comment"
  },
  "type": "kept"
}
JSON
# Quoted values after an assignment or a flag.
cat > "$r/c5.json" <<'JSON'
{
  "permissions": {
    "allow": [
      "Bash(API_TOKEN='FIXTUREVALUE-c5-single' run-a)",
      "Bash(X_SECRET=\"FIXTUREVALUE-c5-double\" run-b)",
      "Bash(tool --token 'FIXTUREVALUE-c5-flag-single')",
      "Bash(tool --password \"FIXTUREVALUE-c5-flag-double\")"
    ]
  }
}
JSON
# Workflows and other text.
cat > "$r/i1.yml" <<'YAML'
permissions:
  id-token: write
jobs:
  a:
    runs-on: ubuntu-latest
    env:
      API_KEY: "FIXTUREVALUE-i1-quoted"
      DB_PASSWORD: FIXTUREVALUE-i1
      GH_TOKEN: ${{ secrets.BOT_TOKEN }}
      PRIVATE_KEY: |
        -----BEGIN PRIVATE KEY-----
        FIXTUREVALUE-i1-pem
        -----END PRIVATE KEY-----
    steps:
      - run: echo done
YAML
printf 'machine example.com login me password FIXTUREVALUE-i1-netrc\n' > "$r/.netrc"
printf 'export API_TOKEN=FIXTUREVALUE-i1-envrc\n' > "$r/.envrc"
printf 'SECRET=FIXTUREVALUE-i1-env-prod\n' > "$r/.env-prod"
# Credential forms outside the first word list.
cat > "$r/i2.json" <<'JSON'
{
  "mcpServers": {
    "a": { "command": "npx", "args": ["--header", "Authorization: Token FIXTUREVALUE-i2-auth", "-u", "user:FIXTUREVALUE-i2-u", "--pass=FIXTUREVALUE-i2-pass", "MYSQL_PWD=FIXTUREVALUE-i2-pwd"] },
    "b": { "command": "curl -H 'X-API-Key: FIXTUREVALUE-i2-h' -u admin:FIXTUREVALUE-i2-cu https://api.example.com" },
    "c": { "command": "run", "args": ["FIXTUREVALUE0123456789abcdefABCDEF99", "plain-word"] }
  }
}
JSON
# A password with a slash in an address.
cat > "$r/i3.json" <<'JSON'
{ "mcpServers": { "a": { "type": "http", "url": "https://deploy:Sup3r/FIXTUREVALUE-i3@host.example.com/v1" } } }
JSON
printf 'DATABASE_URL=postgres://app:FIXTUREVALUE/i3-env@db.example.com:5432/x\nPLAIN_URL=https://plain.example.com/path\n' > "$r/i3.env"
# A byte that is not valid UTF-8, in a UTF-8 locale.
printf '{ "mcpServers": { "a": { "command": "run", "args": ["--password=FIXTUREVALUE-i4\351x", "ok"] } } }\n' > "$r/i4.json"
# A hidden key whose value starts on the next line.
cat > "$r/i5.json" <<'JSON'
{
  "headers":
  {
    "url": "FIXTUREVALUE-i5-next-line-object"
  },
  "args": [
    { "token":
      "FIXTUREVALUE-i5-next-line-value" }
  ],
  "type": "kept"
}
JSON
cat > "$r/i5.toml" <<'TOML'
env = {
  command = "FIXTUREVALUE-i5-toml"
}
sandbox_mode = "read-only"
TOML

for file in c1.json c1.toml c2.json c3.toml c4.env c4.toml c4.json c5.json i1.yml .envrc .env-prod i2.json i3.json i3.env i5.json i5.toml; do
  out=$(sh "$reader" --show "$r/$file" 2>&1) || true
  no_marker "$out" "review case $file"
done
out=$(LC_ALL=C.UTF-8 sh "$reader" --show "$r/i4.json" 2>&1) || true
no_marker "$out" "review case i4.json in a UTF-8 locale"

# The cases still show what the check needs.
expect_text "$(sh "$reader" --show "$r/c1.json")" "after" "review c1.json"
expect_text "$(sh "$reader" --show "$r/c1.json")" "--api-key" "review c1.json"
expect_text "$(sh "$reader" --show "$r/c1.toml")" "after" "review c1.toml"
expect_text "$(sh "$reader" --show "$r/c2.json")" "kept" "review c2.json"
expect_text "$(sh "$reader" --show "$r/c3.toml")" "[mcp_servers.a.env]" "review c3.toml"
expect_text "$(sh "$reader" --show "$r/c4.env")" "NAME=" "review c4.env"
expect_text "$(sh "$reader" --show "$r/c4.toml")" "read-only" "review c4.toml"
expect_text "$(sh "$reader" --show "$r/c4.json")" "kept" "review c4.json"
expect_text "$(sh "$reader" --show "$r/c5.json")" "run-a" "review c5.json"
expect_text "$(sh "$reader" --show "$r/c5.json")" "run-b" "review c5.json"
expect_text "$(sh "$reader" --show "$r/i1.yml")" "id-token: write" "review i1.yml"
expect_text "$(sh "$reader" --show "$r/i1.yml")" "secrets.BOT_TOKEN" "review i1.yml"
expect_text "$(sh "$reader" --show "$r/i1.yml")" "runs-on: ubuntu-latest" "review i1.yml"
expect_text "$(sh "$reader" --show "$r/i2.json")" "plain-word" "review i2.json"
expect_text "$(sh "$reader" --show "$r/i2.json")" "api.example.com" "review i2.json"
expect_text "$(sh "$reader" --show "$r/i3.json")" "host.example.com" "review i3.json"
expect_text "$(sh "$reader" --show "$r/i3.env")" "db.example.com" "review i3.env"
expect_text "$(sh "$reader" --show "$r/i3.env")" "PLAIN_URL=https://plain.example.com" "review i3.env"
expect_text "$(sh "$reader" --show "$r/i5.json")" "kept" "review i5.json"
expect_text "$(sh "$reader" --show "$r/i5.toml")" "read-only" "review i5.toml"

# More forms from the reviewer's own attack files.
cat > "$r/more.json" <<'JSON'
{
  "mcpServers": {
    "a": { "command": "mysql", "args": ["-pFIXTUREVALUE-short-flag", "--pat=FIXTUREVALUE-pat", "--dsn=admin:FIXTUREVALUE-dsn@tcp(db:3306)/app"] },
    "b": { "command": "server -token FIXTUREVALUE-go-flag -v" },
    "c": { "command": "sshpass -p 'FIXTUREVALUE-quoted-p' ssh deploy@host" },
    "d": { "command": "redis-cli -a FIXTUREVALUE-dash-a ping" },
    "e": { "type": "http", "url": "https://mcp.example.com/FIXTUREVALUE24x/sse" },
    "f": { "type": "http", "url": "https://mcp.example.com/sse#FIXTUREVALUE-fragment" },
    "g": { "type": "http", "url": "https://FIXTUREVALUE28key.mcp.example.com/sse" },
    "h": { "type": "http", "url": "https://mcp.example.com/k/FIXTUREVALUE26.abcdefghij.klmnopqrstuvwxyz/sse" },
    "i": { "type": "http", "url": "https://prod-db-01.example.com/mcp" },
    "j": { "command": "run", "args": ["wJalrXUtnFEMI/K7MDENG/bPxRfiFIXTUREVALUE"] }
  }
}
JSON
out=$(sh "$reader" --show "$r/more.json" 2>&1) || true
no_marker "$out" "review case more.json"
expect_text "$out" "prod-db-01.example.com/mcp" "review more.json"
expect_text "$out" "mcp.example.com" "review more.json"
expect_text "$out" "deploy@host" "review more.json"

# A file type the reader does not know is refused.
code=0
out=$(sh "$reader" --show "$r/.netrc" 2>&1) || code=$?
[ "$code" -eq 4 ] || fail "show: an unknown file type did not exit 4 (exit $code)"
no_marker "$out" "show unknown file type"

# The list: workflows that run no agent are left out, and nested agent files are found.
git -C "$r/wf" init -q -b main
printf 'jobs:\n  a:\n    steps:\n      - run: psql -c "declare cursor for select 1"\n' > "$r/wf/.github/workflows/sql.yml"
printf 'jobs:\n  a:\n    steps:\n      - run: echo raiders\n' > "$r/wf/.github/workflows/raiders.yml"
printf '# this used to run codex\njobs:\n  a:\n    steps:\n      - run: echo hello\n' > "$r/wf/.github/workflows/commented.yml"
printf 'jobs:\n  a:\n    steps:\n      - run: claude\n' > "$r/wf/.github/workflows/run-claude.yml"
printf '# nested\n' > "$r/wf/packages/api/CLAUDE.md"
wf=$(sh "$reader" "$r/wf")
expect_line "$wf" ".github/workflows/run-claude.yml:shared:workflow:untracked" "list workflows"
expect_line "$wf" "packages/api/CLAUDE.md:claude-code:instructions:untracked" "list nested"
for name in sql.yml raiders.yml commented.yml; do
  printf '%s\n' "$wf" | grep -q "$name" && fail "list workflows: $name runs no agent and is listed"
done

# 7b. A server that carries the name of a hidden block (review minor 10).
# The name of a server is not a block of credentials. Its settings are shown,
# and the env block inside it is still hidden.
n="$work/names"
mkdir -p "$n/a" "$n/b" "$n/c" "$n/d" "$n/e" "$n/.vscode"
cat > "$n/a/.mcp.json" <<'JSON'
{
  "mcpServers": {
    "auth": {
      "command": "npx",
      "args": ["auth-server"],
      "env": {
        "API_KEY": "FIXTUREVALUE-m10-env"
      }
    },
    "env": { "command": "envsrv", "env": { "command": "FIXTUREVALUE-m10-inner" } },
    "headers":
    {
      "command": "hdrsrv"
    }
  },
  "auth": { "command": "FIXTUREVALUE-m10-after" }
}
JSON
out=$(sh "$reader" --show "$n/a/.mcp.json")
no_marker "$out" "server names json"
expect_text "$out" '"npx"' "server named auth: command"
expect_text "$out" '"auth-server"' "server named auth: args"
expect_text "$out" '"envsrv"' "server named env: command"
expect_text "$out" '"hdrsrv"' "server named headers: command"

printf '{"mcpServers":{"oauth":{"command":"oauthsrv","env":{"K":"FIXTUREVALUE-m10-oneline"}}},"env":{"command":"FIXTUREVALUE-m10-top"}}\n' > "$n/b/.mcp.json"
out=$(sh "$reader" --show "$n/b/.mcp.json")
no_marker "$out" "server names json one line"
expect_text "$out" '"oauthsrv"' "server named oauth: command"

# A hidden block outside a list of servers stays hidden.
printf '{\n  "env": {\n    "command": "FIXTUREVALUE-m10-settings"\n  },\n  "x": [ { "mcpServers": {} }, { "auth": { "command": "FIXTUREVALUE-m10-array" } } ]\n}\n' > "$n/c/settings.json"
out=$(sh "$reader" --show "$n/c/settings.json")
no_marker "$out" "hidden block outside servers"

printf '{\n  "servers": {\n    "auth": { "command": "vscodesrv", "env": { "T": "FIXTUREVALUE-m10-vscode" } }\n  }\n}\n' > "$n/.vscode/mcp.json"
out=$(sh "$reader" --show "$n/.vscode/mcp.json")
no_marker "$out" "server names vscode"
expect_text "$out" '"vscodesrv"' "server named auth in servers: command"

cat > "$n/d/config.toml" <<'TOML'
[mcp_servers.auth]
command = "tomlauthsrv"

[mcp_servers.auth.env]
API_KEY = "FIXTUREVALUE-m10-toml-env"

[mcp_servers]
env.command = "tomlenvsrv"
env.env = { K = "FIXTUREVALUE-m10-toml-inline" }

[auth]
command = "FIXTUREVALUE-m10-toml-top"
TOML
out=$(sh "$reader" --show "$n/d/config.toml")
no_marker "$out" "server names toml"
expect_text "$out" '"tomlauthsrv"' "toml server named auth: command"
expect_text "$out" '"tomlenvsrv"' "toml server named env: command"

printf 'mcp_servers.oauth.command = "tomloauthsrv"\nmcp_servers.oauth.env.K = "FIXTUREVALUE-m10-toml-dotted"\noauth.command = "FIXTUREVALUE-m10-toml-dotted-top"\n' > "$n/e/config.toml"
out=$(sh "$reader" --show "$n/e/config.toml")
no_marker "$out" "server names toml dotted"
expect_text "$out" '"tomloauthsrv"' "toml dotted server named oauth: command"

# 7c. The open-rows variant of the fixture (review minor 5). It plants what
# makes rows 3, 4, and 6 "open": production cloud keys in the agent job and a
# self-hosted runner. The reader keeps that evidence readable.
sh "$root/tests/fixtures/agent-permissions-check/make-repo.sh" "$work/open" open-rows >/dev/null
out=$(sh "$reader" "$work/open/repo")
expect_line "$out" ".github/workflows/agent.yml:shared:workflow:tracked" "open-rows list"
out=$(sh "$reader" --show "$work/open/repo/.github/workflows/agent.yml")
no_marker "$out" "open-rows workflow"
expect_text "$out" 'runs-on: self-hosted' "open-rows: runner"
expect_text "$out" 'secrets.PROD_AWS_SECRET_ACCESS_KEY' "open-rows: production key by name"
expect_text "$out" 'secrets.PROD_AWS_ACCESS_KEY_ID' "open-rows: production key id by name"
[ -z "$(git -C "$work/open/repo" status --porcelain)" ] || fail "open-rows: the fixture repository is not clean"
code=0
sh "$root/tests/fixtures/agent-permissions-check/make-repo.sh" "$work/bad" no-such-variant >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] || fail "make-repo: an unknown variant did not exit 2"
[ ! -e "$work/bad" ] || fail "make-repo: an unknown variant left a folder behind"

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
