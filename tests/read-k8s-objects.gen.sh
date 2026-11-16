#!/bin/sh
# read-k8s-objects.gen.sh: compare what the Kubernetes object reader accepts
# with what Kubernetes decodes, by generation.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/read-k8s-objects.gen.sh READER [MAXLEN]
#
# Writes every string of 1 to MAXLEN characters (3 by default) over
#   a 1 - = . / : ? , " ' and the space
# two ways: as the items of a flow list, "add: [<string>]", and as a whole
# value, "serviceAccountName: <string>". For each one it asks the reader
# and kubectl ("kubectl annotate --local -f FILE zz=1 -o json", which needs
# no cluster and decodes YAML the way Kubernetes does), and fails when:
#   - the reader accepts a flow list that kubectl decodes with a map or a
#     list as an item, with another number of items, or as no list at all;
#   - the reader reads a whole value that kubectl decodes as a map or a
#     list, or calls a value empty that kubectl decodes as a value.
# A document the reader accepts and kubectl refuses is counted, not failed:
# Kubernetes never applies it.
#
# The reader makes a whole file unread on one bad item, so the script asks
# it about every string in one run through the inline Helm values of Argo CD
# Applications, where a layout the reader cannot place drops the values of
# that one Application. It then reads the accepted strings again in plain
# Pod documents, and a sample of the refused ones one file at a time.
#
# Prints the counts. Exit codes: 0 no difference (or kubectl is not
# installed: it prints "skipped"), 1 a difference, 2 wrong usage.

set -u
LC_ALL=C
export LC_ALL

[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: sh read-k8s-objects.gen.sh READER [MAXLEN]" >&2; exit 2; }
reader=$1
max=${2:-3}
case "$max" in [1-5]) ;; *) echo "MAXLEN is 1 to 5" >&2; exit 2 ;; esac
[ -f "$reader" ] || { echo "not a file: $reader" >&2; exit 2; }
case "$reader" in /*) ;; *) reader="$(pwd)/$reader" ;; esac

if ! command -v kubectl >/dev/null 2>&1; then
  echo "skipped: the generation against kubectl (kubectl is not installed)"
  exit 0
fi

g=$(mktemp -d)
trap 'rm -rf "$g"' EXIT
NET=
if unshare -n true 2>/dev/null; then
  NET="unshare -n"
elif unshare -rn true 2>/dev/null; then
  NET="unshare -rn"
fi
bad=0
problem() {
  echo "generation: $1"
  bad=1
}

# Every string, one on each line. The line number is its id.
awk -v max="$max" 'BEGIN {
  n = split("a 1 - = . / : ? , \" \047", A, " "); A[++n] = " "
  cur[0] = ""; nc = 1
  for (len = 1; len <= max; len++) {
    nn = 0
    for (i = 0; i < nc; i++) for (j = 1; j <= n; j++) { s = cur[i] A[j]; nxt[nn++] = s; print s }
    for (i = 0; i < nn; i++) cur[i] = nxt[i]
    nc = nn
  }
}' > "$g/strings"
total=$(awk 'END { print NR }' "$g/strings")

# rd FILE: the reader on one file of $g, standard output in $g/out.
rd() {
  # shellcheck disable=SC2086 # NET is a command and its option, or empty
  (cd "$g" && $NET sh "$reader" --fields "$1" > out 2>/dev/null)
}

# The ask in one run. $1 = flow or value.
sieve() {
  awk -v form="$1" '{
    if (NR > 1) print "---"
    print "apiVersion: argoproj.io/v1alpha1"
    print "kind: Application"
    print "metadata:"
    print "  name: p" NR
    print "  namespace: argocd"
    print "spec:"
    print "  project: default"
    print "  source:"
    print "    repoURL: https://git.example.com/generation.git"
    print "    path: apps"
    print "    helm:"
    print "      values: |"
    if (form == "flow") {
      print "        securityContext:"
      print "          capabilities:"
      print "            add: [" $0 "]"
    } else print "        probe: " $0
    print "  destination:"
    print "    namespace: apps"
  }' "$g/strings" > "$g/sieve.yaml"
  rd sieve.yaml || { problem "the reader did not read the $1 sieve"; return 1; }
  # One line for each string the reader accepted: id, then the number of
  # items it read (flow) or the state word it gave (value).
  awk -F: -v form="$1" '
    { split($3, o, "/"); id = substr(o[3], 2); f = $5; sub(/=.*/, "", f); v = $5; sub(/^[^=]*=/, "", v) }
    f == "source.1.helm-values" && v == "present" { ok[id] = 1; if (id + 0 > top) top = id + 0 }
    form == "flow" && f == "values.securityContext.capabilities.add" { n[id]++ }
    form == "value" && f == "values-key.probe" { st[id] = v }
    END { for (id = 1; id <= top; id++) if (id in ok) print id, (form == "flow") ? n[id] + 0 : st[id] }
  ' "$g/out" > "$g/accepted.$1"
}

# The accepted strings as Pod documents: one file with them all for the
# reader, and one file each for kubectl, which stops a file at a document
# it cannot decode and goes on with the next file.
pods() {
  rm -rf "$g/k"
  mkdir "$g/k"
  awk -v form="$1" -v dir="$g/k" -v all="$g/pods.yaml" '
    NR == FNR { ok[$1] = 1; next }
    FNR in ok {
      d = "apiVersion: v1\nkind: Pod\nmetadata:\n  name: p" FNR "\nspec:\n"
      if (form == "flow") d = d "  containers:\n    - name: app\n      securityContext:\n        capabilities:\n          add: [" $0 "]\n"
      else d = d "  serviceAccountName: " $0 "\n"
      printf "%s%s", (n++ ? "---\n" : ""), d > all
      f = dir "/p" FNR ".yaml"
      printf "%s", d > f
      close(f)
    }
  ' "$g/accepted.$1" "$g/strings"
}

# What kubectl decoded, from its indented JSON: one line for each document,
# its id, then for a flow list "list" and one letter for each item (s a
# string, t a number, a boolean, or null, M a map, L a list), and for
# anything else its kind (string, typed, null, map, list).
decoded() {
  # shellcheck disable=SC2086 # NET is a command and its option, or empty
  $NET kubectl annotate --local -f "$g/k" zz=1 -o json 2>/dev/null | awk -v key="$1" '
    function kind(t) {
      if (t ~ /^"/) return "string"
      if (t ~ /^\{/) return "map"
      if (t ~ /^\[/) return "list"
      if (t ~ /^null/) return "null"
      return "typed"
    }
    /^\{$/ { id = ""; got = 0; next }
    /^        "name": "p[0-9]+",?$/ { id = $2; gsub(/[^0-9]/, "", id); next }
    /^\}$/ { if (id != "") print id, got ? res : "null"; next }
    inlist {
      match($0, /^ */)
      if (RLENGTH == ind) { inlist = 0; next }
      if (RLENGTH == ind + 4) {
        t = substr($0, RLENGTH + 1)
        if (t ~ /^[\]}]/) next
        k = kind(t)
        res = res (k == "string" ? "s" : k == "map" ? "M" : k == "list" ? "L" : "t")
      }
      next
    }
    {
      match($0, /^ */); ind = RLENGTH
      t = substr($0, ind + 1)
      if (index(t, "\"" key "\": ") != 1) next
      t = substr(t, length(key) + 5)
      got = 1
      if (t ~ /^\[$/) { res = "list "; inlist = 1 }
      else if (t ~ /^\[\],?$/) res = "list "
      else res = kind(t)
    }
  ' > "$g/decoded"
}

# ---- Flow-list items ----

flow_kube=0; flow_typed=0; flow_acc=0; flow_ref=0; flow_sample=0
if sieve flow; then
  flow_acc=$(awk 'END { print NR }' "$g/accepted.flow")
  flow_ref=$((total - flow_acc))
  pods flow
  if [ "$flow_acc" -gt 0 ]; then
    if rd pods.yaml; then
      awk -F: '{ split($3, o, "/"); id = substr(o[3], 2) }
        $5 ~ /^object=/ { seen[id] = 1; if (id + 0 > top) top = id + 0 }
        $5 ~ /^cap-add=/ { n[id]++ }
        END { for (id = 1; id <= top; id++) if (id in seen) print id, n[id] + 0 }' "$g/out" > "$g/direct"
      cmp -s "$g/direct" "$g/accepted.flow" || problem "the reader reads a flow list in a Pod and in Helm values with different item counts"
    else
      problem "the reader accepts a flow list in Helm values that it does not read in a Pod"
    fi
  fi
  # A sample of the refused strings, each in a file of its own.
  step=$((flow_ref / 16 + 1))
  awk -v step="$step" 'NR == FNR { ok[$1] = 1; next } !(FNR in ok) && (r++ % step) == 0 { print }' "$g/accepted.flow" "$g/strings" > "$g/sample"
  while IFS= read -r s; do
    printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: sample\nspec:\n  containers:\n    - name: app\n      securityContext:\n        capabilities:\n          add: [%s]\n' "$s" > "$g/one.yaml"
    rd one.yaml
    [ $? -eq 4 ] || problem "the reader refuses [$s] in Helm values and reads it in a Pod"
    flow_sample=$((flow_sample + 1))
  done < "$g/sample"
  decoded add
  awk -v strings="$g/strings" '
    BEGIN { while ((getline line < strings) > 0) S[++ns] = line }
    NR == FNR { n[$1] = $2; next }
    { k[$1] = 1 }
    $2 != "list" { print "generation: kubectl decodes no list where the reader read a flow list: [" S[$1] "]"; next }
    $3 ~ /[ML]/ { print "generation: kubectl decodes a map or a list where the reader read a plain item: [" S[$1] "]"; next }
    length($3) != n[$1] { print "generation: kubectl decodes " length($3) " items where the reader read " n[$1] ": [" S[$1] "]"; next }
    $3 ~ /t/ { typed++ }
    END { for (id in n) if (!(id in k)) kube++; print "counts", kube + 0, typed + 0 }
  ' "$g/accepted.flow" "$g/decoded" > "$g/verdict"
  if grep -q '^generation: ' "$g/verdict"; then
    grep '^generation: ' "$g/verdict" | sed -n 1,20p
    bad=1
  fi
  flow_kube=$(awk '$1 == "counts" { print $2 }' "$g/verdict")
  flow_typed=$(awk '$1 == "counts" { print $3 }' "$g/verdict")
fi
echo "generation: $total flow lists of 1 to $max characters: the reader accepted $flow_acc and refused $flow_ref ($flow_sample of the refused read again alone); of the accepted, kubectl refused $flow_kube and typed an item as a number, a boolean, or null in $flow_typed"

# ---- Whole values ----

val_kube=0; val_typed=0; val_acc=0
if sieve value; then
  val_acc=$(awk 'END { print NR }' "$g/accepted.value")
  pods value
  if [ "$val_acc" -gt 0 ]; then
    if rd pods.yaml; then
      [ "$(grep -c ':object=present$' "$g/out")" -eq "$val_acc" ] || problem "the reader does not read every Pod of the whole values"
    else
      problem "the reader reads a value in Helm values that it does not read in a Pod"
    fi
  fi
  decoded serviceAccountName
  awk -v strings="$g/strings" '
    BEGIN { while ((getline line < strings) > 0) S[++ns] = line }
    NR == FNR { st[$1] = $2; next }
    { k[$1] = 1 }
    $2 == "map" || $2 == "list" { print "generation: kubectl decodes a map or a list where the reader read a value: " S[$1]; next }
    st[$1] == "empty" && $2 != "null" && S[$1] !~ /^ *(""|\047\047) *$/ { print "generation: kubectl decodes a value where the reader read an empty one: " S[$1]; next }
    $2 == "typed" || $2 == "null" { typed++ }
    END { for (id in st) if (!(id in k)) kube++; print "counts", kube + 0, typed + 0 }
  ' "$g/accepted.value" "$g/decoded" > "$g/verdict"
  if grep -q '^generation: ' "$g/verdict"; then
    grep '^generation: ' "$g/verdict" | sed -n 1,20p
    bad=1
  fi
  val_kube=$(awk '$1 == "counts" { print $2 }' "$g/verdict")
  val_typed=$(awk '$1 == "counts" { print $3 }' "$g/verdict")
fi
echo "generation: $total whole values of 1 to $max characters: the reader read $val_acc and refused $((total - val_acc)); of those read, kubectl refused $val_kube and typed $val_typed as a number, a boolean, or null"

exit "$bad"
