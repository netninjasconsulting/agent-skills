#!/bin/sh
# make-repo.sh: turn the loose-agents fixture into a Git repository with a stand-in home folder.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
# Changed from the Net Ninjas original during independent review, 15 November 2026.
#
# Usage: sh make-repo.sh <new-directory> [open-rows]
#
# With "open-rows", the files in open-rows/ replace their namesakes before the
# commit. That variant runs the agent on a self-hosted runner and gives it
# production cloud keys, so rows 3 and 4 are "open". Row 6 is "not checked":
# the runner label alone cannot establish its lifetime or network isolation.
#
# A fixture cannot carry its own .git folder inside this repository, so this
# script builds one. It creates two folders:
#
#   <new-directory>/repo   the repository under test, committed
#   <new-directory>/home   a stand-in home folder with user-level agent settings
#
# In the new repository, .env and .claude/settings.local.json are present and
# ignored by Git, as they would be on a developer's machine.

set -eu

[ $# -eq 1 ] || [ $# -eq 2 ] || { echo "usage: sh make-repo.sh <new-directory> [open-rows]" >&2; exit 2; }
target=$1
variant=${2:-}
[ -z "$variant" ] || [ "$variant" = "open-rows" ] || { echo "make-repo: unknown variant: $variant" >&2; exit 2; }
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target/repo" "$target/home"
cp -R "$here/loose-agents/." "$target/repo/"
cp -R "$here/home/." "$target/home/"
[ -z "$variant" ] || cp -R "$here/$variant/." "$target/repo/"

cd "$target/repo"
printf '.env\n.claude/settings.local.json\nnode_modules\n' > .gitignore
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git add -A
git commit -q -m "Initial commit"

echo "Fixture repository ready at $target/repo, with a stand-in home folder at $target/home"
