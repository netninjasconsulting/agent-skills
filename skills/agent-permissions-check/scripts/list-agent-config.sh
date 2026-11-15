#!/bin/sh
# list-agent-config.sh: list the configuration files of AI coding agents, and
# print one of them with its values hidden.
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
#   kind:  instructions | settings | mcp | hooks | workflow | env | credential-store
#   state: tracked | untracked | ignored | no-git | home
#
# The script reads files and Git objects. It writes nothing, changes nothing,
# and makes no network request. Under DIR it looks only at the paths named in
# references/agent-files.md. It never walks the home folder.
#
# What --show prints depends on the file:
#   JSON, TOML  Every key. A value only when its key carries a permission, and
#               then through the token, address, flag, and long-word filters.
#               Comments and anything under env, headers, or auth are hidden.
#   env files   Names. For an address, the scheme and the host.
#   YAML        The file, with the value of every key whose name marks a
#               credential hidden, and with the filters above.
#   Markdown    The file, through the filters above.
#   Exit 3      A credential store. Never shown.
#   Exit 4      Any other file type. Not shown.
# Of ~/.claude.json it prints the mcpServers blocks only.

set -u
LC_ALL=C
export LC_ALL

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
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

# Flags whose value is the next word, and is hidden.
VALUE_FLAGS='-H --header -u --user -p -a'

# A workflow runs an agent when a line that is not a comment names one of these as a word.
AGENT_WORKFLOW='(^|[^A-Za-z0-9_])(claude-code|claude_code|codex|copilot|cursor-agent|gemini-cli|aider|opencode|claude)([^A-Za-z0-9_]|$)'

# Agent files below the top folder, found through Git.
NESTED='(^|/)(CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md|GEMINI\.md|\.mcp\.json)$|(^|/)\.claude/settings(\.local)?\.json$|(^|/)\.codex/config\.toml$'
TOP_LEVEL='CLAUDE\.md|CLAUDE\.local\.md|AGENTS\.md|GEMINI\.md|\.mcp\.json|\.claude/CLAUDE\.md|\.claude/settings\.json|\.claude/settings\.local\.json|\.codex/config\.toml'

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
      if grep -vE '^[[:space:]]*#' "$file" 2>/dev/null | grep -qiE -e "$AGENT_WORKFLOW"; then
        emit ".github/workflows/$(basename "$file")" shared workflow
      fi
    done
  fi

  for file in "$ROOT"/.env "$ROOT"/.env.* "$ROOT"/.envrc; do
    [ -f "$file" ] || continue
    emit "$(basename "$file")" shared env
  done

  if is_git; then
    git -C "$ROOT" ls-files -c -o --exclude-standard 2>/dev/null |
      grep -E -e "$NESTED" | grep -vxE -e "$TOP_LEVEL" |
      while IFS= read -r path; do
        case "$path" in
          *.mcp.json) emit "$path" claude-code mcp ;;
          *settings.json | *settings.local.json) emit "$path" claude-code settings ;;
          *config.toml) emit "$path" codex settings ;;
          *CLAUDE.md | *CLAUDE.local.md) emit "$path" claude-code instructions ;;
          *) emit "$path" shared instructions ;;
        esac
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
    .env | .env.* | .env-* | *.env | .envrc | env.*) format="env" ;;
    .claude.json) format="json"; mcponly=1 ;;
    *.json | *.jsonc) format="json" ;;
    *.toml) format="toml" ;;
    *.yml | *.yaml) format="yaml" ;;
    *.md | *.mdc | .cursorrules) format="text" ;;
    *)
      echo "list-agent-config: not a file type this reader shows: $SHOW_FILE" >&2
      exit 4
      ;;
  esac

  # A word that marks a name as the name of a credential, in either case.
  W='([Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss]|[Pp][Ww][Dd]|[Aa][Uu][Tt][Hh]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]|[Bb][Ee][Aa][Rr][Ee][Rr]|[Cc][Oo][Oo][Kk][Ii][Ee]|[Ss][Ee][Ss][Ss][Ii][Oo][Nn])'
  Q="'"

  awk -v format="$format" -v mcponly="$mcponly" -v showkeys="$SHOW_KEYS" -v hidekeys="$HIDE_KEYS" -v valueflags="$VALUE_FLAGS" '
    BEGIN {
      n = split(showkeys, list, " "); for (i = 1; i <= n; i++) SHOW[list[i]] = 1
      n = split(hidekeys, list, " "); for (i = 1; i <= n; i++) HIDE[list[i]] = 1
      n = split(valueflags, list, " "); for (i = 1; i <= n; i++) VFLAG[list[i]] = 1
      arraykey = ""; hide = 0; hidedepth = 0; mcpprint = 0; mcpdepth = 0
      instr = 0; incomment = 0; pendkey = ""; pend = 0
      arr = ""; arrdepth = 0; arrshow = 0; thide = 0; inml = 0; mlq = ""; tbl = 0
      envq = ""; yhide = -1; yscalar = 0; pem = 0
      if (mcponly) printf "      \t(only the mcpServers blocks of this file are shown)\n"
    }

    function cnt(s, ch,    c, i) {
      c = 0
      for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) c++
      return c
    }

    function emit(s) { printf "%6d\t%s\n", NR, s }

    function secretword(s) {
      return tolower(s) ~ /key|token|secret|pass|pwd|auth|credential|bearer|cookie|session/
    }

    # One shown string, with its quotes. A flag that takes a credential hides the string after it.
    function elem(str,    q, body) {
      q = substr(str, 1, 1)
      body = substr(str, 2, length(str) - 2)
      if (pend) { pend = 0; return q "<redacted>" q }
      if (body ~ /^-p./) return q "-p<redacted>" q
      if (body ~ /^--?[A-Za-z0-9_-]+$/ && ((body in VFLAG) || secretword(body))) pend = 1
      return str
    }

    # ---- JSON ----

    # Where a comment starts in text that holds no string. 0 when there is none.
    function cpos(text,    a, b) {
      a = index(text, "//"); b = index(text, "/*")
      if (a == 0) return b
      if (b == 0) return a
      return (a < b) ? a : b
    }

    # Text between two strings: structure, and bare values after a colon.
    function seg(text,    gov, ok, tmp, keep) {
      gov = (Jkey != "") ? Jkey : arraykey
      ok = (!hide && !Jhide && (gov in SHOW))
      LSTRUCT = LSTRUCT text; Jafter = Jafter text
      if (Jhide) Jhideafter = Jhideafter text
      if (LMCP) LMCPAFTER = LMCPAFTER text
      if (!ok) {
        if (text ~ /^[ \t]*:[ \t]*[-+0-9A-Za-z.]/) sub(/:[ \t]*[-+0-9A-Za-z.]+/, ": <redacted>", text)
        gsub(/[-+]?[0-9][0-9.eE+-][0-9.eE+-][0-9.eE+-][0-9.eE+-][0-9.eE+-]+/, "<redacted>", text)
      }
      tmp = text
      gsub(/<redacted>|true|false|null/, "", tmp)
      if (tmp ~ /[A-Za-z_]/) {
        keep = text; gsub(/[^][{}:, \t]/, "", keep)
        text = keep "<redacted>"
      }
      Jout = Jout text
    }

    # A comment that starts at position c of text. more is what follows text on the line.
    function comment(text, c, more) {
      seg(substr(text, 1, c - 1))
      Jout = Jout "<redacted>"
      if (substr(text, c, 2) == "/*" && index(substr(text, c + 2) more, "*/") == 0) incomment = 1
    }

    # One line of JSON. A string is a key when a colon follows it. Any other
    # string is a value, governed by the last key before it or by the key of
    # the array it sits in. A value is shown only when that key is shown.
    function json_line(line,    rest, pre, str, post, c, q, d, gov, ok) {
      Jout = ""; Jafter = ""; Jkey = ""; Jhide = 0; Jhideafter = ""
      LSTRUCT = ""; LMCP = 0; LMCPAFTER = ""
      if (incomment) { if (index(line, "*/")) incomment = 0; return "<redacted>" }
      rest = line
      if (instr) {
        if (!match(rest, /^([^"\\]|\\.)*"/)) return "<redacted>"
        rest = substr(rest, RLENGTH + 1); Jout = "<redacted>\""; instr = 0
      }
      if (pendkey != "") {
        Jkey = pendkey
        if (Jkey in HIDE) Jhide = 1
        if (Jkey == "mcpServers") LMCP = 1
        pendkey = ""
      }
      while (match(rest, /"([^"\\]|\\.)*"/)) {
        pre = substr(rest, 1, RSTART - 1)
        str = substr(rest, RSTART, RLENGTH)
        post = substr(rest, RSTART + RLENGTH)
        c = cpos(pre)
        if (c) { comment(pre, c, str post); rest = ""; break }
        seg(pre)
        if (post ~ /^[ \t]*:/) {
          Jkey = substr(str, 2, length(str) - 2)
          Jout = Jout str
          Jafter = ""; pend = 0
          if (Jkey in HIDE) { if (!Jhide) Jhideafter = ""; Jhide = 1 }
          if (Jkey == "mcpServers") { LMCP = 1; LMCPAFTER = "" }
        } else {
          gov = (Jkey != "") ? Jkey : arraykey
          ok = (!hide && !Jhide && (gov in SHOW))
          Jout = Jout (ok ? elem(str) : "\"<redacted>\"")
        }
        rest = post
      }
      c = cpos(rest); q = index(rest, "\"")
      if (c && (q == 0 || c < q)) {
        comment(rest, c, "")
      } else if (q) {
        # A quote with no partner: the value goes on. Hide it to its end.
        seg(substr(rest, 1, q - 1))
        Jout = Jout "\"<redacted>"
        instr = 1
      } else {
        seg(rest)
      }

      if (hide) {
        hidedepth += cnt(LSTRUCT, "{") - cnt(LSTRUCT, "}")
        if (hidedepth <= 0) hide = 0
      } else if (Jhide) {
        d = cnt(Jhideafter, "{") - cnt(Jhideafter, "}")
        if (d > 0) { hide = 1; hidedepth = d }
      }

      if (Jkey != "" && cnt(Jafter, "[") > cnt(Jafter, "]")) arraykey = Jkey
      else if (cnt(LSTRUCT, "]") > cnt(LSTRUCT, "[")) { arraykey = ""; pend = 0 }
      # The key ended the line: its value starts on the next one.
      if (Jkey != "" && !instr && Jafter ~ /^[ \t]*:[ \t]*$/) pendkey = Jkey
      return Jout
    }

    # ---- TOML ----

    # The line without its strings and without a trailing comment.
    function tstrip(s,    out, i, ch, q) {
      out = ""; q = ""
      for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)
        if (q != "") {
          if (ch == "\\" && q == "\"") i++
          else if (ch == q) q = ""
          continue
        }
        if (ch == "\"" || ch == "\047") { q = ch; continue }
        if (ch == "#") break
        out = out ch
      }
      return out
    }

    # Where a trailing comment starts. 0 when there is none.
    function tcomment(s,    i, ch, q) {
      q = ""
      for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)
        if (q != "") {
          if (ch == "\\" && q == "\"") i++
          else if (ch == q) q = ""
          continue
        }
        if (ch == "\"" || ch == "\047") { q = ch; continue }
        if (ch == "#") return i
      }
      return 0
    }

    # A shown value, or a line of a shown array.
    function tshow(s,    c, tail, out, rest) {
      c = tcomment(s); tail = ""
      if (c) { tail = "# <redacted>"; s = substr(s, 1, c - 1) }
      out = ""; rest = s
      while (match(rest, /"([^"\\]|\\.)*"|\047[^\047]*\047/)) {
        out = out substr(rest, 1, RSTART - 1) elem(substr(rest, RSTART, RLENGTH))
        rest = substr(rest, RSTART + RLENGTH)
      }
      if (match(rest, /["\047]/)) rest = substr(rest, 1, RSTART - 1) "<redacted>"
      return out rest tail
    }

    function toml_line(line,    st, key, val, k, n, parts, i, ok, d, sv, t, iskv, isheader) {
      if (inml) { if (index(line, mlq)) inml = 0; return "<redacted>" }
      st = tstrip(line)
      if (tbl > 0) { tbl += cnt(st, "{") - cnt(st, "}"); return "<redacted>" }
      if (line ~ /^[ \t]*$/) return line
      if (line ~ /^[ \t]*#/) return "# <redacted>"
      isheader = (st ~ /^[ \t]*\[\[?[A-Za-z0-9_. \t-]*\]\]?[ \t]*$/)
      iskv = match(line, /^[ \t]*[A-Za-z0-9_."\047-]+[ \t]*=/)
      if (iskv) { key = substr(line, RSTART, RLENGTH); val = substr(line, RSTART + RLENGTH) }
      if (arr != "" && !isheader && !iskv) {
        arrdepth += cnt(st, "[") - cnt(st, "]")
        t = arrshow ? tshow(line) : "<redacted>"
        if (arrdepth <= 0) { arr = ""; pend = 0 }
        return t
      }
      arr = ""; pend = 0
      if (isheader) {
        thide = 0
        t = line; sub(/#.*/, "", t); gsub(/[][ \t"\047]/, "", t)
        n = split(t, parts, ".")
        for (i = 1; i <= n; i++) if (parts[i] in HIDE) thide = 1
        return tshow(line)
      }
      if (iskv) {
        k = substr(key, 1, length(key) - 1); gsub(/[ \t"\047]/, "", k)
        n = split(k, parts, ".")
        ok = (!thide && (parts[n] in SHOW))
        for (i = 1; i <= n; i++) if (parts[i] in HIDE) ok = 0
        if (val ~ /"""/ && val !~ /""".*"""/) { inml = 1; mlq = "\"\"\""; return key " <redacted>" }
        if (val ~ /\047\047\047/ && val !~ /\047\047\047.*\047\047\047/) { inml = 1; mlq = "\047\047\047"; return key " <redacted>" }
        sv = tstrip(val)
        d = cnt(sv, "{") - cnt(sv, "}")
        if (d > 0) { tbl = d; return key " <redacted>" }
        d = cnt(sv, "[") - cnt(sv, "]")
        if (d > 0) { arr = k; arrdepth = d; arrshow = ok }
        return ok ? key tshow(val) : key " <redacted>"
      }
      return "<redacted>"
    }

    # ---- env files ----

    # The name, and for an address the scheme and the host.
    function env_line(line,    key, v, q, scheme, rest, at, i, creds, host) {
      if (envq != "") { if (index(line, envq)) envq = ""; return "<redacted>" }
      if (line ~ /^[ \t]*$/) return line
      if (line ~ /^[ \t]*#/) return "# <redacted>"
      if (match(line, /^[ \t]*(export[ \t]+)?[A-Za-z0-9_.-]+[ \t]*=/)) {
        key = substr(line, 1, RLENGTH)
        v = substr(line, RLENGTH + 1); sub(/^[ \t]+/, "", v)
        q = substr(v, 1, 1)
        if (q == "\"" || q == "\047") {
          v = substr(v, 2)
          if (index(v, q) == 0) envq = q
        }
        if (match(v, /^[A-Za-z][A-Za-z0-9+.-]*:\/\//)) {
          scheme = substr(v, 1, RLENGTH)
          rest = substr(v, RLENGTH + 1)
          if (match(rest, /["\047 \t]/)) rest = substr(rest, 1, RSTART - 1)
          at = 0
          for (i = 1; i <= length(rest); i++) if (substr(rest, i, 1) == "@") at = i
          creds = ""
          if (at) { creds = "<redacted>@"; rest = substr(rest, at + 1) }
          host = match(rest, /[\/?#]/) ? substr(rest, 1, RSTART - 1) : rest
          return key scheme creds host "/<redacted>"
        }
        return key "<redacted>"
      }
      return "<redacted>"
    }

    # ---- YAML ----

    # The value of a key whose name marks a credential is hidden, unless it
    # is an expression such as ${{ secrets.NAME }} or a permission word.
    function yaml_line(line,    ind, key, v, lk) {
      if (line ~ /^[ \t]*$/) return line
      ind = match(line, /[^ ]/) - 1
      if (yhide >= 0) {
        if (ind > yhide) {
          if (!yscalar && line ~ /^[ \t-]*[A-Za-z0-9_.-]+[ \t]*:[ \t]*["\047]?\$\{\{/) return line
          return "<redacted>"
        }
        yhide = -1
      }
      if (line ~ /^[ \t]*#/) return "# <redacted>"
      if (match(line, /^[ \t-]*[A-Za-z0-9_.-]+[ \t]*:/)) {
        key = substr(line, 1, RLENGTH)
        v = substr(line, RLENGTH + 1); gsub(/^[ \t]+|[ \t]+$/, "", v)
        lk = key; gsub(/[ \t:-]/, "", lk)
        if (secretword(lk)) {
          if (v == "") { yhide = ind; yscalar = 0; return line }
          if (v ~ /^[|>]/) { yhide = ind; yscalar = 1; return key " <redacted>" }
          if (v ~ /^["\047]?\$\{\{/) return line
          if (v ~ /^(read|write|none|true|false|inherit)$/) return line
          return key " <redacted>"
        }
      }
      return line
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

    # YAML and Markdown: a private key block is hidden whole.
    pem { if ($0 ~ /-----END [A-Z ]*PRIVATE KEY-----/) pem = 0; emit("<redacted:private-key-block>"); next }
    /-----BEGIN [A-Z ]*PRIVATE KEY-----/ {
      if ($0 !~ /-----END [A-Z ]*PRIVATE KEY-----/) pem = 1
      emit("<redacted:private-key-block>"); next
    }
    format == "yaml" { emit(yaml_line($0)); next }
    { emit($0) }
  ' < "$SHOW_FILE" | sed -E \
    -e 's/(AKIA|ASIA)[0-9A-Z]{16}/<redacted:aws-access-key-id>/g' \
    -e 's/-----BEGIN ([A-Z]+ )?PRIVATE KEY-----.*/<redacted:private-key-block>/g' \
    -e 's/(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/<redacted:github-token>/g' \
    -e 's/glpat-[A-Za-z0-9_-]{16,}/<redacted:gitlab-token>/g' \
    -e 's/[sr]k_(live|test)_[A-Za-z0-9_]{8,}/<redacted:stripe-secret-key>/g' \
    -e 's/whsec_[A-Za-z0-9_]{8,}/<redacted:stripe-webhook-secret>/g' \
    -e 's/sk-ant-[A-Za-z0-9_-]{16,}/<redacted:anthropic-api-key>/g' \
    -e 's/sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}/<redacted:openai-api-key>/g' \
    -e 's/AIza[0-9A-Za-z_-]{35}/<redacted:google-api-key>/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/xapp-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/sb_secret_[A-Za-z0-9_-]{10,}/<redacted:supabase-secret-key>/g' \
    -e 's/npm_[A-Za-z0-9]{20,}/<redacted:npm-token>/g' \
    -e 's/hf_[A-Za-z0-9]{20,}/<redacted:hugging-face-token>/g' \
    -e 's/SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/<redacted:sendgrid-key>/g' \
    -e 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/<redacted:json-web-token>/g' \
    -e "s#([A-Za-z][A-Za-z0-9+.-]*://)[^[:space:]\"$Q]*@#\1<redacted>@#g" \
    -e "s#(://[^[:space:]\"$Q?]*)\?[^[:space:]\"$Q]*#\1?<redacted>#g" \
    -e "s#(://[^[:space:]\"$Q]*/)[A-Za-z0-9_-]{20,}#\1<redacted>#g" \
    -e "s/((-H|--header)[[:space:]=]+\\\\?[\"$Q]?)[^\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/((-u|--user)[[:space:]=]+)[^[:space:]\"$Q\\\\]+/\1<redacted>/g" \
    -e "s/([[:space:]]-[pa][[:space:]]+)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/([[:space:]]-[pa][[:space:]]+)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/([[:space:]]-p)[[:space:]]?[^[:space:]\"$Q\\\\-][^[:space:]\"$Q\\\\]*/\1 <redacted>/g" \
    -e "s/([[:space:]]-a[[:space:]]+)[^[:space:]\"$Q\\\\-][^[:space:]\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/(--?[Pp][Aa][Tt][=[:space:]]+)[^[:space:]\"$Q\\\\]+/\1<redacted>/g" \
    -e "s#[A-Za-z0-9._-]+:[^[:space:]\"$Q@/<]+@([A-Za-z0-9.-]+)#<redacted>@\1#g" \
    -e "s#(://[^[:space:]\"$Q\#]*)\#[^[:space:]\"$Q]*#\1\#<redacted>#g" \
    -e "s#(^|[\"${Q}[:space:]=:])[A-Za-z0-9/+]{40}([\"${Q}[:space:],]|\$)#\1<redacted>\2#g" \
    -e "s/((Authorization|Proxy-Authorization|Cookie|Set-Cookie|[Xx]-[A-Za-z-]+):[[:space:]]*)[^\"$Q\\\\,]+/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)[^[:space:]\"$Q,;<\$\\\\]+/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)[^[:space:]\"$Q<\$\\\\-][^[:space:]\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/(\"--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*\"[[:space:]]*,[[:space:]]*\")[^\"]*\"/\1<redacted>\"/g" \
    -e 's/(([Bb]earer|[Bb]asic)[[:space:]]+)[A-Za-z0-9._~+\/=-]{8,}/\1<redacted>/g' |
    # A long word that mixes letters and digits is hidden, whatever its place.
    # A name in capitals with underscores is the name of a variable, and it stays.
    # Inside an address the limit is lower: 8 characters for a label of the
    # host, and for a part of the path.
    awk '
      function mixed(w) { return w ~ /[0-9]/ && w ~ /[A-Za-z]/ }
      function flush(    limit) {
        limit = (url > 0) ? 8 : 20
        if (length(run) >= limit && mixed(run) && !(url == 0 && run ~ /^[A-Z0-9_]+$/ && run ~ /_/) && run !~ /^redacted/) out = out "<redacted>"
        else out = out run
        run = ""
      }
      {
        tab = index($0, "\t")
        s = substr($0, tab + 1); out = ""; run = ""; url = 0
        n = length(s)
        for (i = 1; i <= n; i++) {
          ch = substr(s, i, 1)
          # url: 0 outside an address, 1 in its host, 2 in its path.
          if (url == 0 && substr(s, i, 3) == "://") { flush(); out = out "://"; i += 2; url = 1; continue }
          if (url > 0 && ch ~ /[] \t"\047<>(),;[]/) { flush(); url = 0; out = out ch; continue }
          if (url == 1 && ch == "/") { flush(); url = 2; out = out ch; continue }
          if (url == 2 && ch ~ /[A-Za-z0-9_.~%:+=-]/) { run = run ch; continue }
          if (url == 1 && ch ~ /[A-Za-z0-9]/) { run = run ch; continue }
          if (url == 0 && ch ~ /[A-Za-z0-9_+=-]/) { run = run ch; continue }
          flush(); out = out ch
        }
        flush()
        print substr($0, 1, tab) out
      }
    '
}

case "$MODE" in
  list) list ;;
  show) show ;;
esac
