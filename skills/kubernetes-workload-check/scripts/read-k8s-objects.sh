#!/bin/sh
# read-k8s-objects.sh: list the Kubernetes objects, charts, overlays, and values
# files of a repository, and print named fields of them. It never prints a line
# of a file.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   sh read-k8s-objects.sh [path]                    list manifests, charts, overlays, and values files
#   sh read-k8s-objects.sh --fields FILE             print the field table of each object in FILE
#   sh read-k8s-objects.sh --values FILE             print the key names of a values file, and the
#                                                    sizing and security values that pass a shape
#   sh read-k8s-objects.sh --render helm CHART VALUES [VALUES] [--namespace NAME]
#                                                    print the field table of the rendered chart
#   sh read-k8s-objects.sh --render kustomize DIR    print the field table of the built overlay
#
# List line:  <path>:<kind>:<state>
#   kind:  manifest | chart | chart-values | overlay | kustomize-base | argo-application | link
#   state: tracked | untracked | ignored | no-git, or a refusal state of --render.
#          A link line has the state "points outside the repository, not read"
#          or "broken, not read".
# Field line: <file>:<line>:<object kind>/<namespace>/<name>:<container or ->:<field>=<value>
#
# Exit codes: 0 success, 2 wrong usage, 3 render refused, failed, or with
# no object, 4 a file that is not read or a path that is not listed.
#
# Nothing prints by default. A field prints only when references/fields.md
# names it for its object kind and place, and its value fits the shape that
# file gives. The reader works by line and does not parse. A layout it cannot
# place with certainty (an anchor, an alias, a merge key, a tag, a flow
# collection over several lines, a quoted value over several lines, a tab in
# the indent, a key at an indent no sibling uses, a key twice in one map, an
# unrendered template line) means the whole file is not read: it prints
# nothing and exits 4.
#
# A symbolic link that stays inside the repository (for the list, --fields,
# and --values, the directory the reader runs in; for a render, the top of
# its Git repository; each resolved with its own links) is followed like
# what it points to, and the list prints every path that reaches a file. A link that points outside
# it, or that does not resolve, is not read: the list prints a link line
# for it, --fields and --values exit 4, and a render is refused.
#
# The reader reads files and Git objects and writes nothing. --render runs
# helm template or kustomize build (or kubectl kustomize) itself, after the
# refusal tests of fields.md, with a cleared environment and the fixed
# arguments of fields.md, drops what the tool writes to standard error, and
# pipes its standard output into the same extractor.

set -u
LC_ALL=C
export LC_ALL

me=read-k8s-objects
REMOTES=
NL='
'
TAB=$(printf '\t')

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

die2() { echo "$me: $1" >&2; exit 2; }

# The shape block of references/fields.md, one shape on each line: id,
# maximum length, pattern. It reaches awk through the environment, so that
# no copy of awk rewrites a backslash in it.
SHAPES='
bool 5 ^(true|false)$
int 10 ^[0-9]+$
port 5 ^[1-9][0-9]?[0-9]?[0-9]?[0-9]?$
qty-cpu 12 ^([0-9]+|[0-9]+\.[0-9]+|[0-9]+m)$
qty-mem 16 ^[0-9]+(\.[0-9]+)?(E|P|T|G|M|k|Ei|Pi|Ti|Gi|Mi|Ki|m)?$
dns-label 63 ^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$
dns-subdomain 253 ^([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])$
short-name 63 ^([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])$
api-version 64 ^(([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])/)?v[0-9]+((alpha|beta)[0-9]+)?$
kind-name 63 ^[A-Z][A-Za-z0-9]*$
env-name 64 ^[A-Za-z_][A-Za-z0-9_]*$
key-name 64 ^[A-Za-z0-9._-]+$
label-value 63 ^([A-Za-z0-9]|[A-Za-z0-9][-A-Za-z0-9_.]*[A-Za-z0-9])$
image-tag 64 ^[A-Za-z0-9_][A-Za-z0-9._-]*$
pull-policy 12 ^(Always|IfNotPresent|Never)$
cap-name 32 ^[A-Z][A-Z0-9_]*$
rbac-verb 16 ^(get|list|watch|create|update|patch|delete|deletecollection|escalate|bind|impersonate|\*)$
rbac-resource 63 ^(\*|[a-z][a-z0-9-]*)(/(\*|[a-z][a-z0-9-]*))?$
rbac-group 63 ^(core|\*|([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9]))$
role-name 253 ^([a-z0-9]|[a-z0-9][-a-z0-9.:]*[a-z0-9])$
subject-kind 14 ^(User|Group|ServiceAccount)$
role-ref-kind 12 ^(Role|ClusterRole)$
cidr-v4 18 ^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.)((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.)((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.)(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])/(3[0-2]|[12]?[0-9])$
cidr-v6 43 ^[0-9a-fA-F:]*:[0-9a-fA-F:]*/(12[0-8]|1[01][0-9]|[1-9]?[0-9])$
psa-level 10 ^(privileged|baseline|restricted)$
psa-version 8 ^(latest|v[0-9]+\.[0-9]+)$
secret-type 40 ^(Opaque|kubernetes\.io/(service-account-token|dockercfg|dockerconfigjson|basic-auth|ssh-auth|tls)|bootstrap\.kubernetes\.io/token)$
update-mode 17 ^(Off|Initial|Recreate|Auto|InPlaceOrRecreate|InPlace)$
concurrency-policy 7 ^(Allow|Forbid|Replace)$
metric-type 18 ^(ContainerResource|External|Object|Pods|Resource)$
metric-resource 6 ^(cpu|memory)$
metric-target-type 13 ^(Utilization|Value|AverageValue)$
limit-type 21 ^(Container|Pod|PersistentVolumeClaim)$
protocol 4 ^(TCP|UDP|SCTP)$
env-source 17 ^(literal|literal-empty|secretKeyRef|configMapKeyRef|fieldRef|resourceFieldRef|fileKeyRef)$
scale-down 13 ^(never|onsuccess|progressively)$
volume-type 14 ^(hostPath|emptyDir|secret|configMap|projected|downwardAPI)$
container-kind 4 ^(main|init)$
rel-path 128 ^[$]?[A-Za-z0-9._/-]+$
host-path 128 ^/[A-Za-z0-9._/-]*$
element-key 32 ^[A-Za-z][A-Za-z0-9_-]*$
values-path 200 ^[A-Za-z_][A-Za-z0-9_-]*(\.[A-Za-z_][A-Za-z0-9_-]*)*$
image-ref 255 ^(([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])(:[0-9]+)?/)?[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*(:[A-Za-z0-9_][A-Za-z0-9._-]*)?(@sha256:[a-f0-9]+)?$
image-digest 71 ^sha256:[a-f0-9]+$
image-registry 260 ^(default|([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])(:[0-9]+)?)$
image-repository 255 ^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*$
medium 6 ^Memory$
policy-type 7 ^(Ingress|Egress)$
'

# The extractor. Modes: fields (and render, the same for a rendered stream),
# values, and leaves (the reader's own use: the paths a kustomization or a
# Chart.yaml names, never printed by the reader).
#
# Pass 1, by line: track the indent of block-style YAML, the document, and
# the path of each key and list item, and keep each one as a leaf: its path
# (keys joined by ">", the n-th list item written "#n"), its line, and its
# cleaned value. Pass 2, at the end of each document: name the fields of the
# object from the leaves, each through field(), which prints nothing that is
# not on the field list or does not fit its shape.
# shellcheck disable=SC2016 # awk code, not shell
EXTRACT='
function reset(I,    k) {
  for (k = 1; k <= NL[I]; k++) delete LIDX[I, LPATH[I, k]]
  NL[I] = 0; D[I] = 0; Col[I, 0] = -1; CC[I, 0] = -1; PT[I, 0] = ""; NI[I, 0] = 0
  Open[I, 0] = 1; SPATH[I, 0] = ""; BS[I] = 0; BSN[I] = 0
}

function leaf(I, p) { return ((I, p) in LIDX) ? LIDX[I, p] : 0 }
function leaf0(p) { return leaf(0, p) }

# Clean the text after a colon or a dash: sets CV (the text), CQ (quoted),
# and CT: none, scalar, flow, block, template, bad, or err (the layout is
# not one the reader can place).
function cleanv(t,    q, i, n, c, qend) {
  CV = ""; CQ = 0
  sub(/[ \t]+$/, "", t)
  if (t == "") { CT = "none"; return }
  q = substr(t, 1, 1)
  if (q == "\"" || q == "\047") {
    n = length(t); qend = 0
    for (i = 2; i <= n; i++) {
      c = substr(t, i, 1)
      if (q == "\"" && c == "\\") { i++; continue }
      if (c == q) {
        if (q == "\047" && substr(t, i + 1, 1) == "\047") { i++; continue }
        qend = i; break
      }
    }
    if (!qend) { CT = "err"; return }
    CV = substr(t, 2, qend - 2); CQ = 1
    CT = (qend == n) ? "scalar" : "bad"
    return
  }
  if (q == "#") { CT = "none"; return }
  if (match(t, /[ \t]#/)) t = substr(t, 1, RSTART - 1)
  sub(/[ \t]+$/, "", t)
  CV = t
  if (t == "") { CT = "none"; return }
  q = substr(t, 1, 1)
  if (substr(t, 1, 2) == "{{") { CT = "template"; return }
  if (q == "{" || q == "[") { CT = balanced(t) ? "flow" : "err"; return }
  if (q == "|" || q == ">") { CT = (t ~ /^[|>][-+]?$/) ? "block" : "err"; return }
  if (q == "&" || q == "*" || q == "!") { CT = "err"; return }
  if (q == "%" || q == "@" || q == "`") { CT = "bad"; return }
  if (q == "?" && (length(t) == 1 || substr(t, 2, 1) == " ")) { CT = "bad"; return }
  if (index(t, ": ") || substr(t, length(t), 1) == ":" || index(t, "\t")) { CT = "bad"; return }
  CT = "scalar"
}

# A flow collection that opens and closes on its line, and nothing after it.
function balanced(t,    i, n, c, d, q) {
  n = length(t); d = 0; q = ""
  for (i = 1; i <= n; i++) {
    c = substr(t, i, 1)
    if (q != "") {
      if (q == "\"" && c == "\\") { i++; continue }
      if (c == q) q = ""
      continue
    }
    if (c == "\"" || c == "\047") { q = c; continue }
    if (c == "{" || c == "[") d++
    else if (c == "}" || c == "]") {
      d--
      if (d < 0) return 0
      if (d == 0 && i != n) return 0
    }
  }
  return d == 0 && q == ""
}

# The allow shape of a flow-list item: an unquoted token of letters,
# digits, and _ . / @ + = - that starts with a letter, a digit, ".", or
# "/", or with a "-" that has at least one more character after it, or one
# single-quoted or double-quoted string with no quote, backslash, or
# control character inside, with nothing but spaces around it. No such item
# is a map or a list to Kubernetes, and no such list has another number of
# items there. The patterns are strings, not /.../, so that no awk takes a
# backslash for a member of a bracket.
function allowed(t,    q, inner) {
  if (t ~ "^[A-Za-z0-9./][A-Za-z0-9_./@+=-]*$") return 1  # an equals sign does not start an item
  if (t ~ "^-[A-Za-z0-9_./@+=-]+$") return 1  # a dash alone is not an item
  q = substr(t, 1, 1)
  if (length(t) < 2 || (q != "\"" && q != "\047") || substr(t, length(t), 1) != q) return 0
  inner = substr(t, 2, length(t) - 2)
  if (index(inner, "\"") || index(inner, "\047") || index(inner, "\\")) return 0
  return inner !~ /[\001-\037\177]/
}

# The items of a one-line flow list, each cleaned on its own: FIV, FIQ, FIT.
# An item outside the allow shape gives the type flow, never read.
function flowitems(t,    inner, n, i, c, q, d, cur, ok) {
  NFI = 0
  if (substr(t, 1, 1) != "[") return 0
  inner = substr(t, 2, length(t) - 2)
  if (inner ~ /^ *$/) return 0
  q = ""; d = 0; cur = ""
  n = length(inner)
  for (i = 1; i <= n + 1; i++) {
    c = (i <= n) ? substr(inner, i, 1) : ","
    if (q != "") {
      if (q == "\"" && c == "\\") { cur = cur c substr(inner, i + 1, 1); i++; continue }
      if (c == q) q = ""
      cur = cur c; continue
    }
    if (c == "\"" || c == "\047") { q = c; cur = cur c; continue }
    if (c == "{" || c == "[") d++
    if (c == "}" || c == "]") d--
    if (c == "," && d == 0) {
      sub(/^ +/, "", cur); sub(/ +$/, "", cur)
      ok = allowed(cur)  # the allow shape of a flow item
      cleanv(cur)
      NFI++; FIV[NFI] = CV; FIQ[NFI] = CQ; FIT[NFI] = ok ? CT : "flow"
      cur = ""; continue
    }
    cur = cur c
  }
  return NFI
}

# A flow map that is not empty, or a flow list with an item outside the
# allow shape: what it holds is not read, so the file is not read.
function flowmap(t, v,    n, i, sv, sq, st, r) {
  if (t != "flow" || v == "{}" || v == "[]") return 0
  if (substr(v, 1, 1) == "{") return 1
  sv = CV; sq = CQ; st = CT; r = 0
  n = flowitems(v)
  for (i = 1; i <= n; i++) if (FIT[i] != "scalar") r = 1  # a flow item that is not a plain scalar
  CV = sv; CQ = sq; CT = st
  return r
}

# A key at the start of s: sets KEY and KVAL.
function keyline(s,    q, k, rest, i) {
  q = substr(s, 1, 1)
  if (q == "\"" || q == "\047") {
    i = index(substr(s, 2), q)
    if (!i) return 0
    k = substr(s, 2, i - 1); rest = substr(s, i + 2)
    if (k !~ "^[A-Za-z0-9_$./+-]+$") return 0
  } else {
    if (!match(s, "^[A-Za-z0-9_$.][A-Za-z0-9_$./+-]*")) return 0
    k = substr(s, 1, RLENGTH); rest = substr(s, RLENGTH + 1)
  }
  if (rest != ":" && substr(rest, 1, 2) != ": ") return 0
  KEY = k; KVAL = substr(rest, 2); sub(/^ +/, "", KVAL)
  return 1
}

function push(I, col, key, isitem, ln, vt,    d, seg, p, k, pk) {
  d = D[I]
  if (!Open[I, d]) { ERR[I] = 1; return 0 }
  if (CC[I, d] < 0) CC[I, d] = col
  else if (CC[I, d] != col) { ERR[I] = 1; return 0 }
  if (isitem) {
    if (PT[I, d] == "map") { ERR[I] = 1; return 0 }
    PT[I, d] = "seq"; NI[I, d]++; seg = "#" NI[I, d]
  } else {
    if (PT[I, d] == "seq") { ERR[I] = 1; return 0 }
    PT[I, d] = "map"; seg = key
  }
  p = (d == 0) ? seg : SPATH[I, d] ">" seg
  if ((I, p) in LIDX) { ERR[I] = 1; return 0 }
  cleanv(vt)
  if (CT == "err") { ERR[I] = 1; return 0 }
  if (flowmap(CT, CV)) { ERR[I] = 1; return 0 }  # a flow collection that holds a map
  d++; D[I] = d
  Col[I, d] = col; CC[I, d] = -1; PT[I, d] = ""; NI[I, d] = 0; SPATH[I, d] = p
  IsItem[I, d] = isitem; Open[I, d] = (CT == "none")
  k = ++NL[I]
  LPATH[I, k] = p; LVAL[I, k] = CV; LQ[I, k] = CQ; LT[I, k] = CT; LLN[I, k] = ln; LKIDS[I, k] = 0
  LIDX[I, p] = k
  if (d > 1) { pk = SLEAF[I, d - 1]; LKIDS[I, pk]++; LCH[I, pk, LKIDS[I, pk]] = k }
  SLEAF[I, d] = k
  if (CT == "block") {
    BS[I] = 1; BSP[I] = col; BSC[I] = -1; BSK[I] = k
    BSN[I] = (I == 0 && mode != "values" && p ~ /^spec>(template>spec>)?(source|sources>#[0-9]+)>helm>values$/)
    if (BSN[I]) reset(1)
  }
  return 1
}

function block_end(I) {
  BS[I] = 0
  if (I == 0 && BSN[0]) {
    BSN[0] = 0
    if (BS[1]) block_end(1)
    if (ERR[1]) NESTFAIL[BSK[0]] = 1
    else if (NL[1] > 0) nested_values(BSK[0])
    ERR[1] = 0; reset(1)
  }
}

function pline(I, raw, ln,    line, n, c, rest, sp) {
  if (ERR[I]) return
  line = raw
  if (substr(line, length(line), 1) == "\r") line = substr(line, 1, length(line) - 1)
  if (index(line, "\r")) { ERR[I] = 1; return }
  if (line ~ /[\001-\010\013\014\016-\037\177]/) { ERR[I] = 1; return }
  if (index(line, "\302\205") || index(line, "\342\200\250") || index(line, "\342\200\251")) { ERR[I] = 1; return }  # a line break YAML takes from Unicode
  if (BS[I]) {
    if (line ~ /^ *$/) return
    match(line, /^ */); n = RLENGTH
    if (n > BSP[I] && (BSC[I] < 0 || n >= BSC[I])) {
      if (BSC[I] < 0) BSC[I] = n
      if (BSN[I]) pline(1, substr(line, BSC[I] + 1), ln)
      return
    }
    block_end(I)
  }
  if (line ~ /^ *$/) return
  match(line, /^ */); n = RLENGTH; c = substr(line, n + 1)
  if (substr(c, 1, 1) == "\t") { ERR[I] = 1; return }
  if (substr(c, 1, 1) == "#") return
  if (n == 0 && (c ~ /^---( +#.*)? *$/ || c ~ /^\.\.\.( +#.*)? *$/)) {
    if (I == 0) doc_end(); else ERR[I] = 1
    return
  }
  if (n == 0 && (substr(c, 1, 3) == "---" || substr(c, 1, 3) == "..." || substr(c, 1, 1) == "%")) { ERR[I] = 1; return }
  if (substr(c, 1, 2) == "{{" || substr(c, 1, 2) == "{%") { ERR[I] = 1; return }
  if (c == "-" || substr(c, 1, 2) == "- ") {
    rest = substr(c, 2); match(rest, /^ */); sp = RLENGTH; rest = substr(rest, sp + 1)
    while (D[I] > 0 && Col[I, D[I]] > n) D[I]--
    if (D[I] > 0 && Col[I, D[I]] == n && IsItem[I, D[I]]) D[I]--
    if (rest == "" || substr(rest, 1, 1) == "#") { push(I, n, "", 1, ln, ""); return }
    if (rest == "-" || substr(rest, 1, 2) == "- " || substr(rest, 1, 1) == "?") { ERR[I] = 1; return }
    if (keyline(rest)) {
      if (!push(I, n, "", 1, ln, "")) return
      push(I, n + 1 + sp, KEY, 0, ln, KVAL)
      return
    }
    push(I, n, "", 1, ln, rest)
    return
  }
  if (keyline(c)) {
    while (D[I] > 0 && Col[I, D[I]] >= n) D[I]--
    push(I, n, KEY, 0, ln, KVAL)
    return
  }
  ERR[I] = 1
}

function doc_end() {
  if (BS[0]) block_end(0)
  if (!ERR[0] && NL[0] > 0) {
    if (mode == "values") values_doc()
    else if (mode == "leaves") leaves_doc()
    else fields_doc()
  }
  reset(0)
  NPEND = 0
  split("", NESTFAIL)
}

# ---- Shapes and names ----

function fits(v, q, sid,    n) {
  if (!(sid in SRE)) return 0
  if (length(v) > SMAX[sid]) return 0
  if (sid == "rel-path") gsub(/[{][{] *[.]?[A-Za-z][A-Za-z0-9_.-]* *[}][}]/, "P", v)  # a generator parameter
  if (v !~ SRE[sid]) return 0
  if ((sid == "bool" || sid == "int" || sid == "port") && q) return 0
  if ((sid == "int" || sid == "port") && length(v) > 1 && substr(v, 1, 1) == "0") return 0
  if (sid == "port" && v + 0 > 65535) return 0
  if (sid == "image-ref" || sid == "image-digest") {
    n = index(v, "sha256:")
    if (n && length(v) - n - 6 != 64) return 0
  }
  return 1
}

# 20 or more characters with a letter and a digit: a token, not a name.
function tok20(s) { return length(s) >= 20 && s ~ /[A-Za-z]/ && s ~ /[0-9]/ }

function credlike(name,    s, n, i, c, w, pc) {
  s = tolower(name); gsub(/[-_.]/, "", s)
  if (s ~ /pass|pwd|secret|token|apikey|accesskey|privatekey|signingkey|encryptionkey|credential|connectionstring|connstr|dsn|auth|salt|bearer|jwt|hmac|license|cert|cookie|session/) return 1
  n = length(name); w = ""; pc = ""
  for (i = 1; i <= n + 1; i++) {
    c = (i <= n) ? substr(name, i, 1) : "-"
    if (c == "-" || c == "_" || c == "." || (c ~ /[A-Z]/ && pc ~ /[a-z0-9]/)) {
      w = tolower(w)
      if (w == "pw" || w == "pat") return 1
      w = (c ~ /[A-Z]/) ? c : ""
    } else w = w c
    pc = c
  }
  return 0
}

function listed(f,    g, i) {
  g = f; gsub(/\.[0-9]+/, ".#", g)
  if (g in FLX) return 1
  for (i = 1; i <= NFLP; i++) if (substr(g, 1, length(FLP[i])) == FLP[i]) return 1
  return 0
}

function out(ln, cont, f, v) {
  if (NESTOUT) { NPEND++; PENDK[NPEND] = NESTOUT; PENDL[NPEND] = ln; PENDF[NPEND] = f "=" v; return }
  NDO++; DOL[NDO] = ln; DOC[NDO] = cont; DOF[NDO] = f "=" v
}

# Every value that prints goes through here: the field list, then the shape.
# A key the reader saw and could not read prints other, so that it never
# looks the same as a key that is absent.
function field(ln, cont, f, v, q, t, sid) {
  if (!listed(f)) return
  if (sid == "label-value" && tok20(v)) t = "token"  # a token is not a label value
  if (sid == "present") { out(ln, cont, f, (t == "unread") ? "other" : "present"); return }
  # A quota value is a quantity, which may be quoted.
  if (f == "quota-hard.pods") q = 0
  if (t == "scalar" && q && v == "") {
    if (sid == "rbac-group") v = "core"
    else if (sid == "secret-type") v = "Opaque"
  }
  if (t == "scalar" && fits(v, q, sid)) out(ln, cont, f, v)
  else out(ln, cont, f, "other")  # a key seen and not read
}

function lastseg(p,    n, s) { n = split(p, s, ">"); return s[n] }

# The path with each item number written "#", the numbers in IX.
function generic(p,    n, s, i, g) {
  n = split(p, s, ">"); g = ""; NIX = 0
  for (i = 1; i <= n; i++) {
    if (substr(s[i], 1, 1) == "#") { NIX++; IX[NIX] = substr(s[i], 2); s[i] = "#" }
    g = (i == 1) ? s[i] : g ">" s[i]
  }
  return g
}

function fname(f,    i) {
  for (i = NIX; i >= 1; i--) gsub("#" i, IX[i], f)
  gsub(/#S/, SRCN, f)
  return f
}

function simple(ctx, k, rel, cont,    g, w, i, n) {
  g = generic(rel)
  if ((ctx SUBSEP g) in SIMPLE) {
    split(SIMPLE[ctx SUBSEP g], w, " ")
    field(LLN[0, k], cont, fname(w[1]), LVAL[0, k], LQ[0, k], LT[0, k], w[2])
    return 1
  }
  if ((ctx SUBSEP g ">#") in SIMPLE && LT[0, k] == "flow") {
    split(SIMPLE[ctx SUBSEP g ">#"], w, " ")
    n = flowitems(LVAL[0, k])
    NIX++
    for (i = 1; i <= n; i++) { IX[NIX] = i; field(LLN[0, k], cont, fname(w[1]), FIV[i], FIQ[i], FIT[i], w[2]) }
    return 1
  }
  return 0
}

# The number of items of a list leaf, or -1 when it is not a list.
function listcount(I, k) {
  if (LT[I, k] == "flow") return (substr(LVAL[I, k], 1, 1) == "[") ? flowitems(LVAL[I, k]) : -1
  if (LT[I, k] != "none") return -1
  if (LKIDS[I, k] > 0 && substr(lastseg(LPATH[I, LCH[I, k, 1]]), 1, 1) != "#") return -1
  return LKIDS[I, k]
}

# SOPS. A document carries a sops block when its top-level sops key is a
# block map. A value looks encrypted when it is a plain scalar that starts
# with ENC[ and ends with ]. Only its first four and last characters are
# tested, and no part of it prints.
function sopsdoc(I,    k) {
  k = leaf(I, "sops")
  return k && LT[I, k] == "none" && LKIDS[I, k] > 0 && listcount(I, k) == -1
}
function encval(I, k,    v) {
  v = LVAL[I, k]
  return LT[I, k] == "scalar" && substr(v, 1, 4) == "ENC[" && substr(v, length(v), 1) == "]"  # looks encrypted
}
# The state of a ConfigMap or values key, with the word encrypted for a
# value that looks encrypted, in a document with a sops block only.
function vstate(I, k,    w) {
  w = stateword(I, k)
  if (w == "scalar" && sopsdoc(I) && encval(I, k)) w = "encrypted"  # encrypted only in a sops document
  return w
}
# The data and stringData keys of a Secret that are set and do not look
# encrypted. A block scalar is counted as clear.
function sopsclear(    i, j, b, c, ch) {
  c = 0
  for (i = 1; i <= 2; i++) {
    b = leaf0(i == 1 ? "data" : "stringData")
    if (!b) continue
    for (j = 1; j <= LKIDS[0, b]; j++) {
      ch = LCH[0, b, j]
      if (stateword(0, ch) != "empty" && !encval(0, ch)) c++  # a clear value in a sops Secret
    }
  }
  return c
}

# block is a parent map, whose keys print lines of their own, and
# block-scalar a value written over several lines with | or >.
function stateword(I, k,    t, v) {
  t = LT[I, k]; v = LVAL[I, k]
  if (t == "block") return "block-scalar"  # a value over several lines
  if (t == "none") return LKIDS[I, k] > 0 ? "block" : "empty"
  if (t == "flow") return (v == "{}" || v == "[]") ? "empty" : "scalar"
  if (t == "scalar" && (v == "" || (!LQ[I, k] && (v == "null" || v == "~")))) return "empty"
  return "scalar"
}

# ---- Fields of an object ----

function fields_doc(    kk, k, p, i, ab, nm) {
  kk = leaf0("kind")
  if (!kk || LT[0, kk] != "scalar" || !fits(LVAL[0, kk], LQ[0, kk], "kind-name")) return
  KIND = LVAL[0, kk]
  if (KIND ~ /List$/) { ERR[0] = 1; LISTK = 1; return }  # a List holds objects the reader does not follow
  if (!(KIND in KINDS)) return
  NAME = "-"; k = leaf0("metadata>name"); if (k && LT[0, k] == "scalar" && fits(LVAL[0, k], LQ[0, k], "dns-subdomain")) NAME = LVAL[0, k]
  NSP = "-"; k = leaf0("metadata>namespace"); if (k && LT[0, k] == "scalar" && fits(LVAL[0, k], LQ[0, k], "dns-label")) NSP = LVAL[0, k]
  NDO = 0; NOBJ++
  out(LLN[0, kk], "-", "object", "present")
  POD = (KIND in PODKINDS) && !(KIND == "Rollout" && leaf0("spec>workloadRef"))
  P = (KIND == "Pod") ? "spec" : (KIND == "CronJob") ? "spec>jobTemplate>spec>template>spec" : "spec>template>spec"
  TM = (KIND == "Pod") ? "metadata" : substr(P, 1, length(P) - 5) ">metadata"
  TMLAB = POD ? TM ">labels" : ""
  # Annotation keys that are credential-like and hold a value.
  ANNCOUNT = 0; ANNDONE = 0
  for (i = 1; i <= 2; i++) {
    ab = (i == 1) ? leaf0("metadata>annotations") : (POD && TM != "metadata") ? leaf0(TM ">annotations") : 0
    if (!ab) continue
    for (k = 1; k <= LKIDS[0, ab]; k++) {
      nm = LCH[0, ab, k]
      if (credlike(lastseg(LPATH[0, nm])) && stateword(0, nm) != "empty") ANNCOUNT++
    }
  }
  split("", ARGDONE)
  if (KIND in ARGO) argo_prepass()
  for (k = 1; k <= NL[0]; k++) {
    if (k == kk) continue
    p = LPATH[0, k]
    if (p == "metadata>name" || p == "metadata>namespace") continue
    if (fields_leaf(k, p)) continue
    # Every other leaf reaches field() under its own key, and the field
    # list stops it.
    field(LLN[0, k], "-", "unlisted." lastseg(p), LVAL[0, k], LQ[0, k], LT[0, k], "label-value")
  }
  for (i = 1; i <= NDO; i++) OUT[++NOUT] = FILE ":" DOL[i] ":" KIND "/" NSP "/" NAME ":" DOC[i] ":" DOF[i]
}

function fields_leaf(k, p,    ln, rel) {
  ln = LLN[0, k]
  if (p == "apiVersion") { field(ln, "-", "api-version", LVAL[0, k], LQ[0, k], LT[0, k], "api-version"); return 1 }
  # A top-level sops key that is a block map: its name only, never a line under it.
  if (p == "sops") { if (sopsdoc(0)) { out(ln, "-", "sops", "present"); if (KIND == "Secret") field(ln, "-", "sops-clear-count", sopsclear() "", 0, "scalar", "int") } return 1 }  # a sops block map
  if ((p == "metadata>annotations" || (POD && p == TM ">annotations")) && !ANNDONE) {
    ANNDONE = 1
    if (ANNCOUNT > 0) field(ln, "-", "annotation-credential-like-count", ANNCOUNT "", 0, "scalar", "int")
    return 1
  }
  if (POD && substr(p, 1, length(P) + 1) == P ">") {
    rel = substr(p, length(P) + 2)
    if (podleaf(k, rel)) return 1
  }
  if (POD && (p == TMLAB || substr(p, 1, length(TMLAB) + 1) == TMLAB ">")) return labelleaf(k, p)
  if (KIND in ARGO) return argoleaf(k, p)
  if (simple(KIND, k, p, "-")) return 1
  if (KIND == "NetworkPolicy") return npleaf(k, p)
  if (KIND == "Role" || KIND == "ClusterRole") return roleleaf(k, p)
  if (KIND == "RoleBinding" || KIND == "ClusterRoleBinding") return bindleaf(k, p)
  if (KIND == "Secret") return secretleaf(k, p)
  if (KIND == "ConfigMap") return cmleaf(k, p)
  if (KIND == "ResourceQuota" && p == "spec>hard") return quotaleaf(k)
  return 0
}

function cname(cp,    k) {
  k = leaf0(cp ">name")
  if (k && LT[0, k] == "scalar" && fits(LVAL[0, k], LQ[0, k], "dns-label")) return LVAL[0, k]
  return "-"
}

function podleaf(k, rel,    cp, crel, ckind) {
  if (match(rel, /^(containers|initContainers)>#[0-9]+/)) {
    cp = P ">" substr(rel, 1, RLENGTH); crel = substr(rel, RLENGTH + 2)
    ckind = (substr(rel, 1, 1) == "c") ? "main" : "init"
    return contleaf(k, cp, crel, cname(cp), ckind)
  }
  if (simple("pod", k, rel, "-")) return 1
  if (rel ~ /^volumes>#[0-9]+>[^>]+$/ && lastseg(rel) != "name") {
    field(LLN[0, k], "-", "volume-type", lastseg(rel), 0, "scalar", "volume-type")
    return 1
  }
  return 0
}

function contleaf(k, cp, crel, cont, ckind,    ln, n) {
  ln = LLN[0, k]
  if (crel == "") { field(ln, cont, "container-kind", ckind, 0, "scalar", "container-kind"); return 1 }
  if (simple("c", k, crel, cont)) return 1
  if (crel == "image") { image(k, cont); return 1 }
  if (crel == "env") {
    n = envother(cp)
    if (n > 0) field(ln, cont, "env-other-count", n "", 0, "scalar", "int")
    return 1
  }
  if (crel ~ /^env>#[0-9]+$/) { envitem(k, cp ">" crel, cont); return 1 }
  if ((crel == "args" || crel == "command") && !(cp in ARGDONE)) {
    ARGDONE[cp] = 1
    n = argcount(cp)
    if (n > 0) field(ln, cont, "args-credential-like-count", n "", 0, "scalar", "int")
    return 1
  }
  if (crel ~ /^volumeMounts>#[0-9]+$/) { mountitem(k, cp ">" crel, cont); return 1 }
  return 0
}

# The registry, the repository, and a pin word. The tag is never printed.
function image(k, cont,    ln, v, s, dg, reg, i, last, tag, repo, n, seg, sg, pin) {
  ln = LLN[0, k]; v = LVAL[0, k]
  if (LT[0, k] != "scalar" || !fits(v, LQ[0, k], "image-ref")) {
    field(ln, cont, "image-registry", "", 0, "none", "image-registry")
    field(ln, cont, "image-repository", "", 0, "none", "image-repository")
    return
  }
  s = v; dg = ""
  i = index(s, "@"); if (i) { dg = substr(s, i + 1); s = substr(s, 1, i - 1) }
  reg = "default"
  i = index(s, "/")
  if (i) {
    seg = substr(s, 1, i - 1)
    if (seg ~ /[.:]/ || seg == "localhost") { reg = seg; s = substr(s, i + 1) }
  }
  last = s; while (index(last, "/")) last = substr(last, index(last, "/") + 1)
  tag = ""; i = index(last, ":")
  if (i) { tag = substr(last, i + 1); s = substr(s, 1, length(s) - length(last) + i - 1) }
  n = split(s, sg, "/"); repo = ""
  for (i = 1; i <= n; i++) repo = repo (i > 1 ? "/" : "") (tok20(sg[i]) ? "other" : sg[i])
  pin = (dg != "") ? "digest" : (tag == "latest") ? "latest" : (tag == "") ? "none" : "tag"
  field(ln, cont, "image-registry", reg, 0, "scalar", "image-registry")
  field(ln, cont, "image-repository", repo, 0, "scalar", "image-repository")
  field(ln, cont, "image-pin", pin, 0, "scalar", "image-pin")
}

function envname(ip,    k) {
  k = leaf0(ip ">name")
  if (!k || LT[0, k] != "scalar" || !fits(LVAL[0, k], LQ[0, k], "env-name") || tok20(LVAL[0, k])) return 0
  ENVNAME = LVAL[0, k]
  return 1
}

# Where the value of an env entry comes from. The value never prints.
function envsrc(ip,    vk, fk, src, n) {
  vk = leaf0(ip ">value"); fk = leaf0(ip ">valueFrom"); src = ""
  if (vk && !fk) src = "literal"  # names only: env
  if (src == "literal" && stateword(0, vk) == "empty") src = "literal-empty"  # an empty literal
  else if (fk && !vk && LT[0, fk] == "none" && LKIDS[0, fk] == 1) src = lastseg(LPATH[0, LCH[0, fk, 1]])
  return src
}

function envother(cp,    ek, n, i, ip, c) {
  ek = leaf0(cp ">env"); c = 0
  if (!ek) return 0
  n = listcount(0, ek)
  if (n <= 0) return 0
  if (LT[0, ek] == "flow") return n
  for (i = 1; i <= n; i++) {
    ip = cp ">env>#" i
    if (!envname(ip) || envsrc(ip) == "") c++
  }
  return c
}

function envitem(k, ip, cont,    nm, src, rk) {
  if (!envname(ip)) return
  nm = ENVNAME; src = envsrc(ip)
  if (src == "") return
  field(LLN[0, k], cont, "env." nm, src, 0, "scalar", "env-source")
  if (src == "secretKeyRef" || src == "configMapKeyRef") {
    rk = leaf0(ip ">valueFrom>" src ">name")
    if (rk) field(LLN[0, rk], cont, "env-ref." nm, LVAL[0, rk], LQ[0, rk], LT[0, rk], "dns-subdomain")
  }
}

function credarg(s,    t, i) {
  if (s ~ "://[^/@ ]+@") return 1
  t = s; sub(/^-+/, "", t)
  i = index(t, "="); if (i) t = substr(t, 1, i - 1)
  return length(t) <= 64 && t ~ /^[A-Za-z0-9_.-]+$/ && credlike(t)
}

function argcount(cp,    j, lk, n, i, c, ik) {
  c = 0
  for (j = 1; j <= 2; j++) {
    lk = leaf0(cp ">" (j == 1 ? "command" : "args"))
    if (!lk) continue
    if (LT[0, lk] == "flow") {
      n = flowitems(LVAL[0, lk])
      for (i = 1; i <= n; i++) if (FIT[i] == "scalar" && credarg(FIV[i])) c++
    } else if (listcount(0, lk) > 0) {
      for (i = 1; i <= LKIDS[0, lk]; i++) {
        ik = LCH[0, lk, i]
        if (LT[0, ik] == "scalar" && credarg(LVAL[0, ik])) c++
      }
    }
  }
  return c
}

function mountitem(k, ip, cont,    nk, rk, m) {
  nk = leaf0(ip ">name")
  if (!nk || LT[0, nk] != "scalar" || !fits(LVAL[0, nk], LQ[0, nk], "dns-label")) return
  rk = leaf0(ip ">readOnly")
  if (!rk) m = "read-write"
  else if (LT[0, rk] == "scalar" && fits(LVAL[0, rk], LQ[0, rk], "bool")) m = (LVAL[0, rk] == "true") ? "read-only" : "read-write"
  else m = ""
  field(LLN[0, k], cont, "mount." LVAL[0, nk], m, 0, "scalar", "mount-mode")
}

function labelleaf(k, p,    key, i, c, ck) {
  if (p == TMLAB) {
    c = 0
    for (i = 1; i <= LKIDS[0, k]; i++) {
      ck = LCH[0, k, i]
      if (!(lastseg(LPATH[0, ck]) in LABELKEYS)) c++
    }
    if (c > 0) field(LLN[0, k], "-", "pod-label-other-count", c "", 0, "scalar", "int")
    return 1
  }
  key = substr(p, length(TMLAB) + 2)
  if (!(key in LABELKEYS)) return 0
  field(LLN[0, k], "-", "pod-label." key, LVAL[0, k], LQ[0, k], LT[0, k], "label-value")
  return 1
}

# all for {}, labels for a selector with labels, nothing when unsure.
function selword(k,    p, ml, me, lab, unk, n) {
  p = LPATH[0, k]
  if (LT[0, k] == "flow") return (LVAL[0, k] == "{}") ? "all" : ""
  if (LT[0, k] != "none" || LKIDS[0, k] == 0) return ""
  ml = leaf0(p ">matchLabels"); me = leaf0(p ">matchExpressions"); lab = 0; unk = 0
  if (ml) {
    if (LT[0, ml] == "none" && LKIDS[0, ml] > 0) lab = 1
    else if (!(LT[0, ml] == "flow" && LVAL[0, ml] == "{}")) unk = 1
  }
  if (me) {
    n = listcount(0, me)
    if (n > 0) lab = 1
    else if (n < 0) unk = 1
  }
  if (LKIDS[0, k] != (ml ? 1 : 0) + (me ? 1 : 0)) unk = 1
  if (unk) return ""
  return lab ? "labels" : "all"
}

function selother(k,    p, ml, me, i, c, n) {
  p = LPATH[0, k]; c = 0
  ml = leaf0(p ">matchLabels"); me = leaf0(p ">matchExpressions")
  if (ml) for (i = 1; i <= LKIDS[0, ml]; i++) if (!(lastseg(LPATH[0, LCH[0, ml, i]]) in LABELKEYS)) c++
  if (me) { n = listcount(0, me); if (n > 0) c += n }
  return c
}

function npleaf(k, p,    ln, w, n, dir, r, fk, rest, base, key, s, x) {
  ln = LLN[0, k]
  if (p == "spec>podSelector") {
    w = selword(k)
    field(ln, "-", "np-pod-selector", w, 0, "scalar", "selector-word")
    n = selother(k)
    if (n > 0) field(ln, "-", "np-pod-label-other-count", n "", 0, "scalar", "int")
    return 1
  }
  if (substr(p, 1, 29) == "spec>podSelector>matchLabels>") {
    key = substr(p, 30)
    if (!(key in LABELKEYS)) return 0
    field(ln, "-", "np-pod-label." key, LVAL[0, k], LQ[0, k], LT[0, k], "label-value")
    return 1
  }
  if (p == "spec>ingress" || p == "spec>egress") {
    n = listcount(0, k)
    field(ln, "-", "np-" substr(p, 6) "-rules", n "", 0, "scalar", "int")
    return 1
  }
  if (p ~ /^spec>(ingress|egress)>#[0-9]+$/) {
    split(p, s, ">"); dir = s[2]; r = substr(s[3], 2)
    fk = leaf0(p ">" (dir == "ingress" ? "from" : "to"))
    n = fk ? listcount(0, fk) : 0
    field(ln, "-", "np-" dir "." r ".peers", n "", 0, "scalar", "int")
    return 1
  }
  if (p ~ /^spec>(ingress>#[0-9]+>from|egress>#[0-9]+>to)>#[0-9]+>/) {
    split(p, s, ">"); dir = s[2]; r = substr(s[3], 2)
    base = "np-" dir "." r ".peer." substr(s[5], 2) "."
    rest = p; for (x = 1; x <= 5; x++) rest = substr(rest, index(rest, ">") + 1)
    if (rest == "podSelector" || rest == "namespaceSelector") {
      w = selword(k)
      field(ln, "-", base (rest == "podSelector" ? "pod-selector" : "namespace-selector"), w, 0, "scalar", "selector-word")
      return 1
    }
    if (substr(rest, 1, 24) == "podSelector>matchLabels>") {
      key = substr(rest, 25)
      if (!(key in LABELKEYS)) return 0
      field(ln, "-", base "pod-label." key, LVAL[0, k], LQ[0, k], LT[0, k], "label-value")
      return 1
    }
    if (substr(rest, 1, 30) == "namespaceSelector>matchLabels>") {
      key = substr(rest, 31)
      if (!(key in LABELKEYS) && key != "kubernetes.io/metadata.name") return 0
      field(ln, "-", base "namespace-label." key, LVAL[0, k], LQ[0, k], LT[0, k], "label-value")
      return 1
    }
    if (rest == "ipBlock>cidr") {
      field(ln, "-", base "ip-block", LVAL[0, k], LQ[0, k], LT[0, k], fits(LVAL[0, k], LQ[0, k], "cidr-v4") ? "cidr-v4" : "cidr-v6")
      return 1
    }
    if (rest == "ipBlock>except") {
      n = listcount(0, k)
      field(ln, "-", base "ip-block-except-count", n "", 0, "scalar", "int")
      return 1
    }
  }
  return 0
}

function roleleaf(k, p,    n, s) {
  if (p ~ /^rules>#[0-9]+>(resourceNames|nonResourceURLs)$/) {
    split(p, s, ">"); n = listcount(0, k)
    field(LLN[0, k], "-", "rule." substr(s[2], 2) (s[3] == "resourceNames" ? ".resource-names-count" : ".non-resource-urls-count"), n "", 0, "scalar", "int")
    return 1
  }
  if (p == "aggregationRule" && KIND == "ClusterRole") { field(LLN[0, k], "-", "aggregation-rule", "", 0, "none", "present"); return 1 }
  return 0
}

function bindleaf(k, p,    s, kk, w) {
  if (p !~ /^subjects>#[0-9]+>name$/) return 0
  split(p, s, ">")
  kk = leaf0("subjects>" s[2] ">kind")
  # A User subject: the form of its name in three fixed words, never the name.
  if (kk && LT[0, kk] == "scalar" && LVAL[0, kk] == "User") {
    # A quoted name with a backslash may spell another name once decoded.
    w = (LT[0, k] != "scalar" || LVAL[0, k] == "" || (LQ[0, k] && index(LVAL[0, k], "\\"))) ? "other" : (substr(LVAL[0, k], 1, 22) == "system:serviceaccount:") ? "service-account" : "plain"  # the form of a User name
    field(LLN[0, k], "-", "subject." substr(s[2], 2) ".user-form", w, 0, "scalar", "user-form")
    return 1
  }
  if (!kk || LT[0, kk] != "scalar" || LVAL[0, kk] != "ServiceAccount") return 0
  field(LLN[0, k], "-", "subject." substr(s[2], 2) ".name", LVAL[0, k], LQ[0, k], LT[0, k], "dns-subdomain")
  return 1
}

function secretleaf(k, p,    ln, key, f, sv) {
  ln = LLN[0, k]
  if (p == "type") { field(ln, "-", "secret-type", LVAL[0, k], LQ[0, k], LT[0, k], "secret-type"); return 1 }
  if (p ~ /^(data|stringData)>[^>]+$/) {
    key = lastseg(p)
    f = (substr(p, 1, 1) == "d") ? "secret-key.data" : "secret-key.string-data"
    if (stateword(0, k) == "empty") f = f "-empty"  # an empty Secret key
    sv = key  # names only: secret
    if (tok20(sv)) sv = "other"
    field(ln, "-", f, sv, 0, "scalar", "key-name")
    return 1
  }
  return 0
}

function cmleaf(k, p,    key) {
  if (p !~ /^(data|binaryData)>[^>]+$/) return 0
  key = lastseg(p)
  if (!fits(key, 0, "key-name") || tok20(key)) key = "other"
  if (substr(p, 1, 1) == "d") field(LLN[0, k], "-", "configmap-data." key, vstate(0, k), 0, "scalar", "state-word")
  else field(LLN[0, k], "-", "configmap-binary." key, "", 0, "none", "present")
  return 1
}

function quotaleaf(k,    i, c) {
  c = 0
  for (i = 1; i <= LKIDS[0, k]; i++) if (!(("ResourceQuota" SUBSEP "spec>hard>" lastseg(LPATH[0, LCH[0, k, i]])) in SIMPLE)) c++
  if (c > 0) field(LLN[0, k], "-", "quota-other-count", c "", 0, "scalar", "int")
  return 1
}

# ---- Argo CD ----

function refs(s,    i, j, inner) {
  while ((i = index(s, "{{")) > 0) {
    s = substr(s, i + 2); j = index(s, "}}")
    if (!j) return
    inner = substr(s, 1, j - 1); s = substr(s, j + 2)
    gsub(/ /, "", inner); sub(/^\./, "", inner)
    if (inner ~ /^[A-Za-z][A-Za-z0-9_-]*$/) REFKEYS[inner] = 1
  }
}

function argo_prepass(    k, p, rel) {
  ABASE = (KIND == "ApplicationSet") ? "spec>template>spec" : "spec"
  HASSOURCES = leaf0(ABASE ">sources") ? 1 : 0
  split("", REFKEYS)
  for (k = 1; k <= NL[0]; k++) {
    p = LPATH[0, k]
    if (substr(p, 1, length(ABASE) + 1) != ABASE ">") continue
    rel = substr(p, length(ABASE) + 2)
    if (rel == "project" || rel == "destination>namespace" || rel ~ /^(source|sources>#[0-9]+)>(path|helm>valueFiles(>#[0-9]+)?)$/) refs(LVAL[0, k])
  }
}

function urlnorm(u) {
  u = tolower(u)
  sub(/^[a-z][a-z0-9+.-]*:\/\//, "", u)
  sub("^[^/@]*@", "", u)
  if (index(u, ":") && (!index(u, "/") || index(u, ":") < index(u, "/"))) sub(/:/, "/", u)
  sub(/\/+$/, "", u); sub(/\.git$/, "", u); sub(/\/+$/, "", u)
  return u
}

function argoleaf(k, p,    ln, s, i, rel, key, v, val) {
  ln = LLN[0, k]
  if (KIND == "ApplicationSet") {
    if (simple("ApplicationSet", k, p, "-")) return 1
    if (p ~ /^spec>generators>#[0-9]+>[^>]+$/) {
      split(p, s, ">")
      field(ln, "-", "generator." substr(s[3], 2), (s[4] == "list") ? "list" : "other", 0, "scalar", "generator-word")
      return 1
    }
    if (p ~ /^spec>generators>#[0-9]+>list>elements>#[0-9]+>[^>]+$/) {
      split(p, s, ">"); key = s[7]
      val = "present"; v = LVAL[0, k]
      if (!fits(key, 0, "element-key") || tok20(key)) key = "other"
      else if (!credlike(key) && (key in REFKEYS) && LT[0, k] == "scalar" && fits(v, LQ[0, k], "short-name")) val = v
      field(ln, "-", "list-element." substr(s[3], 2) "." substr(s[6], 2) "." key, val, LQ[0, k], "scalar", (val == "present") ? "present" : "short-name")
      return 1
    }
  }
  if (substr(p, 1, length(ABASE) + 1) != ABASE ">") return 0
  rel = substr(p, length(ABASE) + 2)
  if (simple("argo", k, rel, "-")) return 1
  if (!HASSOURCES && substr(rel, 1, 7) == "source>") { SRCN = 1; return srcleaf(k, substr(rel, 8)) }
  if (match(rel, /^sources>#[0-9]+>/)) { SRCN = substr(rel, 10, RLENGTH - 10); return srcleaf(k, substr(rel, RLENGTH + 1)) }
  return 0
}

function srcleaf(k, srel,    ln, v, user, w, i, n, nk, vk, pre) {
  ln = LLN[0, k]; pre = "source." SRCN "."
  if (srel == "repoURL") {
    v = LVAL[0, k]
    if (LT[0, k] != "scalar") { field(ln, "-", pre "repo", "unknown", 0, "scalar", "repo-word"); return 1 }
    user = (v ~ "^[A-Za-z][A-Za-z0-9+.-]*://[^/@]*@" || v ~ /^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+:/) ? "true" : "false"
    w = (NREMOTES == 0) ? "unknown" : "other"
    for (i = 1; i <= NREMOTES; i++) if (urlnorm(REMOTE[i]) == urlnorm(v)) w = "this"
    field(ln, "-", pre "repo", w, 0, "scalar", "repo-word")
    field(ln, "-", pre "url-has-user-part", user, 0, "scalar", "bool")
    return 1
  }
  if (simple("src", k, srel, "-")) return 1
  if (srel == "chart" || srel == "helm>valuesObject" || srel == "kustomize") {
    field(ln, "-", pre (srel == "chart" ? "chart" : srel == "kustomize" ? "kustomize" : "helm-values-object"), "", 0, "none", "present")
    return 1
  }
  if (srel == "helm>values") {
    field(ln, "-", pre "helm-values", "", 0, (k in NESTFAIL) ? "unread" : "none", "present")
    for (i = 1; i <= NPEND; i++) if (PENDK[i] == k) { NDO++; DOL[NDO] = PENDL[i]; DOC[NDO] = "-"; DOF[NDO] = PENDF[i] }
    return 1
  }
  if (substr(srel, 1, 18) == "helm>valuesObject>") {
    vleaf(0, k, substr(srel, 19))
    return 1
  }
  if (srel == "helm>parameters") {
    n = listcount(0, k)
    field(ln, "-", pre "helm-parameter-count", n "", 0, "scalar", "int")
    return 1
  }
  if (srel ~ /^helm>parameters>#[0-9]+$/) {
    nk = leaf0(LPATH[0, k] ">name"); vk = leaf0(LPATH[0, k] ">value")
    if (nk && vk && LT[0, nk] == "scalar") {
      v = LVAL[0, nk]; gsub(/\./, ">", v)
      vkey(0, LLN[0, vk], v, vk)
    }
    return 1
  }
  return 0
}

# ---- The values-file rule ----

# One leaf of a values tree, with its path below the tree root.
function vleaf(I, k, p,    n, s, i, last, prev, pp, j) {
  if (index(p, "#")) {
    n = split(p, s, ">")
    if (substr(s[n], 1, 1) == "#" && n >= 3 && s[n - 2] == "capabilities" && (s[n - 1] == "drop" || s[n - 1] == "add") && index(substr(p, 1, length(p) - length(s[n])), "#") == 0) {
      pp = s[1]; for (j = 2; j < n; j++) pp = pp "." s[j]
      for (j = 1; j < n; j++) if (credlike(s[j])) return  # a credential-like parent of a capability list
      if (vpathok(pp)) field(LLN[I, k], "-", "values." vprint(pp), LVAL[I, k], LQ[I, k], LT[I, k], "cap-name")
      return
    }
    if (substr(s[n], 1, 1) == "#") return
    vunread(LLN[I, k])
    return
  }
  vkey(I, LLN[I, k], p, k)
}

function vpathok(pp,    n, s, i) {
  n = split(pp, s, ".")
  if (n > 8 || length(pp) > 200) return 0
  for (i = 1; i <= n; i++) if (s[i] !~ /^[A-Za-z_][A-Za-z0-9_-]*$/) return 0
  return 1
}

function vprint(pp,    n, s, i, o) {
  n = split(pp, s, "."); o = ""
  for (i = 1; i <= n; i++) o = o (i > 1 ? "." : "") (tok20(s[i]) ? "other" : s[i])
  return o
}

function vunread(ln) { VUNR++; if (!VUNRL) VUNRL = ln }

# A key of a values tree: its name always, its value only when the rule allows.
function vkey(I, ln, p, k,    pp, n, s, last, prev, sid, v, q, t, i, w) {
  pp = p; gsub(/>/, ".", pp)
  if (!vpathok(pp)) { vunread(ln); return }
  field(ln, "-", "values-key." vprint(pp), vstate(I, k), 0, "scalar", "state-word")
  n = split(pp, s, "."); last = s[n]; prev = (n > 1) ? s[n - 1] : ""
  for (i = 1; i <= n; i++) if (credlike(s[i])) return  # a credential-like key or parent
  v = LVAL[I, k]; q = LQ[I, k]; t = LT[I, k]; sid = ""
  if (last == "cpu" && (prev == "requests" || prev == "limits")) sid = "qty-cpu"
  else if (last == "memory" && (prev == "requests" || prev == "limits")) sid = "qty-mem"
  else if (last ~ /^(privileged|allowPrivilegeEscalation|readOnlyRootFilesystem|runAsNonRoot)$/) sid = "bool"
  else if (last ~ /^(runAsUser|runAsGroup|replicaCount|replicas|minReplicas|maxReplicas)$/) sid = "int"
  else if ((last == "drop" || last == "add") && prev == "capabilities" && t == "flow") {
    w = flowitems(v)
    for (i = 1; i <= w; i++) field(ln, "-", "values." vprint(pp), FIV[i], FIQ[i], FIT[i], "cap-name")
    return
  } else if (last == "tag" && prev == "image") {
    w = (t == "scalar" && v == "latest") ? "latest" : (t == "scalar" && fits(v, q, "image-tag")) ? "tag" : ""
    field(ln, "-", "values." vprint(pp), w, 0, "scalar", "image-pin")
    return
  } else if (last == "digest" && prev == "image") {
    w = (t == "scalar" && fits(v, q, "image-digest")) ? "digest" : ""
    field(ln, "-", "values." vprint(pp), w, 0, "scalar", "image-pin")
    return
  }
  if (sid != "") field(ln, "-", "values." vprint(pp), v, q, t, sid)
}

function vtree(I,    k) {
  VUNR = 0; VUNRL = 0
  for (k = 1; k <= NL[I]; k++) vleaf(I, k, LPATH[I, k])
  if (VUNR > 0) field(VUNRL, "-", "values-key-unreadable-count", VUNR "", 0, "scalar", "int")
}

function values_doc(    i) {
  NDO = 0
  vtree(0)
  for (i = 1; i <= NDO; i++) OUT[++NOUT] = FILE ":" DOL[i] ":Values/-/-:" DOC[i] ":" DOF[i]
}

# The lines of a helm.values block, read as a values file. They wait until
# the object they belong to is known.
function nested_values(k) {
  NESTOUT = k
  vtree(1)
  NESTOUT = 0
}

# ---- Leaves, for the reader itself ----

function leaves_doc(    k, n, i) {
  for (k = 1; k <= NL[0]; k++) {
    OUT[++NOUT] = LT[0, k] "\t" LPATH[0, k] "\t" LVAL[0, k]
    if (LT[0, k] == "flow") {
      n = flowitems(LVAL[0, k])
      for (i = 1; i <= n; i++) OUT[++NOUT] = FIT[i] "\t" LPATH[0, k] ">#" i "\t" FIV[i]
    }
  }
}

BEGIN {
  FILE = ENVIRON["K8S_FILE"]
  n = split(ENVIRON["K8S_SHAPES"], L, "\n")
  for (i = 1; i <= n; i++) {
    if (L[i] == "") continue
    split(L[i], w, " ")
    SMAX[w[1]] = w[2] + 0
    SRE[w[1]] = substr(L[i], length(w[1]) + length(w[2]) + 3)
  }
  SRE["image-pin"] = "^(digest|tag|latest|none)$"; SMAX["image-pin"] = 6
  SRE["mount-mode"] = "^(read-only|read-write)$"; SMAX["mount-mode"] = 10
  SRE["state-word"] = "^(scalar|empty|block|block-scalar|encrypted)$"; SMAX["state-word"] = 12
  SRE["user-form"] = "^(service-account|plain|other)$"; SMAX["user-form"] = 15
  SRE["selector-word"] = "^(all|labels)$"; SMAX["selector-word"] = 6
  SRE["generator-word"] = "^(list|other)$"; SMAX["generator-word"] = 5
  SRE["repo-word"] = "^(this|other|unknown)$"; SMAX["repo-word"] = 7
  NREMOTES = 0
  n = split(ENVIRON["K8S_REMOTES"], L, "\n")
  for (i = 1; i <= n; i++) if (L[i] != "") REMOTE[++NREMOTES] = L[i]

  # The field list of references/fields.md. A trailing "." takes a key.
  n = split("object api-version annotation-credential-like-count host-network host-pid host-ipc " \
    "service-account automount-sa-token run-as-non-root run-as-user run-as-group cpu-request " \
    "memory-request cpu-limit memory-limit pod-active-deadline-seconds pod-label. pod-label-other-count " \
    "volume-name volume-type host-path emptydir-medium emptydir-size-limit secret-volume-name " \
    "configmap-volume-name container-kind image-repository image-pin image-registry image-pull-policy " \
    "ephemeral-storage-request ephemeral-storage-limit privileged allow-privilege-escalation " \
    "read-only-root-fs cap-drop cap-add host-port mount. env. env-ref. env-from-secret env-from-configmap " \
    "env-other-count args-credential-like-count replicas workload-ref-kind workload-ref-name " \
    "workload-ref-scale-down active-deadline-seconds backoff-limit ttl-seconds-after-finished " \
    "concurrency-policy starting-deadline-seconds history-limit-successful history-limit-failed " \
    "scale-target-api-version scale-target-kind scale-target-name min-replicas max-replicas metric-type " \
    "metric-resource metric-target-type metric-average-utilization update-mode limit-type " \
    "limit-default.cpu limit-default.memory limit-default-request.cpu limit-default-request.memory " \
    "limit-max.cpu limit-max.memory limit-min.cpu limit-min.memory limit-max-ratio.cpu " \
    "limit-max-ratio.memory quota-hard.requests.cpu quota-hard.limits.cpu quota-hard.cpu " \
    "quota-hard.requests.memory quota-hard.limits.memory quota-hard.memory " \
    "quota-hard.requests.ephemeral-storage quota-hard.limits.ephemeral-storage " \
    "quota-hard.ephemeral-storage quota-hard.pods quota-other-count psa-enforce psa-enforce-version " \
    "psa-warn psa-warn-version rule.#.verb rule.#.resource rule.#.api-group rule.#.resource-names-count " \
    "rule.#.non-resource-urls-count aggregation-rule sops sops-clear-count role-ref-kind role-ref-name subject.#.kind " \
    "subject.#.name subject.#.user-form subject.#.namespace np-pod-selector np-pod-label. np-pod-label-other-count " \
    "np-policy-type np-ingress-rules np-egress-rules np-ingress.#.peers np-egress.#.peers " \
    "np-ingress.#.peer.#.pod-selector np-egress.#.peer.#.pod-selector " \
    "np-ingress.#.peer.#.namespace-selector np-egress.#.peer.#.namespace-selector " \
    "np-ingress.#.peer.#.pod-label. np-egress.#.peer.#.pod-label. " \
    "np-ingress.#.peer.#.namespace-label. np-egress.#.peer.#.namespace-label. " \
    "np-ingress.#.peer.#.ip-block np-egress.#.peer.#.ip-block " \
    "np-ingress.#.peer.#.ip-block-except-count np-egress.#.peer.#.ip-block-except-count " \
    "np-ingress.#.port np-egress.#.port np-ingress.#.end-port np-egress.#.end-port " \
    "np-ingress.#.protocol np-egress.#.protocol secret-type secret-key.data secret-key.string-data secret-key.data-empty secret-key.string-data-empty " \
    "secret-immutable configmap-data. configmap-binary. configmap-immutable app-project " \
    "destination-namespace source.#.repo source.#.url-has-user-part source.#.path source.#.chart " \
    "source.#.ref source.#.value-file.# source.#.helm-values source.#.helm-values-object " \
    "source.#.helm-parameter-count source.#.kustomize go-template generator.# list-element.#.#. " \
    "values-key. values. values-key-unreadable-count", L, " ")
  NFLP = 0
  for (i = 1; i <= n; i++) {
    if (substr(L[i], length(L[i]), 1) == ".") FLP[++NFLP] = L[i]
    else FLX[L[i]] = 1
  }

  n = split("app app.kubernetes.io/name app.kubernetes.io/instance app.kubernetes.io/component " \
    "app.kubernetes.io/part-of component tier role environment", L, " ")
  for (i = 1; i <= n; i++) LABELKEYS[L[i]] = 1
  n = split("Pod Deployment StatefulSet DaemonSet Job CronJob Rollout HorizontalPodAutoscaler " \
    "VerticalPodAutoscaler LimitRange ResourceQuota Namespace ServiceAccount Role ClusterRole " \
    "RoleBinding ClusterRoleBinding NetworkPolicy Secret ConfigMap Application ApplicationSet", L, " ")
  for (i = 1; i <= n; i++) KINDS[L[i]] = 1
  n = split("Pod Deployment StatefulSet DaemonSet Job CronJob Rollout", L, " ")
  for (i = 1; i <= n; i++) PODKINDS[L[i]] = 1
  ARGO["Application"] = 1; ARGO["ApplicationSet"] = 1

  # The simple fields: context, path ("#" for an item), field, and shape.
  # Context pod is a path
  # below the pod spec, c below a container, argo below the Application
  # spec, src below one source, and a kind name below the object.
  n = split("" \
    "pod|hostNetwork|host-network|bool;pod|hostPID|host-pid|bool;pod|hostIPC|host-ipc|bool;" \
    "pod|serviceAccountName|service-account|dns-subdomain;pod|serviceAccount|service-account|dns-subdomain;" \
    "pod|automountServiceAccountToken|automount-sa-token|bool;" \
    "pod|securityContext>runAsNonRoot|run-as-non-root|bool;pod|securityContext>runAsUser|run-as-user|int;" \
    "pod|securityContext>runAsGroup|run-as-group|int;" \
    "pod|resources>requests>cpu|cpu-request|qty-cpu;pod|resources>requests>memory|memory-request|qty-mem;" \
    "pod|resources>limits>cpu|cpu-limit|qty-cpu;pod|resources>limits>memory|memory-limit|qty-mem;" \
    "pod|activeDeadlineSeconds|pod-active-deadline-seconds|int;pod|volumes>#>name|volume-name|dns-label;" \
    "pod|volumes>#>hostPath>path|host-path|host-path;pod|volumes>#>emptyDir>medium|emptydir-medium|medium;" \
    "pod|volumes>#>emptyDir>sizeLimit|emptydir-size-limit|qty-mem;" \
    "pod|volumes>#>secret>secretName|secret-volume-name|dns-subdomain;" \
    "pod|volumes>#>configMap>name|configmap-volume-name|dns-subdomain;" \
    "c|imagePullPolicy|image-pull-policy|pull-policy;" \
    "c|resources>requests>cpu|cpu-request|qty-cpu;c|resources>requests>memory|memory-request|qty-mem;" \
    "c|resources>limits>cpu|cpu-limit|qty-cpu;c|resources>limits>memory|memory-limit|qty-mem;" \
    "c|resources>requests>ephemeral-storage|ephemeral-storage-request|qty-mem;" \
    "c|resources>limits>ephemeral-storage|ephemeral-storage-limit|qty-mem;" \
    "c|securityContext>privileged|privileged|bool;" \
    "c|securityContext>allowPrivilegeEscalation|allow-privilege-escalation|bool;" \
    "c|securityContext>readOnlyRootFilesystem|read-only-root-fs|bool;" \
    "c|securityContext>runAsNonRoot|run-as-non-root|bool;c|securityContext>runAsUser|run-as-user|int;" \
    "c|securityContext>runAsGroup|run-as-group|int;" \
    "c|securityContext>capabilities>drop>#|cap-drop|cap-name;" \
    "c|securityContext>capabilities>add>#|cap-add|cap-name;" \
    "c|ports>#>hostPort|host-port|port;" \
    "c|envFrom>#>secretRef>name|env-from-secret|dns-subdomain;" \
    "c|envFrom>#>configMapRef>name|env-from-configmap|dns-subdomain;" \
    "Deployment|spec>replicas|replicas|int;StatefulSet|spec>replicas|replicas|int;" \
    "Rollout|spec>replicas|replicas|int;Rollout|spec>workloadRef>kind|workload-ref-kind|kind-name;" \
    "Rollout|spec>workloadRef>name|workload-ref-name|dns-subdomain;" \
    "Rollout|spec>workloadRef>scaleDown|workload-ref-scale-down|scale-down;" \
    "Job|spec>activeDeadlineSeconds|active-deadline-seconds|int;Job|spec>backoffLimit|backoff-limit|int;" \
    "Job|spec>ttlSecondsAfterFinished|ttl-seconds-after-finished|int;" \
    "CronJob|spec>jobTemplate>spec>activeDeadlineSeconds|active-deadline-seconds|int;" \
    "CronJob|spec>jobTemplate>spec>backoffLimit|backoff-limit|int;" \
    "CronJob|spec>jobTemplate>spec>ttlSecondsAfterFinished|ttl-seconds-after-finished|int;" \
    "CronJob|spec>concurrencyPolicy|concurrency-policy|concurrency-policy;" \
    "CronJob|spec>startingDeadlineSeconds|starting-deadline-seconds|int;" \
    "CronJob|spec>successfulJobsHistoryLimit|history-limit-successful|int;" \
    "CronJob|spec>failedJobsHistoryLimit|history-limit-failed|int;" \
    "HorizontalPodAutoscaler|spec>scaleTargetRef>apiVersion|scale-target-api-version|api-version;" \
    "HorizontalPodAutoscaler|spec>scaleTargetRef>kind|scale-target-kind|kind-name;" \
    "HorizontalPodAutoscaler|spec>scaleTargetRef>name|scale-target-name|dns-subdomain;" \
    "HorizontalPodAutoscaler|spec>minReplicas|min-replicas|int;" \
    "HorizontalPodAutoscaler|spec>maxReplicas|max-replicas|int;" \
    "HorizontalPodAutoscaler|spec>metrics>#>type|metric-type|metric-type;" \
    "HorizontalPodAutoscaler|spec>metrics>#>resource>name|metric-resource|metric-resource;" \
    "HorizontalPodAutoscaler|spec>metrics>#>resource>target>type|metric-target-type|metric-target-type;" \
    "HorizontalPodAutoscaler|spec>metrics>#>resource>target>averageUtilization|metric-average-utilization|int;" \
    "VerticalPodAutoscaler|spec>targetRef>apiVersion|scale-target-api-version|api-version;" \
    "VerticalPodAutoscaler|spec>targetRef>kind|scale-target-kind|kind-name;" \
    "VerticalPodAutoscaler|spec>targetRef>name|scale-target-name|dns-subdomain;" \
    "VerticalPodAutoscaler|spec>updatePolicy>updateMode|update-mode|update-mode;" \
    "LimitRange|spec>limits>#>type|limit-type|limit-type;" \
    "LimitRange|spec>limits>#>default>cpu|limit-default.cpu|qty-cpu;" \
    "LimitRange|spec>limits>#>default>memory|limit-default.memory|qty-mem;" \
    "LimitRange|spec>limits>#>defaultRequest>cpu|limit-default-request.cpu|qty-cpu;" \
    "LimitRange|spec>limits>#>defaultRequest>memory|limit-default-request.memory|qty-mem;" \
    "LimitRange|spec>limits>#>max>cpu|limit-max.cpu|qty-cpu;" \
    "LimitRange|spec>limits>#>max>memory|limit-max.memory|qty-mem;" \
    "LimitRange|spec>limits>#>min>cpu|limit-min.cpu|qty-cpu;" \
    "LimitRange|spec>limits>#>min>memory|limit-min.memory|qty-mem;" \
    "LimitRange|spec>limits>#>maxLimitRequestRatio>cpu|limit-max-ratio.cpu|qty-cpu;" \
    "LimitRange|spec>limits>#>maxLimitRequestRatio>memory|limit-max-ratio.memory|qty-cpu;" \
    "ResourceQuota|spec>hard>requests.cpu|quota-hard.requests.cpu|qty-cpu;" \
    "ResourceQuota|spec>hard>limits.cpu|quota-hard.limits.cpu|qty-cpu;" \
    "ResourceQuota|spec>hard>cpu|quota-hard.cpu|qty-cpu;" \
    "ResourceQuota|spec>hard>requests.memory|quota-hard.requests.memory|qty-mem;" \
    "ResourceQuota|spec>hard>limits.memory|quota-hard.limits.memory|qty-mem;" \
    "ResourceQuota|spec>hard>memory|quota-hard.memory|qty-mem;" \
    "ResourceQuota|spec>hard>requests.ephemeral-storage|quota-hard.requests.ephemeral-storage|qty-mem;" \
    "ResourceQuota|spec>hard>limits.ephemeral-storage|quota-hard.limits.ephemeral-storage|qty-mem;" \
    "ResourceQuota|spec>hard>ephemeral-storage|quota-hard.ephemeral-storage|qty-mem;" \
    "ResourceQuota|spec>hard>pods|quota-hard.pods|int;" \
    "Namespace|metadata>labels>pod-security.kubernetes.io/enforce|psa-enforce|psa-level;" \
    "Namespace|metadata>labels>pod-security.kubernetes.io/enforce-version|psa-enforce-version|psa-version;" \
    "Namespace|metadata>labels>pod-security.kubernetes.io/warn|psa-warn|psa-level;" \
    "Namespace|metadata>labels>pod-security.kubernetes.io/warn-version|psa-warn-version|psa-version;" \
    "ServiceAccount|automountServiceAccountToken|automount-sa-token|bool;" \
    "Role|rules>#>verbs>#|rule.#1.verb|rbac-verb;" \
    "Role|rules>#>resources>#|rule.#1.resource|rbac-resource;" \
    "Role|rules>#>apiGroups>#|rule.#1.api-group|rbac-group;" \
    "ClusterRole|rules>#>verbs>#|rule.#1.verb|rbac-verb;" \
    "ClusterRole|rules>#>resources>#|rule.#1.resource|rbac-resource;" \
    "ClusterRole|rules>#>apiGroups>#|rule.#1.api-group|rbac-group;" \
    "RoleBinding|roleRef>kind|role-ref-kind|role-ref-kind;RoleBinding|roleRef>name|role-ref-name|role-name;" \
    "RoleBinding|subjects>#>kind|subject.#1.kind|subject-kind;" \
    "RoleBinding|subjects>#>namespace|subject.#1.namespace|dns-label;" \
    "ClusterRoleBinding|roleRef>kind|role-ref-kind|role-ref-kind;" \
    "ClusterRoleBinding|roleRef>name|role-ref-name|role-name;" \
    "ClusterRoleBinding|subjects>#>kind|subject.#1.kind|subject-kind;" \
    "ClusterRoleBinding|subjects>#>namespace|subject.#1.namespace|dns-label;" \
    "NetworkPolicy|spec>policyTypes>#|np-policy-type|policy-type;" \
    "NetworkPolicy|spec>ingress>#>ports>#>port|np-ingress.#1.port|port;" \
    "NetworkPolicy|spec>ingress>#>ports>#>endPort|np-ingress.#1.end-port|port;" \
    "NetworkPolicy|spec>ingress>#>ports>#>protocol|np-ingress.#1.protocol|protocol;" \
    "NetworkPolicy|spec>egress>#>ports>#>port|np-egress.#1.port|port;" \
    "NetworkPolicy|spec>egress>#>ports>#>endPort|np-egress.#1.end-port|port;" \
    "NetworkPolicy|spec>egress>#>ports>#>protocol|np-egress.#1.protocol|protocol;" \
    "Secret|immutable|secret-immutable|bool;ConfigMap|immutable|configmap-immutable|bool;" \
    "argo|project|app-project|dns-subdomain;argo|destination>namespace|destination-namespace|dns-label;" \
    "src|path|source.#S.path|rel-path;src|ref|source.#S.ref|element-key;" \
    "src|helm>valueFiles>#|source.#S.value-file.#1|rel-path;" \
    "ApplicationSet|spec>goTemplate|go-template|bool", L, ";")
  for (i = 1; i <= n; i++) {
    split(L[i], w, "|")
    SIMPLE[w[1] SUBSEP w[2]] = w[3] " " w[4]
  }
  reset(0); reset(1)
}

{ pline(0, $0, NR) }

END {
  if (!ERR[0]) doc_end()
  if (ERR[0]) exit (LISTK ? 5 : 4)
  if (mode == "render" && !NOBJ) exit 3  # a render that printed no object
  for (i = 1; i <= NOUT; i++) print OUT[i]
}
'

# The schema test. It reads a values.schema.json file as JSON, decodes the
# escapes of each string (\uXXXX in either case of hex, \/, and the rest),
# and exits 1 when a decoded key is $ref (or $dynamicRef, $recursiveRef,
# or $schema) with a value that is not a string starting with #, when a decoded key is
# $id, or when the file is not JSON the test can read. It prints nothing.
# shellcheck disable=SC2016 # awk code, not shell
SCHEMA='
function hexv(h,    i, v, c) {
  v = 0
  for (i = 1; i <= 4; i++) {
    c = index("0123456789abcdef", tolower(substr(h, i, 1)))
    if (!c) return -1
    v = v * 16 + c - 1
  }
  return v
}
# A string that starts at T[i] (the quote): its decoded text in S, and the
# place after its closing quote in POS. A character that cannot be part of
# a key the test looks for is decoded as "?".
function str(i,    c, e, v) {
  S = ""; i++
  while (i <= N) {
    c = substr(T, i, 1)
    if (c == "\"") { POS = i + 1; return 1 }
    if (c < " ") return 0
    if (c == "\\") {
      e = substr(T, i + 1, 1)
      if (e == "u") {
        v = hexv(substr(T, i + 2, 4))
        if (v < 0) return 0
        S = S ((v >= 32 && v < 127) ? sprintf("%c", v) : "?")  # a JSON escape, decoded
        i += 6; continue
      }
      if (e == "\"" || e == "\\" || e == "/") S = S e
      else if (index("bfnrt", e) && e != "") S = S "?"
      else return 0
      i += 2; continue
    }
    S = S c; i++
  }
  return 0
}
function ws(i) { while (i <= N && index(" \t\n\r", substr(T, i, 1))) i++; return i }
{ T = T $0 "\n" }
END {
  N = length(T); i = 1; bad = 0
  while (i <= N && !bad) {
    c = substr(T, i, 1)
    if (index(" \t\n\r{}[],:", c)) { i++; continue }
    if (c == "\"") {
      if (!str(i)) { bad = 1; break }
      key = S; i = ws(POS)
      if (substr(T, i, 1) != ":") continue
      i = ws(i + 1)
      if (key == "$id") { bad = 1; break }
      if (key == "$ref" || key == "$dynamicRef" || key == "$recursiveRef" || key == "$schema") {
        if (substr(T, i, 1) != "\"" || !str(i) || substr(S, 1, 1) != "#") { bad = 1; break }  # a reference that is not local
      }
      continue
    }
    if (index("-0123456789", c)) { while (i <= N && index("-+.eE0123456789", substr(T, i, 1))) i++; continue }
    if (c ~ /[a-z]/) {
      w = ""
      while (i <= N && substr(T, i, 1) ~ /[a-z]/) { w = w substr(T, i, 1); i++ }
      if (w != "true" && w != "false" && w != "null") bad = 1
      continue
    }
    bad = 1
  }
  exit bad
}'

# ---- Shell helpers ----

extract() {
  # $1 = mode, $2 = the file name to print. Reads standard input.
  K8S_FILE=$2 K8S_SHAPES=$SHAPES K8S_REMOTES=$REMOTES awk -v mode="$1" "$EXTRACT"
}

# A file holds a control character or a NUL: it is not text.
# NEL (\302\205), LS, and PS (\342\200\250, \342\200\251) are line breaks
# to a YAML 1.1 reader, so a line the reader takes for a comment can hold a
# key for Kubernetes.
not_text() {  # not text
  sed -n l < "$1" | awk '
    { n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c != "\\") continue
        d = substr($0, i + 1, 1)
        if (d == "\\") { i++; continue }
        if (d ~ /[abfv]/) bad = 1
        if (d ~ /[0-7]/) {
          o = substr($0, i + 1, 3)
          if (o < "040" || o == "177") bad = 1
          if (o == "302" && substr($0, i + 4, 4) == "\\205") bad = 1
          if (o == "342" && (substr($0, i + 4, 8) == "\\200\\250" || substr($0, i + 4, 8) == "\\200\\251")) bad = 1
          i += 3
        }
      } }
    END { exit !bad }'
}

# The path has no symbolic link in any part, and, unless $2 is "dots", no
# ".." part.
plain_path() {
  [ "${2:-}" = dots ] || case "/$1/" in */../*) return 1 ;; esac
  p=$1
  case "$p" in /*) acc=/ ;; *) acc= ;; esac
  rest=${p#/}
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    case "$rest" in */*) rest=${rest#*/} ;; *) rest= ;; esac
    [ -n "$part" ] || continue
    acc="$acc$part"
    [ -L "$acc" ] && return 1
    acc="$acc/"
  done
  return 0
}

# The text holds a control character: C0 or DEL, as LC_ALL=C names them.
has_ctl() {
  case "$1" in *[[:cntrl:]]*) return 0 ;; esac
  return 1
}

# Every path argument passes here before any other work.
no_ctl() {  # a control character in a path argument
  if has_ctl "$1"; then die2 "a path with a control character"; fi
}

# The directory part and the last part of a path, in DIR and BASE. A
# command substitution drops every line break at the end of what it holds,
# so dirname and basename are not used for this.
dir_part() {
  case "$1" in
    */*) DIR=${1%/*}; [ -n "$DIR" ] || DIR=/ ;;
    *) DIR=. ;;
  esac
  BASE=${1##*/}
}

# The physical path of an existing file or directory. A resolved path with a
# control character (for example a repository under a directory whose name
# holds a line break) is not given. The "x" printed after the path keeps a
# line break at the end of the path through the command substitution: a
# path that lost one would be the path of another directory.
phys() {
  if [ -d "$1" ]; then
    DIR=$1; BASE=
  else
    dir_part "$1"
  fi
  r=$(cd -P -- "$DIR" 2>/dev/null && pwd -P && echo x) || return 1
  r=${r%"${NL}x"}  # a line break at the end of a resolved path
  [ -z "$BASE" ] || r="${r%/}/$BASE"
  if has_ctl "$r"; then return 1; fi  # a control character in a resolved path
  printf '%s\n' "$r"
}

# The physical path of $1 with every symbolic link followed, the last part
# included, in RP. Returns 1 when a link does not resolve (its target does
# not exist, or the links loop), 2 when the path holds a control
# character, and 3 when readlink, which prints the target of one link, is
# not installed.
resolve() {
  rp_p=$1; rp_n=0
  while [ -L "$rp_p" ]; do
    rp_n=$((rp_n + 1))
    [ "$rp_n" -le 40 ] || return 1  # links that loop
    command -v readlink >/dev/null 2>&1 || return 3
    rp_t=$(readlink -- "$rp_p" && echo x) || return 1
    rp_t=${rp_t%"${NL}x"}
    [ -n "$rp_t" ] || return 1
    case "$rp_t" in
      /*) rp_p=$rp_t ;;
      *) dir_part "$rp_p"; rp_p="$DIR/$rp_t" ;;
    esac
  done
  [ -e "$rp_p" ] || return 1  # a link whose target does not exist
  if has_ctl "$rp_p"; then return 2; fi
  RP=$(phys "$rp_p") || return 2
}

# The absolute path $1 cleaned the way kustomize cleans a path before it
# follows any link, in LX: each "." part dropped, and each ".." part
# cancelling the part before it.
lexical() {
  lx_rest=$1; LX=
  while [ -n "$lx_rest" ]; do
    lx_part=${lx_rest%%/*}
    case "$lx_rest" in */*) lx_rest=${lx_rest#*/} ;; *) lx_rest= ;; esac
    case "$lx_part" in
      '' | .) ;;
      ..) LX=${LX%/*} ;;
      *) LX="$LX/$lx_part" ;;
    esac
  done
  [ -n "$LX" ] || LX=/
}

# A file or directory in the tree $1 has a line break in its name, which
# no line-by-line test can read with certainty.
nl_inside() {  # a line break in a name
  [ -n "$(find "$1" -name "*$NL*" -print | sed -n 1p)" ]
}

inside_root() {
  # $1 = a physical path
  case "$1" in "$ROOTP" | "$ROOTP"/*) return 0 ;; esac
  return 1
}

git_state() {
  # $1 = a path relative to the list root. A path through a link takes the
  # state of the file it reaches.
  gs=$1
  if resolve "$1" && inside_root "$RP"; then
    gs=${RP#"$ROOTP"}; gs=${gs#/}; [ -n "$gs" ] || gs=.
  fi
  if ! git -C "$LROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo no-git
  elif git -C "$LROOT" ls-files --error-unmatch -- "$gs" >/dev/null 2>&1; then
    echo tracked
  elif git -C "$LROOT" check-ignore -q -- "$gs" 2>/dev/null; then
    echo ignored
  else
    echo untracked
  fi
}

remotes_of() {
  git -C "$1" config --get-regexp '^remote\..*\.url$' 2>/dev/null | sed 's/^[^ ]* //'
}

kfile_in() {
  # $1 = a directory. Prints its kustomization file, or nothing.
  for n in kustomization.yaml kustomization.yml Kustomization; do
    if [ -f "$1/$n" ]; then printf '%s\n' "$1/$n"; return; fi
  done
}

# The paths a kustomization names, one "<field> <path>" line each, read
# with the extractor and never printed. Exit 4 when the file is not read.
# kustomize decodes its own keys as Go structure fields, which match a key
# in any case: the top-level keys of a kustomization, and the keys of an
# item of a list whose items are structures (patches, replacements, and
# generators). So each such key of the lists below is judged by its
# lower-case form, and a kustomization that writes one in another case is
# refused as well. A key under a label, an annotation, or a selector is a
# map key, which kustomize takes as written, and is never judged so.
kust_entries() {
  leaves=$(REMOTES='' extract leaves "" < "$1") || return 4
  printf '%s\n' "$leaves" | awk -F '\t' '
    BEGIN {
      n = split("helmCharts helmGlobals helmChartInflationGenerator generators transformers validators resources bases components crds configurations patchesStrategicMerge patches patchesJson6902 replacements openapi configMapGenerator secretGenerator", w, " ")
      for (i = 1; i <= n; i++) TOP[tolower(w[i])] = w[i]
      n = split("patches patchesStrategicMerge patchesJson6902 replacements helmCharts configMapGenerator secretGenerator", w, " ")
      for (i = 1; i <= n; i++) ITEMS[w[i]] = 1
      n = split("path files envs env", w, " ")
      for (i = 1; i <= n; i++) ITEMKEY[tolower(w[i])] = w[i]
    }
    {
      n = split($2, s, ">"); p = ""
      for (i = 1; i <= n; i++) {
        k = tolower(s[i])
        if (i == 1 && (k in TOP)) s[i] = TOP[k]  # a top-level key
        else if (i == 3 && (s[1] in ITEMS) && s[2] ~ /^#[0-9]+$/ && (k in ITEMKEY)) s[i] = ITEMKEY[k]  # a key of an item that is a structure
        p = (i == 1) ? s[i] : p ">" s[i]
      }
      if (p != $2) { print "bad -"; $2 = p }  # a known key in another case
    }
    $2 ~ /^(helmCharts|helmGlobals|helmChartInflationGenerator|generators|transformers|validators)(>|$)/ { print "plugin -"; next }
    $2 ~ /^((resources|bases|components|crds|configurations|patchesStrategicMerge)>#[0-9]+|(patches|patchesJson6902|replacements)>#[0-9]+>path|openapi>path|(configMapGenerator|secretGenerator)>#[0-9]+>((files|envs)>#[0-9]+|env))$/ && $1 != "scalar" { print "bad -"; next }  # an entry that is not a plain scalar
    $2 ~ /^(resources|bases|components|crds|configurations|patchesStrategicMerge)$/ && $1 != "none" && $1 != "flow" { print "bad -"; next }
    $2 ~ /^(patches|patchesJson6902|replacements|configMapGenerator|secretGenerator)>#[0-9]+$/ && $1 != "none" { print "bad -"; next }  # an item that is not a map
    $1 != "scalar" { next }
    $2 ~ /^(resources|bases|components)>#[0-9]+$/ { print "res " $3; next }
    $2 ~ /^(crds|configurations|patchesStrategicMerge)>#[0-9]+$/ { print "path " $3; next }
    $2 ~ /^(patches|patchesJson6902|replacements)>#[0-9]+>path$/ || $2 == "openapi>path" { print "path " $3; next }
    $2 ~ /^(configMapGenerator|secretGenerator)>#[0-9]+>(files|envs)>#[0-9]+$/ { v = $3; sub(/^[^=]*=/, "", v); print "path " v; next }
    $2 ~ /^(configMapGenerator|secretGenerator)>#[0-9]+>env$/ { print "path " $3; next }
  '
}

# An entry kustomize can take for a repository, whether or not a local
# path of that name exists: an address form, a character no plain local
# path needs, or a first part with a dot (a host) on a path with more parts
# or on a directory. $1 = the entry, $2 = the directory of the kustomization.
repo_like() {
  case "$1" in
    *://* | *//* | *'?'* | *git::* | *gh:* | *_git* | *.git | *.git/* | *@* | *:* | *\\* | /*) return 0 ;;
  esac
  first=${1%%/*}
  case "$first" in . | ..) return 1 ;; esac
  case "$first" in
    *.*) if [ "$first" != "$1" ] || [ -d "$2/$1" ]; then return 0; fi ;;
  esac
  return 1
}

# The directory of a path: "." for a path with no "/".
dir_of() {
  case "$1" in */*) printf '%s\n' "${1%/*}" ;; *) echo . ;; esac
}

# A path as a list line prints it: "./" in front of one that starts with
# "-", so that it is never read as an option.
shown() {
  case "$1" in -*) printf './%s\n' "$1" ;; *) printf '%s\n' "$1" ;; esac
}

# $1 is inside chart $2: under its templates, crds, or charts directory.
in_chart() {
  if [ "$2" = . ]; then
    case "$1" in templates/* | crds/* | charts/*) return 0 ;; esac
  else
    case "$1" in "$2"/templates/* | "$2"/crds/* | "$2"/charts/*) return 0 ;; esac
  fi
  return 1
}

# ---- Modes ----

list_mode() {
  LROOT=$1
  [ -d "$LROOT" ] || die2 "not a directory: $LROOT"
  cd -P -- "$LROOT" || exit 2
  LROOT=.
  ROOTP=$(phys .) || { echo "$me: not read, a control character in the resolved path" >&2; exit 4; }
  # Only paths of letters, digits, and . _ / @ + - are listed, so no path
  # in a list line can split, expand, or hide a line break. Any other path
  # is counted and reported, and the run ends with exit code 4.
  set -f
  unsafe_path='*[!A-Za-z0-9._/@+-]*'
  files=$(find . -name .git -prune -o -type f \( -name '*.yaml' -o -name '*.yml' -o -name Kustomization \) ! -path "$unsafe_path" -print | sed 's#^\./##' | sort)
  unsafe=$(find . -name .git -prune -o -type f \( -name '*.yaml' -o -name '*.yml' -o -name Kustomization \) -path "$unsafe_path" -exec printf . \; | awk '{ n += length($0) } END { print n + 0 }')
  # A symbolic link with such a path, named like a manifest or to a
  # directory, is counted with them.
  ulinks=$(find . -name .git -prune -o -type l -path "$unsafe_path" \( -name '*.yaml' -o -name '*.yml' -o -name Kustomization -o -exec test -d {} \; \) -exec printf . \; | awk '{ n += length($0) } END { print n + 0 }')
  unsafe=$((unsafe + ulinks))
  # Every other symbolic link is followed when it stays inside the list
  # root, and every path that reaches a file inside it is listed at its own
  # path: a file link by its own path, and a directory link with its path
  # in front of each file under the directory it reaches, the links there
  # included. Only a directory loop stops the descent. A link that points
  # outside the root, or does not resolve, is not read and gets a link line.
  links=$(find . -name .git -prune -o \( -type l ! -path "$unsafe_path" \) -print | sed 's#^\./##' | sort)  # a link the list can carry
  if [ -n "$links" ] && ! command -v readlink >/dev/null 2>&1; then  # no readlink
    echo "$me: not listed: the tree holds a symbolic link, and readlink, which the reader needs to follow one, is not installed" >&2
    exit 4
  fi
  recs=
  for l in $links; do
    named=0
    case "${l##*/}" in *.yaml | *.yml | Kustomization) named=1 ;; esac
    rs=0
    resolve "$l" || rs=$?
    if [ "$rs" -eq 2 ]; then
      if [ "$named" -eq 1 ] || [ -d "$l" ]; then unsafe=$((unsafe + 1)); fi
      continue
    fi
    if [ "$rs" -ne 0 ]; then
      [ "$named" -eq 0 ] || recs="${recs}B$TAB$l$NL"
      continue
    fi
    if ! inside_root "$RP"; then  # a link that points outside the list root
      if [ "$named" -eq 1 ] || [ -d "$RP" ]; then recs="${recs}O$TAB$l$NL"; fi
      continue
    fi
    rel=${RP#"$ROOTP"}; rel=${rel#/}; [ -n "$rel" ] || rel=.
    if [ -d "$RP" ]; then
      recs="${recs}D$TAB$l$TAB$rel$NL"
    elif [ "$named" -eq 1 ]; then
      recs="${recs}F$TAB$l$NL"
    fi
  done
  # The paths, from the file list and the link records on standard input,
  # with a line ":" between them, which no listed path can be.
  lpaths=$({ printf '%s\n' "$files"; echo ':'; printf '%s' "$recs"; } | awk -F "$TAB" -v t="$TAB" '
    function anc(a, d) { return a == "." || d == a || substr(d, 1, length(a) + 1) == a "/" }
    function first(A, n, key,    lo, hi, m) {
      lo = 1; hi = n + 1
      while (lo < hi) { m = int((lo + hi) / 2); if ((A[m] "") < key) lo = m + 1; else hi = m }
      return lo
    }
    function dirof(p,    i) { i = match(p, /\/[^\/]*$/); return i ? substr(p, 1, i - 1) : "." }
    function shown(p) { return (substr(p, 1, 1) == "-") ? "./" p : p }
    function emit(line) { if (++NOUT > 200000) { MANY = 1; return 0 } print line; return 1 }
    function link(j, p) {
      if (LK[j] == "F") return emit("f" t p)  # a file link at its own path
      if (LK[j] == "O") return emit("l" t shown(p) ":link:points outside the repository, not read")
      if (LK[j] == "B") return emit("l" t shown(p) ":link:broken, not read")
      return expand(p, LT[j], DIRS[j], 1)
    }
    # The files and links under the directory a, with the path p in front.
    function expand(p, a, chain, depth,    n, c, i, key, r) {
      n = split(chain, c, SUBSEP)
      for (i = 1; i <= n; i++) if (anc(a, c[i])) return 1  # a directory loop
      if (depth > 40) return 1
      key = (a == ".") ? "" : a "/"
      for (i = first(F, NF_, key); i <= NF_ && substr(F[i], 1, length(key)) == key; i++)
        if (!emit("f" t p "/" substr(F[i], length(key) + 1))) return 0
      for (i = first(LP, NLK, key); i <= NLK && substr(LP[i], 1, length(key)) == key; i++) {
        r = substr(LP[i], length(key) + 1)
        if (LK[i] == "D") { if (!expand(p "/" r, LT[i], chain SUBSEP DIRS[i], depth + 1)) return 0 }
        else if (!link(i, p "/" r)) return 0
      }
      return 1
    }
    BEGIN { part = 1 }
    part == 1 && $0 == ":" { part = 2; next }
    part == 1 { if ($0 != "") F[++NF_] = $0; next }
    $0 != "" {
      NLK++; LK[NLK] = $1; LP[NLK] = $2; LT[NLK] = $3
      DIRS[NLK] = dirof($2)
    }
    END {
      for (i = 1; i <= NF_; i++) if (!emit("f" t F[i])) break
      for (j = 1; j <= NLK && !MANY; j++) link(j, LP[j])
      if (MANY) exit 3
    }') || { echo "$me: not listed: the links of the tree reach more than 200000 paths" >&2; exit 4; }
  files=$(printf '%s\n' "$lpaths" | awk -F "$TAB" '$1 == "f" { print $2 }' | sort -u)
  llines=$(printf '%s\n' "$lpaths" | awk -F "$TAB" '$1 == "l" { print $2 }' | sort -u)
  [ -z "$llines" ] || llines="$llines$NL"
  charts=
  for f in $files; do
    case "$f" in Chart.yaml) charts="$charts ." ;; */Chart.yaml) charts="$charts ${f%/Chart.yaml}" ;; esac
  done
  # A chart under another chart's templates, crds, or charts is not listed.
  top=
  for c in $charts; do
    sub=0
    for o in $charts; do
      if [ "$o" != "$c" ] && in_chart "$c/Chart.yaml" "$o"; then sub=1; fi
    done
    [ "$sub" -eq 1 ] || top="$top $c"
  done
  kdirs=
  for f in $files; do
    case "${f##*/}" in kustomization.yaml | kustomization.yml | Kustomization) ;; *) continue ;; esac
    skip=0
    for c in $top; do if in_chart "$f" "$c"; then skip=1; fi; done
    [ "$skip" -eq 1 ] || kdirs="$kdirs $(dir_of "$f")"
  done
  kdirs=$(for kd in $kdirs; do printf '%s\n' "$kd"; done | sort -u)
  bases=$(for kd in $kdirs; do
    kf=$(kfile_in "$kd")
    [ -n "$kf" ] || continue
    entries=$(kust_entries "$kf") || continue
    printf '%s\n' "$entries" | while IFS=' ' read -r what target; do
      [ "$what" = res ] || continue
      if repo_like "$target" "$kd"; then continue; fi
      t="$kd/$target"
      [ -d "$t" ] || continue
      pp=$(phys "$t") || continue
      inside_root "$pp" || continue
      rel=${pp#"$ROOTP"}; rel=${rel#/}; [ -n "$rel" ] || rel=.
      [ -n "$(kfile_in "$t")" ] && printf '%s\n' "$rel"
    done
  done | sort -u)
  {
    for c in $top; do
      printf '%s:chart:%s\n' "$(shown "$c")" "$(git_state "$c/Chart.yaml")"
    done
    for kd in $kdirs; do
      kf=$(kfile_in "$kd")
      [ -n "$kf" ] || continue
      kind=overlay
      kr=$(phys "$kd") || continue
      kr=${kr#"$ROOTP"}; kr=${kr#/}; [ -n "$kr" ] || kr=.
      if printf '%s\n' "$bases" | grep -qxF -e "$kr"; then kind=kustomize-base; fi
      printf '%s:%s:%s\n' "$(shown "$kd")" "$kind" "$(git_state "$kf")"
    done
    for f in $files; do
      base=${f##*/}
      case "$base" in kustomization.yaml | kustomization.yml | Kustomization | Chart.yaml) continue ;; esac
      skip=0; home=
      for c in $top; do
        if in_chart "$f" "$c"; then skip=1; fi
        [ "$(dir_of "$f")" = "$c" ] && home=$c
      done
      [ "$skip" -eq 0 ] || continue
      kind=
      if [ -n "$home" ]; then
        case "$base" in values*.yaml | values*.yml) kind='chart-values' ;; esac
      fi
      # A top-level key may be written bare, in double quotes, or in single
      # quotes: the same forms --fields reads (keyline).
      if [ -z "$kind" ] && grep -Eq -- '^(kind|"kind"|'"'"'kind'"'"'):' "$f" &&  # a quoted top-level key
        grep -Eq -- '^(apiVersion|"apiVersion"|'"'"'apiVersion'"'"'):' "$f"; then
        if grep -Eq -- '^(kind|"kind"|'"'"'kind'"'"'):[[:space:]]*["'"'"']?(Application|ApplicationSet)["'"'"']?[[:space:]]*$' "$f" &&
          grep -Eq -- '^(apiVersion|"apiVersion"|'"'"'apiVersion'"'"'):[[:space:]]*["'"'"']?argoproj\.io/' "$f"; then
          kind=argo-application
        else
          kind=manifest
        fi
      elif [ -z "$kind" ]; then
        case "$base" in values*.yaml | values*.yml) kind='chart-values' ;; esac
      fi
      [ -n "$kind" ] && printf '%s:%s:%s\n' "$(shown "$f")" "$kind" "$(git_state "$f")"
    done
    printf '%s' "$llines"
  } | sort
  if [ "$unsafe" -gt 0 ]; then
    echo "$me: not listed: $unsafe paths with a character other than letters, digits, and . _ / @ + -, or with a line break" >&2
    exit 4
  fi
}

read_file_mode() {
  # $1 = fields or values, $2 = the file
  f=$2
  if [ -L "$f" ] && [ ! -e "$f" ]; then
    echo "$me: not read, a symbolic link that does not resolve: $f" >&2
    exit 4
  fi
  [ -f "$f" ] || die2 "not a file: $f"
  ROOTP=$(phys .) || { echo "$me: not read, a control character in the resolved path" >&2; exit 4; }  # the root of the list
  rs=0
  resolve "$f" || rs=$?
  if [ "$rs" -eq 2 ]; then
    echo "$me: not read, a path with a control character once its links are followed: $f" >&2
    exit 4
  fi
  if [ "$rs" -eq 3 ]; then
    echo "$me: not read, a symbolic link, and readlink is not installed: $f" >&2
    exit 4
  fi
  if [ "$rs" -ne 0 ] || ! inside_root "$RP"; then  # a path that leaves the repository
    echo "$me: not read, a path that leads outside the repository: $f" >&2
    exit 4
  fi
  rf=$RP
  if not_text "$rf"; then
    echo "$me: not read, not a text file: $f" >&2
    exit 4
  fi
  dir_part "$f"; REMOTES=$(remotes_of "$DIR")  # the directory of the file, with a line break at its end
  status=0
  extract "$1" "$f" < "$rf" || status=$?
  if [ "$status" -eq 5 ]; then
    echo "$me: not read, a List kind, whose objects the reader does not follow: $f" >&2
    exit 4
  fi
  if [ "$status" -ne 0 ]; then
    echo "$me: not read, a layout the reader cannot place: $f" >&2
    exit 4
  fi
}

refuse() {
  # $1 = state. Prints the refusal line and stops.
  printf '%s:%s:%s\n' "$label" "$rkind" "$1"
  exit 3
}

# The top of the repository the reader runs in, or the working directory
# where there is none. The "x" keeps a line break at its end, as in phys.
repo_top() {
  top=$(git rev-parse --show-toplevel 2>/dev/null && echo x) || top=$(pwd && echo x)
  top=${top%"${NL}x"}  # a line break at the end of the repository root
  ROOTP=$(phys "$top")
}

set_root() {
  repo_top || refuse "not a local file"
}

local_ok() {
  # $1 = a path, $2 = d or f. The path is local, has no ".." part, and
  # with its links followed is inside the repository; its physical path
  # is then in RP. Returns 3 when a link takes it outside.
  [ -e "$1" ] || return 1
  case "/$1/" in */../*) return 1 ;; esac
  if [ "$2" = d ]; then [ -d "$1" ] || return 1; else [ -f "$1" ] || return 1; fi
  resolve "$1" || return 1
  inside_root "$RP" && return 0
  if plain_path "$1" dots; then return 1; fi
  return 3
}

# The render stops unless $1 is local and inside the repository.
need_local() {
  nl_s=0
  local_ok "$1" "$2" || nl_s=$?
  [ "$nl_s" -ne 3 ] || refuse "points outside the repository, not read"  # a path a link takes outside the repository
  [ "$nl_s" -eq 0 ] || refuse "not a local file"
}

# The physical directories a render reads: the tree $1 and every
# directory that a symbolic link in it reaches, one on each line, in
# TREE_DIRS. Every link has to resolve inside the repository: a link that
# points outside it, or does not resolve, stops the render.
tree_dirs() {
  td_queue=$1; TREE_DIRS=
  while [ -n "$td_queue" ]; do
    td_d=$(printf '%s\n' "$td_queue" | sed -n 1p)
    td_queue=$(printf '%s\n' "$td_queue" | sed 1d)
    if printf '%s\n' "$TREE_DIRS" | grep -qxF -e "$td_d"; then continue; fi
    TREE_DIRS="$TREE_DIRS$td_d$NL"
    if nl_inside "$td_d"; then refuse "not a local file"; fi
    td_links=$(find "$td_d" -type l -print)
    while IFS= read -r td_l; do
      [ -n "$td_l" ] || continue
      td_s=0
      resolve "$td_l" || td_s=$?
      [ "$td_s" -ne 1 ] || refuse "broken, not read"  # a link that does not resolve
      [ "$td_s" -eq 0 ] || refuse "not a local file"
      inside_root "$RP" || refuse "points outside the repository, not read"  # a link in the tree that leaves the repository
      if [ -d "$RP" ]; then td_queue="$td_queue$NL$RP"; fi  # a directory a link reaches
    done <<TREE
$td_links
TREE
  done
}

render_helm() {
  chart=${1%/}; shift
  label=$chart; rkind=chart
  ns=default
  vals=
  while [ $# -gt 0 ]; do
    case "$1" in
      --namespace)
        [ $# -ge 2 ] || die2 "--namespace needs a name"
        ns=$2; shift
        ;;
      -*) die2 "unknown option: $1" ;;
      *) vals="$vals
$1" ;;
    esac
    shift
  done
  [ -n "$vals" ] || die2 "--render helm needs a chart and a values file"
  printf '%s\n' "$ns" | grep -Eqx '([a-z]|[a-z][-a-z0-9]*[a-z0-9])' && [ ${#ns} -le 63 ] || die2 "the namespace is not a DNS label"
  command -v helm >/dev/null 2>&1 || refuse "tool not installed"
  set_root
  need_local "$chart" d
  need_local "$chart/Chart.yaml" f
  vlist=$(printf '%s\n' "$vals" | sed '/^$/d')
  nv=0
  for v in $vlist; do
    need_local "$v" f
    nv=$((nv + 1))
  done
  [ "$nv" -le 2 ] || die2 "--render helm takes one or two values files"
  cp_=$(phys "$chart")
  tree_dirs "$cp_"  # the resolved chart path
  # A schema with a reference that is not local, or with an $id, is
  # refused, with its JSON escapes decoded first, since an escape can spell
  # $ref. So is a schema the test cannot read as JSON.
  if [ -n "$(printf '%s' "$TREE_DIRS" | while IFS= read -r td; do find "$td" \( -type f -o -type l \) -name values.schema.json -print; done | while IFS= read -r sf; do awk "$SCHEMA" < "$sf" || { echo bad; break; }; done)" ]; then
    refuse "remote schema ref"
  fi
  deps=$(printf '%s' "$TREE_DIRS" | while IFS= read -r td; do find "$td" \( -name Chart.yaml -o -name requirements.yaml \) \( -type f -o -type l \) -print; done | while IFS= read -r cf; do
    cdir=$(dirname -- "$cf")
    leaves=$(REMOTES='' extract leaves "" < "$cf") || { echo bad; break; }
    items=$(printf '%s\n' "$leaves" | awk -F '\t' '$2 ~ /^dependencies>#[0-9]+$/ { n++ } tolower($2) ~ /^dependencies(>|$)/ && $2 !~ /^dependencies(>|$)/ { n = -1; exit } END { print n + 0 }')  # dependencies in another case
    names=$(printf '%s\n' "$leaves" | awk -F '\t' '$1 == "scalar" && $2 ~ /^dependencies>#[0-9]+>name$/ { print $3 }')
    [ "$(printf '%s\n' "$names" | awk 'NF { n++ } END { print n + 0 }')" -eq "$items" ] || { echo bad; break; }
    printf '%s\n' "$names" | while IFS= read -r dn; do
      [ -n "$dn" ] || continue
      printf '%s\n' "$dn" | grep -Eqx '[A-Za-z0-9][A-Za-z0-9_.-]*' || { echo bad; break; }
      case "$dn" in *..*) echo bad; break ;; esac
      [ -d "$cdir/charts/$dn" ] && continue
      found=0
      for t in "$cdir/charts/$dn"-*.tgz; do [ -f "$t" ] && found=1; done
      [ "$found" -eq 1 ] || { echo bad; break; }
    done
  done)
  [ -z "$deps" ] || refuse "dependencies not vendored"
  release=$(basename -- "$(phys "$chart")")
  printf '%s\n' "$release" | grep -Eqx '([a-z]|[a-z][-a-z0-9]*[a-z0-9])' && [ ${#release} -le 53 ] || release=release
  set -- template "$release" "$cp_" --skip-schema-validation
  for v in $vlist; do resolve "$v"; set -- "$@" --values "$RP"; done
  set -- "$@" --namespace "$ns"
  REMOTES=$(remotes_of "$ROOTP")
  status=0
  rendered=$(cd "$ROOTP" && env -i PATH="$PATH" HOME=/nonexistent LC_ALL=C helm "$@" 2>/dev/null) || status=$?  # helm: drop standard error
  if [ "$status" -ne 0 ]; then
    echo "$me: helm template exited with status $status" >&2
    refuse "render failed"
  fi
  emit_render
}

render_kustomize() {
  dir=${1%/}
  label=$dir; rkind=overlay
  if command -v kustomize >/dev/null 2>&1; then
    tool=kustomize
  elif command -v kubectl >/dev/null 2>&1; then
    tool=kubectl
  else
    refuse "tool not installed"
  fi
  set_root
  need_local "$dir" d
  [ -n "$(kfile_in "$dir")" ] || refuse "not a local file"
  queue=$(phys "$dir") || refuse "not a local file"
  seen=
  while [ -n "$queue" ]; do
    d=$(printf '%s\n' "$queue" | sed -n 1p)
    queue=$(printf '%s\n' "$queue" | sed 1d)
    [ -d "$d" ] || refuse "not a local file"  # a queue entry that does not exist
    if printf '%s\n' "$seen" | grep -qxF -e "$d"; then continue; fi
    seen="$seen
$d"
    tree_dirs "$d"
    kf=$(kfile_in "$d")
    [ -n "$kf" ] || continue
    entries=$(kust_entries "$kf") || {
      echo "$me: not read, a layout the reader cannot place: $label" >&2
      printf '%s:%s:%s\n' "$label" "$rkind" "not read"
      exit 4
    }
    if printf '%s\n' "$entries" | grep -q '^plugin '; then refuse "plugin or inflator needed"; fi
    if printf '%s\n' "$entries" | grep -q '^bad '; then refuse "remote base"; fi
    while IFS=' ' read -r what target; do
      [ -n "$what" ] || continue
      if repo_like "$target" "$d"; then refuse "remote base"  # an entry kustomize can take for a repository
      fi
      t="$d/$target"
      rest=$target; acc=$d; via=0; dang=0
      while [ -n "$rest" ]; do
        part=${rest%%/*}
        case "$rest" in */*) rest=${rest#*/} ;; *) rest= ;; esac
        [ -n "$part" ] || continue
        acc="$acc/$part"
        if [ -L "$acc" ]; then via=1; [ -e "$acc" ] || dang=1; fi
      done
      [ "$dang" -eq 0 ] || refuse "broken, not read"  # an entry through a link that does not resolve
      [ -e "$t" ] || refuse "remote base"
      # The entry is tested twice: with its links followed first (cd -P),
      # and cleaned first, the way kustomize reads it. Either one outside
      # the repository refuses the render.
      resolve "$t" || refuse "remote base"
      pp=$RP
      lexical "$t"  # the path as kustomize cleans it
      [ -e "$LX" ] || refuse "remote base"
      resolve "$LX" || refuse "remote base"
      lp=$RP
      for ep in "$pp" "$lp"; do
        if ! inside_root "$ep"; then
          [ "$via" -eq 0 ] || refuse "points outside the repository, not read"  # an entry through a link that leaves the repository
          refuse "remote base"  # a base outside the repository
        fi
      done
      if [ "$what" = res ] && [ -d "$t" ]; then
        queue=$(printf '%s\n%s\n%s\n' "$queue" "$pp" "$lp" | sed '/^$/d')
      fi
    done <<EOF
$entries
EOF
  done
  REMOTES=$(remotes_of "$ROOTP")
  dp=$(phys "$dir")
  status=0
  if [ "$tool" = kustomize ]; then
    rendered=$(cd "$ROOTP" && env -i PATH="$PATH" HOME=/nonexistent LC_ALL=C kustomize build "$dp" 2>/dev/null) || status=$?  # kustomize: drop standard error
  else
    rendered=$(cd "$ROOTP" && env -i PATH="$PATH" HOME=/nonexistent LC_ALL=C kubectl kustomize "$dp" 2>/dev/null) || status=$?  # kubectl: drop standard error
  fi
  if [ "$status" -ne 0 ]; then
    echo "$me: $tool exited with status $status" >&2
    refuse "render failed"
  fi
  emit_render
}

emit_render() {
  # The rendered text goes into the extractor and nowhere else.
  printf '%s\n' "$rendered" | extract render "$label"  # the pipe
  status=$?
  if [ "$status" -eq 3 ]; then
    echo "$me: the render printed no object the reader reads: $label" >&2
    refuse "render printed nothing"
  fi
  if [ "$status" -ne 0 ]; then
    echo "$me: not read, the rendered output has a layout the reader cannot place: $label" >&2
    printf '%s:%s:%s\n' "$label" "$rkind" "not read"
    exit 4
  fi
}

# ---- Arguments ----

for arg in "$@"; do no_ctl "$arg"; done

[ $# -gt 0 ] || { list_mode .; exit 0; }
case "$1" in
  -h | --help) usage; exit 0 ;;
  --fields | --values)
    [ $# -eq 2 ] || die2 "$1 needs one file"
    read_file_mode "${1#--}" "$2"
    ;;
  --render)
    [ $# -ge 2 ] || die2 "--render needs helm or kustomize"
    case "$2" in
      helm)
        [ $# -ge 4 ] || die2 "--render helm needs a chart and a values file"
        shift 2
        render_helm "$@"
        ;;
      kustomize)
        [ $# -eq 3 ] || die2 "--render kustomize needs one directory"
        render_kustomize "$3"
        ;;
      *) die2 "--render takes helm or kustomize" ;;
    esac
    ;;
  -*) die2 "unknown option: $1" ;;
  *)
    [ $# -eq 1 ] || die2 "one path only"
    list_mode "$1"
    ;;
esac
