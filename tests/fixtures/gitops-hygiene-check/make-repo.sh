#!/bin/sh
# make-repo.sh: turn the loose-pipeline fixture into a Git repository.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh make-repo.sh <new-directory>
#
# The skill reads the default branch and the origin URL from Git, so the
# fixture needs both. The origin points at a repository that does not exist,
# and the script never contacts it.

set -eu

[ $# -eq 1 ] || { echo "usage: sh make-repo.sh <new-directory>" >&2; exit 2; }
target=$1
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target"
cp -R "$here/loose-pipeline/." "$target/"

cd "$target"
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git remote add origin https://github.com/example-org/loose-pipeline.git
git add -A
git commit -q -m "Initial commit"

echo "Fixture repository ready at $target"
