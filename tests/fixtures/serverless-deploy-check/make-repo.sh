#!/bin/sh
# make-repo.sh: turn the quickship fixture into a Git repository.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh make-repo.sh <new-directory>
#
# A fixture cannot carry its own .git folder inside this repository, so this
# script builds one. The .gitignore lists .env.local and .dev.vars, so those
# two files exist on disk and stay out of Git.

set -eu

[ $# -eq 1 ] || { echo "usage: sh make-repo.sh <new-directory>" >&2; exit 2; }
target=$1
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target"
cp -R "$here/quickship/." "$target/"

cd "$target"
printf 'node_modules\n.next\n.env.local\n.dev.vars\n' > .gitignore
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git add -A
git commit -q -m "Initial commit"

echo "Fixture repository ready at $target"
