#!/bin/sh
# scan-secrets.sh: say where secrets sit in a repository without printing them.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   sh scan-secrets.sh [path]            scan the working tree
#   sh scan-secrets.sh --history [path]  scan every commit Git still holds
#   sh scan-secrets.sh --show FILE       print FILE with line numbers and secret values masked
#
# Scan output, one line per hit:   <path>:<line>:<type>:<tracked|untracked|ignored|no-git>
# History output, one line per hit: history:<commit>:<path>:<type>
#
# The script reads files and Git objects. It writes nothing, changes nothing,
# and makes no network request. It never prints a matched value: grep output
# is cut down to the path and line number before it is shown.
#
# Patterns match on shape, so test keys and documentation examples are listed
# too. A person or an agent decides which hits matter.

set -u

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

MODE=scan
ROOT=.
SHOW_FILE=

while [ $# -gt 0 ]; do
  case "$1" in
    --history) MODE=history ;;
    --show)
      MODE=show
      shift
      [ $# -gt 0 ] || { echo "scan-secrets: --show needs a file" >&2; exit 2; }
      SHOW_FILE=$1
      ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "scan-secrets: unknown option: $1" >&2; exit 2 ;;
    *) ROOT=$1 ;;
  esac
  shift
done

# <type>|<extended regular expression>. The first "|" ends the type.
PATTERNS='aws-access-key-id|(AKIA|ASIA)[0-9A-Z]{16}
private-key-block|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----
github-token|(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})
stripe-secret-key|[sr]k_live_[A-Za-z0-9_]{8,}
stripe-webhook-secret|whsec_[A-Za-z0-9_]{8,}
anthropic-api-key|sk-ant-[A-Za-z0-9_-]{16,}
openai-api-key|sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}
google-api-key|AIza[0-9A-Za-z_-]{35}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
supabase-secret-key|sb_secret_[A-Za-z0-9_-]{10,}
json-web-token|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}
database-url-with-password|(postgres(ql)?|mysql|mongodb(\+srv)?|redis)://[^:/@[:space:]]+:[^@[:space:]]+@
server-secret-behind-public-prefix|(NEXT_PUBLIC|VITE|EXPO_PUBLIC|REACT_APP|NUXT_PUBLIC|GATSBY|PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE_ROLE|PRIVATE_KEY|PASSWORD|OPENAI|ANTHROPIC|GEMINI|MISTRAL|GROQ|DATABASE_URL|POSTGRES)
possible-secret-assignment|(SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY|PRIVATE_?KEY|ACCESS_?KEY)[A-Za-z0-9_]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9/+_.=-]{16,}["'"'"']'

# Env-style lines are only checked in files named .env or .env.<something>.
ENV_LINE='^[A-Za-z0-9_]*(SECRET|TOKEN|PASSWORD|PASSWD|KEY|DATABASE_URL)[A-Za-z0-9_]*=[^[:space:]$<{]{8,}'

EXCLUDES='--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build --exclude-dir=out --exclude-dir=.next --exclude-dir=.nuxt --exclude-dir=.svelte-kit --exclude-dir=.venv --exclude-dir=venv --exclude-dir=target --exclude-dir=.terraform --exclude-dir=coverage --exclude=package-lock.json --exclude=pnpm-lock.yaml --exclude=yarn.lock --exclude=bun.lock --exclude=*.min.js --exclude=*.map'

is_git() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Says whether Git tracks a path, so a local-only file is not reported as committed.
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

scan() {
  [ -d "$ROOT" ] || { echo "scan-secrets: not a directory: $ROOT" >&2; exit 2; }
  {
    echo "$PATTERNS" | while IFS= read -r entry; do
      type=${entry%%|*}
      regex=${entry#*|}
      # shellcheck disable=SC2086
      (cd "$ROOT" && grep -rnIE $EXCLUDES -e "$regex" . 2>/dev/null) | cut -d: -f1,2 | sed "s/\$/:$type/"
    done
    # shellcheck disable=SC2086
    (cd "$ROOT" && grep -rnIE $EXCLUDES --include='.env' --include='.env.*' -e "$ENV_LINE" . 2>/dev/null) | cut -d: -f1,2 | sed 's/$/:env-file-value/'
    if is_git; then
      git -C "$ROOT" ls-files | grep -E '(^|/)\.env(\.[^/]*)?$' | grep -vE '\.(example|sample|template|dist)$' | sed 's/^/.\//; s/$/:0:committed-env-file/'
    fi
  } | sed 's/^\.\///' | sort -u | while IFS= read -r hit; do
    path=${hit%%:*}
    echo "$hit:$(git_state "$path")"
  done
}

history() {
  is_git || { echo "scan-secrets: not a Git repository: $ROOT" >&2; exit 2; }
  combined=$(echo "$PATTERNS" | sed 's/^[^|]*|//' | paste -sd '|' -)
  git -C "$ROOT" log --all --no-color --format='@%h' --name-only -G"($combined)" 2>/dev/null |
    awk '/^@/ { commit = substr($0, 2); next } NF { print commit "\t" $0 }' |
    while IFS="$(printf '\t')" read -r commit path; do
      echo "$PATTERNS" | while IFS= read -r entry; do
        type=${entry%%|*}
        regex=${entry#*|}
        if git -C "$ROOT" show --no-color --format= "$commit" -- "$path" 2>/dev/null | grep -qE -e "^[+-].*($regex)"; then
          echo "history:$commit:$path:$type"
        fi
      done
    done | sort -u
}

show() {
  [ -f "$SHOW_FILE" ] || { echo "scan-secrets: not a file: $SHOW_FILE" >&2; exit 2; }
  case "$(basename "$SHOW_FILE")" in
    .env | .env.*) env_file=1 ;;
    *) env_file=0 ;;
  esac
  awk '
    /-----BEGIN ([A-Z]+ )?PRIVATE KEY-----/ { print "<redacted:private-key-block>"; inside = 1; next }
    inside && /-----END ([A-Z]+ )?PRIVATE KEY-----/ { print "<redacted:private-key-block>"; inside = 0; next }
    inside { print "<redacted:private-key-block>"; next }
    { print }
  ' "$SHOW_FILE" | sed -E \
    -e 's/(AKIA|ASIA)[0-9A-Z]{16}/<redacted:aws-access-key-id>/g' \
    -e 's/(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/<redacted:github-token>/g' \
    -e 's/[sr]k_live_[A-Za-z0-9_]{8,}/<redacted:stripe-secret-key>/g' \
    -e 's/whsec_[A-Za-z0-9_]{8,}/<redacted:stripe-webhook-secret>/g' \
    -e 's/sk-ant-[A-Za-z0-9_-]{16,}/<redacted:anthropic-api-key>/g' \
    -e 's/sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}/<redacted:openai-api-key>/g' \
    -e 's/AIza[0-9A-Za-z_-]{35}/<redacted:google-api-key>/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/sb_secret_[A-Za-z0-9_-]{10,}/<redacted:supabase-secret-key>/g' \
    -e 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/<redacted:json-web-token>/g' \
    -e 's#((postgres(ql)?|mysql|mongodb(\+srv)?|redis)://[^:/@[:space:]]+:)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's/((SECRET|TOKEN|PASSWORD|PASSWD|API_?KEY|PRIVATE_?KEY|ACCESS_?KEY)[A-Za-z0-9_]*["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'])[A-Za-z0-9\/+_.=-]{16,}(["'"'"'])/\1<redacted>\3/g' |
    if [ "$env_file" = 1 ]; then
      # Flags and environment names stay readable: the check needs them (DEBUG=true, NODE_ENV=production).
      sed -E '/=["'"'"']?(true|false|TRUE|FALSE|True|False|[0-9]+|development|production|staging|test)["'"'"']?[[:space:]]*$/!s/^([[:space:]]*(export[[:space:]]+)?[A-Za-z0-9_]+)=.+$/\1=<redacted>/'
    else
      cat
    fi | awk '{ printf "%6d\t%s\n", NR, $0 }'
}

case "$MODE" in
  scan) scan ;;
  history) history ;;
  show) show ;;
esac
