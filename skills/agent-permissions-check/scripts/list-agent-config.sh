#!/bin/sh
# list-agent-config.sh: list the configuration files of AI coding agents, and
# print one of them with every value hidden except the permission settings.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   sh list-agent-config.sh [path]             list agent files in the repository at path
#   sh list-agent-config.sh --home DIR [path]  also list the agent files under DIR
#   sh list-agent-config.sh --show FILE        print FILE with line numbers and values masked
#
# List output, one line per file: <path>:<agent>:<kind>:<state>
#   agent: claude-code | codex | shared
#   kind:  instructions | settings | mcp | hooks | workflow | credential-store
#   state: tracked | untracked | ignored | no-git | home
#
# The script reads files and Git objects. It writes nothing, changes nothing,
# and makes no network request. Under DIR it looks only at the paths named in
# references/agent-files.md. It never walks the home folder.
#
# The masked view hides by default. In JSON and TOML it prints every key and
# replaces every value with <redacted>, except the values of keys that carry
# permissions. Those values still pass the token, URL, and flag filters. In an
# env file it prints names, and for an address the scheme and the host. It
# refuses to print a credential store. Of ~/.claude.json it prints the
# mcpServers blocks only.

set -u

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

MODE=list
ROOT=.
HOME_DIR=
SHOW_FILE=

while [ $# -gt 0 ]; do
  case "$1" in
    --home)
      shift
      [ $# -gt 0 ] || { echo "list-agent-config: --home needs a folder" >&2; exit 2; }
      HOME_DIR=$1
      ;;
    --show)
      MODE=show
      shift
      [ $# -gt 0 ] || { echo "list-agent-config: --show needs a file" >&2; exit 2; }
      SHOW_FILE=$1
      ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "list-agent-config: unknown option: $1" >&2; exit 2 ;;
    *) ROOT=$1 ;;
  esac
  shift
done

# Keys whose values are shown. Each one carries a permission or says how a
# server starts. None of them is a place where a credential belongs.
SHOW_KEYS='allow ask deny defaultMode additionalDirectories disableBypassPermissionsMode disableAutoMode enableAllProjectMcpServers enabledMcpjsonServers disabledMcpjsonServers command args type url matcher approval_policy sandbox_mode network_access writable_roots default_permissions enabled enabled_tools disabled_tools default_tools_approval_mode approval_mode'

# Keys and table names under which everything is hidden, whatever the key.
HIDE_KEYS='env headers http_headers env_http_headers oauth auth oauthAccount'

# A workflow runs an agent when it names one of these.
AGENT_WORKFLOW='claude-code|claude_code|codex|copilot|cursor|gemini-cli|aider|opencode|(^|[[:space:]])claude[[:space:]]'

is_git() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

git_state() {
  if ! is_git; then
    echo no-git
  elif git -C "$ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    echo tracked
  elif git -C "$ROOT" check-ignore -q -- "$1" 2>/dev/null; then
    echo ignored
  else
    echo untracked
  fi
}

# $1 = path relative to the repository, $2 = agent, $3 = kind
emit() {
  if [ -f "$ROOT/$1" ]; then
    printf '%s:%s:%s:%s\n' "$1" "$2" "$3" "$(git_state "$1")"
  fi
}

# $1 = folder relative to the repository, $2 = agent, $3 = kind
emit_folder() {
  if [ -d "$ROOT/$1" ]; then
    for file in "$ROOT/$1"/*; do
      [ -f "$file" ] || continue
      emit "$1/$(basename "$file")" "$2" "$3"
    done
  fi
}

# $1 = path relative to the home folder, $2 = agent, $3 = kind
emit_home() {
  if [ -f "$HOME_DIR/$1" ]; then
    printf '%s:%s:%s:home\n' "$HOME_DIR/$1" "$2" "$3"
  fi
}

list() {
  [ -d "$ROOT" ] || { echo "list-agent-config: not a directory: $ROOT" >&2; exit 2; }

  emit .claude/settings.json claude-code settings
  emit .claude/settings.local.json claude-code settings
  emit .mcp.json claude-code mcp
  emit CLAUDE.md claude-code instructions
  emit CLAUDE.local.md claude-code instructions
  emit .claude/CLAUDE.md claude-code instructions
  emit_folder .claude/rules claude-code instructions

  emit .codex/config.toml codex settings
  emit .codex/hooks.json codex hooks

  emit AGENTS.md shared instructions
  emit GEMINI.md shared instructions
  emit .github/copilot-instructions.md shared instructions
  emit .cursorrules shared instructions
  emit_folder .cursor/rules shared instructions
  emit .cursor/mcp.json shared mcp
  emit .vscode/mcp.json shared mcp
  emit .gemini/settings.json shared mcp

  if [ -d "$ROOT/.github/workflows" ]; then
    for file in "$ROOT"/.github/workflows/*.yml "$ROOT"/.github/workflows/*.yaml; do
      [ -f "$file" ] || continue
      if grep -qiE -e "$AGENT_WORKFLOW" "$file" 2>/dev/null; then
        emit ".github/workflows/$(basename "$file")" shared workflow
      fi
    done
  fi

  if [ -n "$HOME_DIR" ]; then
    [ -d "$HOME_DIR" ] || { echo "list-agent-config: not a directory: $HOME_DIR" >&2; exit 2; }
    emit_home .claude/settings.json claude-code settings
    emit_home .claude.json claude-code mcp
    emit_home .claude/CLAUDE.md claude-code instructions
    emit_home .claude/.credentials.json claude-code credential-store
    emit_home .codex/config.toml codex settings
    emit_home .codex/AGENTS.md codex instructions
    emit_home .codex/hooks.json codex hooks
    emit_home .codex/auth.json codex credential-store
    emit_home .cursor/mcp.json shared mcp
    emit_home .gemini/settings.json shared mcp
  fi
}

show() {
  [ -f "$SHOW_FILE" ] || { echo "list-agent-config: not a file: $SHOW_FILE" >&2; exit 2; }
  base=$(basename "$SHOW_FILE")
  mcponly=0
  case "$base" in
    auth.json | .credentials.json)
      echo "list-agent-config: credential store, not shown: $SHOW_FILE" >&2
      exit 3
      ;;
    .env | .env.* | *.env) format="env" ;;
    .claude.json) format="json"; mcponly=1 ;;
    *.json) format="json" ;;
    *.toml) format="toml" ;;
    *) format="text" ;;
  esac

  # A word that marks a name as the name of a credential, in either case.
  W='([Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww]([Oo][Rr])?[Dd]|[Aa][Uu][Tt][Hh]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]|[Bb][Ee][Aa][Rr][Ee][Rr])'
  Q="'"

  awk -v format="$format" -v mcponly="$mcponly" -v showkeys="$SHOW_KEYS" -v hidekeys="$HIDE_KEYS" '
    BEGIN {
      n = split(showkeys, list, " "); for (i = 1; i <= n; i++) SHOW[list[i]] = 1
      n = split(hidekeys, list, " "); for (i = 1; i <= n; i++) HIDE[list[i]] = 1
      arraykey = ""; hide = 0; hidedepth = 0; mcpprint = 0; mcpdepth = 0
      arr = ""; arrdepth = 0; arrshow = 0; thide = 0; inml = 0
      if (mcponly) printf "      \t(only the mcpServers blocks of this file are shown)\n"
    }

    function cnt(s, ch,    c, i) {
      c = 0
      for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) c++
      return c
    }

    function emit(s) { printf "%6d\t%s\n", NR, s }

    # Text between two strings. Hides a bare value after a colon, and any long number.
    function scalars(text, ok) {
      if (ok) return text
      if (text ~ /^[ \t]*:[ \t]*[-+0-9A-Za-z.]/) sub(/:[ \t]*[-+0-9A-Za-z.]+/, ": <redacted>", text)
      gsub(/[-+]?[0-9][0-9.eE+-][0-9.eE+-][0-9.eE+-][0-9.eE+-][0-9.eE+-]+/, "<redacted>", text)
      return text
    }

    # One line of JSON. A string is a key when a colon follows it. Any other
    # string is a value, governed by the last key on the line or by the key of
    # the array the line sits in. A value is shown only when that key is shown.
    function json_line(line,    rest, out, after, pre, str, post, lastkey, linehide, hideafter, gov, ok, d, q) {
      rest = line; out = ""; after = ""; lastkey = ""; linehide = 0; hideafter = ""
      LSTRUCT = ""; LMCP = 0; LMCPAFTER = ""
      while (match(rest, /"([^"\\]|\\.)*"/)) {
        pre = substr(rest, 1, RSTART - 1)
        str = substr(rest, RSTART, RLENGTH)
        post = substr(rest, RSTART + RLENGTH)
        gov = (lastkey != "") ? lastkey : arraykey
        ok = (!hide && !linehide && (gov in SHOW))
        out = out scalars(pre, ok)
        LSTRUCT = LSTRUCT pre; after = after pre
        if (linehide) hideafter = hideafter pre
        if (LMCP) LMCPAFTER = LMCPAFTER pre
        if (post ~ /^[ \t]*:/) {
          lastkey = substr(str, 2, length(str) - 2)
          out = out str
          after = ""
          if (lastkey in HIDE) { if (!linehide) hideafter = ""; linehide = 1 }
          if (lastkey == "mcpServers") { LMCP = 1; LMCPAFTER = "" }
        } else {
          out = out (ok ? str : "\"<redacted>\"")
        }
        rest = post
      }
      # A quote with no partner: hide everything from it to the end of the line.
      q = index(rest, "\"")
      gov = (lastkey != "") ? lastkey : arraykey
      ok = (!hide && !linehide && (gov in SHOW))
      if (q > 0) {
        pre = substr(rest, 1, q - 1)
        out = out scalars(pre, ok) "\"<redacted>"
        rest = pre
      } else {
        out = out scalars(rest, ok)
      }
      LSTRUCT = LSTRUCT rest; after = after rest
      if (linehide) hideafter = hideafter rest
      if (LMCP) LMCPAFTER = LMCPAFTER rest

      if (hide) {
        hidedepth += cnt(LSTRUCT, "{") - cnt(LSTRUCT, "}")
        if (hidedepth <= 0) hide = 0
      } else if (linehide) {
        d = cnt(hideafter, "{") - cnt(hideafter, "}")
        if (d > 0) { hide = 1; hidedepth = d }
      }

      if (lastkey != "" && cnt(after, "[") > cnt(after, "]")) arraykey = lastkey
      else if (cnt(LSTRUCT, "]") > cnt(LSTRUCT, "[")) arraykey = ""
      return out
    }

    # One line of TOML.
    function toml_line(line,    key, val, k, n, parts, i, ok, d, t) {
      if (inml) { if (line ~ /"""|\047\047\047/) inml = 0; return "<redacted>" }
      if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) return line
      if (arr != "") {
        arrdepth += cnt(line, "[") - cnt(line, "]")
        if (arrdepth <= 0) arr = ""
        return arrshow ? line : "<redacted>"
      }
      if (line ~ /^[ \t]*\[/) {
        thide = 0
        t = line; gsub(/[][ \t"\047]/, "", t)
        n = split(t, parts, ".")
        for (i = 1; i <= n; i++) if (parts[i] in HIDE) thide = 1
        return line
      }
      if (match(line, /^[ \t]*[A-Za-z0-9_."\047-]+[ \t]*=/)) {
        key = substr(line, RSTART, RLENGTH)
        val = substr(line, RSTART + RLENGTH)
        k = substr(key, 1, length(key) - 1); gsub(/[ \t"\047]/, "", k)
        n = split(k, parts, ".")
        ok = (!thide && (parts[n] in SHOW))
        for (i = 1; i <= n; i++) if (parts[i] in HIDE) ok = 0
        if (val ~ /"""|\047\047\047/ && val !~ /""".*"""|\047\047\047.*\047\047\047/) { inml = 1; return key " <redacted>" }
        d = cnt(val, "[") - cnt(val, "]")
        if (d > 0 && val ~ /^[ \t]*\[/) { arr = k; arrdepth = d; arrshow = ok }
        return ok ? line : key " <redacted>"
      }
      return "<redacted>"
    }

    # One line of an env file: the name, and for an address the scheme and the host.
    function env_line(line,    key, val, scheme, rest, at, slash, host) {
      if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) return line
      if (match(line, /^[ \t]*(export[ \t]+)?[A-Za-z0-9_.-]+[ \t]*=/)) {
        key = substr(line, 1, RLENGTH)
        val = substr(line, RLENGTH + 1); gsub(/^["\047 \t]+/, "", val)
        if (match(val, /^[A-Za-z][A-Za-z0-9+.-]*:\/\//)) {
          scheme = substr(val, 1, RLENGTH)
          rest = substr(val, RLENGTH + 1)
          slash = match(rest, /[\/?#"\047 \t]/)
          host = slash ? substr(rest, 1, slash - 1) : rest
          at = index(host, "@")
          while (at > 0) { host = substr(host, at + 1); at = index(host, "@") }
          return key scheme "<redacted>@" host "/<redacted>"
        }
        return key "<redacted>"
      }
      return "<redacted>"
    }

    { sub(/\r$/, "") }

    format == "json" {
      masked = json_line($0)
      if (!mcponly) { emit(masked); next }
      if (mcpprint) {
        emit(masked)
        mcpdepth += cnt(LSTRUCT, "{") - cnt(LSTRUCT, "}")
        if (mcpdepth <= 0) mcpprint = 0
      } else if (LMCP) {
        emit(masked)
        d = cnt(LMCPAFTER, "{") - cnt(LMCPAFTER, "}")
        if (d > 0) { mcpprint = 1; mcpdepth = d }
      }
      next
    }
    format == "toml" { emit(toml_line($0)); next }
    format == "env" { emit(env_line($0)); next }
    { emit($0) }
  ' "$SHOW_FILE" | sed -E \
    -e 's/(AKIA|ASIA)[0-9A-Z]{16}/<redacted:aws-access-key-id>/g' \
    -e 's/-----BEGIN ([A-Z]+ )?PRIVATE KEY-----.*/<redacted:private-key-block>/g' \
    -e 's/(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/<redacted:github-token>/g' \
    -e 's/[sr]k_live_[A-Za-z0-9_]{8,}/<redacted:stripe-secret-key>/g' \
    -e 's/whsec_[A-Za-z0-9_]{8,}/<redacted:stripe-webhook-secret>/g' \
    -e 's/sk-ant-[A-Za-z0-9_-]{16,}/<redacted:anthropic-api-key>/g' \
    -e 's/sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}/<redacted:openai-api-key>/g' \
    -e 's/AIza[0-9A-Za-z_-]{35}/<redacted:google-api-key>/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/sb_secret_[A-Za-z0-9_-]{10,}/<redacted:supabase-secret-key>/g' \
    -e 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/<redacted:json-web-token>/g' \
    -e "s#([A-Za-z][A-Za-z0-9+.-]*://)[^/@[:space:]\"$Q<]+@#\1<redacted>@#g" \
    -e "s#(://[^[:space:]\"$Q?]*)\?[^[:space:]\"$Q]*#\1?<redacted>#g" \
    -e "s#(://[^[:space:]\"$Q]*/)[A-Za-z0-9_-]{20,}#\1<redacted>#g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)[^[:space:]\"$Q,<]+/\1<redacted>/g" \
    -e "s/(\"--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*\"[[:space:]]*,[[:space:]]*\")[^\"]*\"/\1<redacted>\"/g" \
    -e "s/(--[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)[^[:space:]\"$Q<\$-][^[:space:]\"$Q]*/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_]*${W}[A-Za-z0-9_]*=)[^[:space:]\"$Q,;<\$]+/\1<redacted>/g" \
    -e 's/(([Bb]earer|[Bb]asic)[[:space:]]+)[A-Za-z0-9._~+\/=-]{8,}/\1<redacted>/g' \
    -e "s/^([[:space:]]*[0-9]+	[[:space:]-]*[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*:[[:space:]]+)[^[:space:]\$<\"$Q{[|>][^[:space:]]{11,}/\1<redacted>/"
}

case "$MODE" in
  list) list ;;
  show) show ;;
esac
