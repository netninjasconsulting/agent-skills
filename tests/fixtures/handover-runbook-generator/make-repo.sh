#!/bin/sh
# make-repo.sh: turn the parcel-api fixture into a Git repository.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh make-repo.sh <new-directory>
#
# The runbook names the commit it was generated from, so the fixture needs one.

set -eu

[ $# -eq 1 ] || { echo "usage: sh make-repo.sh <new-directory>" >&2; exit 2; }
target=$1
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target"
cp -R "$here/parcel-api/." "$target/"

cd "$target"
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"
git add -A
git commit -q -m "Initial commit"

echo "Fixture repository ready at $target"
