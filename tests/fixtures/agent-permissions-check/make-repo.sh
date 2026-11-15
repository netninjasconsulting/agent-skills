#!/bin/sh
# make-repo.sh: turn the loose-agents fixture into a Git repository with a stand-in home folder.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh make-repo.sh <new-directory>
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

[ $# -eq 1 ] || { echo "usage: sh make-repo.sh <new-directory>" >&2; exit 2; }
target=$1
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target/repo" "$target/home"
cp -R "$here/loose-agents/." "$target/repo/"
cp -R "$here/home/." "$target/home/"

cd "$target/repo"
printf '.env\n.claude/settings.local.json\nnode_modules\n' > .gitignore
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git add -A
git commit -q -m "Initial commit"

echo "Fixture repository ready at $target/repo, with a stand-in home folder at $target/home"
