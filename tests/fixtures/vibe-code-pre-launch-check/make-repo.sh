#!/bin/sh
# make-repo.sh: turn the vibe-shop fixture into a Git repository with history.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh make-repo.sh <new-directory>
#
# A fixture cannot carry its own .git folder inside this repository, so this
# script builds one. The first commit holds a fake private key file. The
# second commit deletes it. The key is gone from the working tree and still
# in the history, which is the case the history scan has to catch.

set -eu

[ $# -eq 1 ] || { echo "usage: sh make-repo.sh <new-directory>" >&2; exit 2; }
target=$1
[ ! -e "$target" ] || { echo "make-repo: $target already exists" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$target"
cp -R "$here/vibe-shop/." "$target/"

cd "$target"
git init -q -b main
git config user.name "Fixture"
git config user.email "fixture@example.com"

mkdir -p config
cat > config/deploy-key.pem <<'KEY'
-----BEGIN RSA PRIVATE KEY-----
FIXTURE-NOT-A-REAL-KEY-FIXTURE-NOT-A-REAL-KEY-FIXTURE-NOT-A-REAL-KEY
FIXTURE-NOT-A-REAL-KEY-FIXTURE-NOT-A-REAL-KEY-FIXTURE-NOT-A-REAL-KEY
-----END RSA PRIVATE KEY-----
KEY

git add -A
git commit -q -m "Initial commit"
git rm -q config/deploy-key.pem
git commit -q -m "Remove deploy key"

echo "Fixture repository ready at $target"
