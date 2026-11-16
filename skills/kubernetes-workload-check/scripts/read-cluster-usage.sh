#!/bin/sh
# read-cluster-usage.sh: run the fixed read commands of the cluster pass, and
# print measured CPU and memory next to the requests, limits, restarts, and a
# VerticalPodAutoscaler's recommendation, for the namespaces it is given.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   sh read-cluster-usage.sh --context                print the current context name,
#                                                     with no request to the cluster
#   sh read-cluster-usage.sh NAMESPACE [NAMESPACE ...]
#                                                     print one table for each namespace
#
# Exit codes: 0 success, 2 wrong usage or an argument that is not a namespace
# name, 5 kubectl missing or no current context, 6 no metrics.
#
# It runs only the commands of the fixed list below (references/fields.md,
# "Command section 3: the cluster commands"), with a cleared environment,
# and drops what kubectl writes to standard error. It never reads a Secret
# and never writes. It takes no command from its arguments: only namespace
# names, each tested as a DNS label before any other work. No line of
# kubectl output prints as it came: a cell prints when it fits its shape,
# and as "other" when it does not; a value that cannot be placed on one
# container prints "not-read"; a row that cannot be placed is counted.

set -u
LC_ALL=C
export LC_ALL
# Split the words of a fixed command at a space, a tab, or a line break,
# whatever the caller had.
IFS=$(printf ' \t\nx')
IFS=${IFS%x}

me=read-cluster-usage

# BEGIN the fixed command list
CMD_CONTEXT='kubectl config current-context'
CMD_TOP='kubectl top pod --containers --namespace=<name> --no-headers --request-timeout=20s'
CMD_PODS='kubectl get pods --namespace=<name> --no-headers --request-timeout=20s -o custom-columns=POD:.metadata.name,CONTAINERS:.spec.containers[*].name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory,STATUS_NAMES:.status.containerStatuses[*].name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_END:.status.containerStatuses[*].lastState.terminated.reason'
CMD_VPA='kubectl get verticalpodautoscalers.autoscaling.k8s.io --namespace=<name> --no-headers --request-timeout=20s -o custom-columns=VPA:.metadata.name,TARGET_KIND:.spec.targetRef.kind,TARGET:.spec.targetRef.name,MODE:.spec.updatePolicy.updateMode,RECO_CONTAINER:.status.recommendation.containerRecommendations[*].containerName,CPU_TARGET:.status.recommendation.containerRecommendations[*].target.cpu,MEM_TARGET:.status.recommendation.containerRecommendations[*].target.memory,CPU_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.cpu,MEM_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.memory,CPU_UPPER:.status.recommendation.containerRecommendations[*].upperBound.cpu,MEM_UPPER:.status.recommendation.containerRecommendations[*].upperBound.memory'
CMD_HPA='kubectl get horizontalpodautoscalers.autoscaling --namespace=<name> --no-headers --request-timeout=20s -o custom-columns=HPA:.metadata.name,TARGET_KIND:.spec.scaleTargetRef.kind,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,METRIC_TYPE:.spec.metrics[*].type,METRIC:.spec.metrics[*].resource.name,UTILIZATION:.spec.metrics[*].resource.target.averageUtilization'
# END the fixed command list

# The shape block of the cluster script in references/fields.md: id,
# maximum length, pattern. It reaches awk through the environment, so that
# no copy of awk rewrites a backslash in it.
SHAPES='
int 10 ^[0-9]+$
qty-cpu 12 ^([0-9]+|[0-9]+\.[0-9]+|[0-9]+m)$
qty-mem 16 ^[0-9]+(\.[0-9]+)?(E|P|T|G|M|k|Ei|Pi|Ti|Gi|Mi|Ki|m)?$
dns-label 63 ^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$
dns-subdomain 253 ^([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])$
kind-name 63 ^[A-Z][A-Za-z0-9]*$
update-mode 17 ^(Off|Initial|Recreate|Auto|InPlaceOrRecreate|InPlace)$
metric-type 18 ^(ContainerResource|External|Object|Pods|Resource)$
metric-resource 6 ^(cpu|memory)$
context-name 253 ^[A-Za-z0-9][A-Za-z0-9_.:@/+-]*$
end-reason 22 ^(OOMKilled|Error|Completed|ContainerCannotRun|DeadlineExceeded|StartError|ContainerStatusUnknown)$
'
export SHAPES

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

die() { echo "$me: $2" >&2; exit "$1"; }

# A namespace name: lower case letters, digits, and -, at most 63
# characters, starting and ending with a letter or a digit. Anything else,
# a control character and a trailing line break included, fails.
is_ns() {  # a namespace is a DNS label
  case $1 in
    '' | -* | *- | *[!a-z0-9-]*) return 1 ;;  # no dash at either end
  esac
  [ "${#1}" -le 63 ]  # at most 63 characters
}

# Run one command of the fixed list. $1 = the command, $2 = the namespace
# that replaces <name>. The command's words hold no space and no glob that
# could expand, and the namespace passed is_ns.
kube() {
  c=$1
  case $c in *'<name>'*) c=${c%%'<name>'*}$2${c#*'<name>'} ;; esac
  set -f
  # shellcheck disable=SC2086 # the words of a fixed command
  set -- $c
  set +f
  if [ -n "${KUBECONFIG-}" ]; then set -- "KUBECONFIG=$KUBECONFIG" "$@"; fi
  env -i PATH="$PATH" HOME="${HOME-}" KUBERC=off LC_ALL=C "$@" 2>/dev/null  # kubectl: a cleared environment
}

# The awk program that prints the tables of one namespace. Its input is
# the output of each command, every line led by a tag: T for top, P for
# pods, V for VPAs, and H for HPAs, with an X after it for a line with a
# control character. A line of kubectl output can never carry another tag,
# because the tag is added in front of every line.
table() {
  awk -v pods="$1" -v vpa="$2" -v hpa="$3" '
function load(   n, L, i, p1, p2, id, rest) {
  n = split(ENVIRON["SHAPES"], L, "\n")
  for (i = 1; i <= n; i++) {
    if (L[i] == "") continue
    p1 = index(L[i], " "); id = substr(L[i], 1, p1 - 1); rest = substr(L[i], p1 + 1)
    p2 = index(rest, " "); MAX[id] = substr(rest, 1, p2 - 1) + 0; PAT[id] = substr(rest, p2 + 1)
  }
}
function fits(v, id) {
  return (id in MAX) && length(v) <= MAX[id] && v ~ PAT[id]
}
function cell(v, id) {
  if (v == "<none>") return "-"
  return fits(v, id) ? v : "other"
}
# Spread a column of comma-joined values over nc items. OUT[1..nc] gets
# each value in its shape, "-" for all when the column is <none>, and
# "not-read" for all when the count differs.
function spread(s, nc, id,   a, n, j) {
  if (s == "<none>") { for (j = 1; j <= nc; j++) OUT[j] = "-"; return }
  n = split(s, a, ",")
  if (n == nc)  # one value for each container
    for (j = 1; j <= nc; j++) OUT[j] = cell(a[j], id)
  else
    for (j = 1; j <= nc; j++) OUT[j] = "not-read"
}
function spread_vpa(s, nc, id,   a, n, j) {
  if (s == "<none>") { for (j = 1; j <= nc; j++) OUT[j] = "-"; return }
  n = split(s, a, ",")
  if (n == nc)  # one value for each recommendation
    for (j = 1; j <= nc; j++) OUT[j] = cell(a[j], id)
  else
    for (j = 1; j <= nc; j++) OUT[j] = "not-read"
}
function spread_hpa(s, nc, id,   a, n, j) {
  if (s == "<none>") { for (j = 1; j <= nc; j++) OUT[j] = "-"; return }
  n = split(s, a, ",")
  if (n == nc)  # one value for each metric
    for (j = 1; j <= nc; j++) OUT[j] = cell(a[j], id)
  else
    for (j = 1; j <= nc; j++) OUT[j] = "not-read"
}
BEGIN { load(); NT = NP = NV = NH = 0; NT_BAD = NP_BAD = NV_BAD = NH_BAD = 0 }
$1 == "TX" { NT_BAD++; next }
$1 == "PX" { NP_BAD++; next }
$1 == "VX" { NV_BAD++; next }
$1 == "HX" { NH_BAD++; next }
$1 == "T" {
  if (NF == 1) next
  if (NF != 5) { NT_BAD++; next }  # a top row with another number of columns
  k = $2 SUBSEP $3
  if (k in TC) TD[k] = 1
  TC[k] = $4; TM[k] = $5
  NT++; TK[NT] = k; TP[NT] = $2; TN[NT] = $3
  next
}
$1 == "P" {
  if (NF == 1) next
  if (NF != 10) { NP_BAD++; next }  # a pod row with another number of columns
  NP++
  for (i = 2; i <= 10; i++) PF[NP, i] = $i
  PODS[$2]++
  next
}
$1 == "V" {
  if (NF == 1) next
  if (NF != 12) { NV_BAD++; next }
  NV++
  for (i = 2; i <= 12; i++) VF[NV, i] = $i
  next
}
$1 == "H" {
  if (NF == 1) next
  if (NF != 11) { NH_BAD++; next }
  NH++
  for (i = 2; i <= 11; i++) HF[NH, i] = $i
  next
}
END {
  print "# container POD CONTAINER CPU_REQ CPU_LIM MEM_REQ MEM_LIM CPU_USED MEM_USED RESTARTS POD_LAST_END"
  if (pods == "failed") print "# pods: not read, the command failed"
  else if (NP == 0 && NP_BAD == 0) print "# pods: none in this namespace"
  for (i = 1; i <= NP; i++) {
    if (PODS[PF[i, 2]] > 1) { NP_BAD++; continue }  # a pod row twice
    if (PF[i, 3] == "<none>") { NP_BAD++; continue }
    nc = split(PF[i, 3], c, ",")
    split("", CN); dup = 0
    for (j = 1; j <= nc; j++) { if (c[j] in CN) dup = 1; CN[c[j]] = j }
    if (nc == 0 || dup) { NP_BAD++; continue }
    spread(PF[i, 4], nc, "qty-cpu"); for (j = 1; j <= nc; j++) CR[j] = OUT[j]
    spread(PF[i, 5], nc, "qty-mem"); for (j = 1; j <= nc; j++) MR[j] = OUT[j]
    spread(PF[i, 6], nc, "qty-cpu"); for (j = 1; j <= nc; j++) CL[j] = OUT[j]
    spread(PF[i, 7], nc, "qty-mem"); for (j = 1; j <= nc; j++) ML[j] = OUT[j]
    # Restarts, matched to a container by status name.
    for (j = 1; j <= nc; j++) RST[j] = "-"
    if (!(PF[i, 8] == "<none>" && PF[i, 9] == "<none>")) {
      ns_ = split(PF[i, 8], sn, ","); nr = split(PF[i, 9], rr, ",")
      ok = (ns_ == nr && PF[i, 8] != "<none>")
      split("", SEEN)
      for (m = 1; m <= ns_ && ok; m++) {
        if (sn[m] in SEEN) ok = 0
        SEEN[sn[m]] = 1
        if (!(sn[m] in CN)) ok = 0  # a status name that matches no container
      }
      for (j = 1; j <= nc; j++) {
        if (!ok) { RST[j] = "not-read"; continue }
        hit = 0; at = 0
        for (m = 1; m <= ns_; m++) if (sn[m] == c[j]) { hit++; at = m }  # restarts by status name
        if (hit == 1) RST[j] = cell(rr[at], "int")
      }
    }
    # The last termination reason, for the pod as a whole.
    le = "-"
    if (PF[i, 10] != "<none>") {
      n = split(PF[i, 10], a, ","); le = ""; split("", LS)
      for (m = 1; m <= n; m++) {
        w = cell(a[m], "end-reason")
        if (w in LS) continue
        LS[w] = 1; le = (le == "" ? w : le "," w)
      }
    }
    for (j = 1; j <= nc; j++) {
      k = PF[i, 2] SUBSEP c[j]
      mc = mm = "-"
      if (k in TC) { mc = cell(TC[k], "qty-cpu"); mm = cell(TM[k], "qty-mem"); USED[k] = 1 }
      if (k in TD) mc = mm = "not-read"  # a top row twice
      print "container", cell(PF[i, 2], "dns-subdomain"), cell(c[j], "dns-label"), CR[j], CL[j], MR[j], ML[j], mc, mm, RST[j], le
    }
  }
  # A top row with no pod row prints its measured values, and not-read for
  # the rest. A pod row that was not placed takes its top rows with it.
  for (t = 1; t <= NT; t++) {
    k = TK[t]
    if ((k in USED) || (k in DONE)) continue
    DONE[k] = 1
    if (PODS[TP[t]] > 0 && pods != "failed") { NT_BAD++; continue }
    mc = cell(TC[k], "qty-cpu"); mm = cell(TM[k], "qty-mem")
    if (k in TD) mc = mm = "not-read"
    print "container", cell(TP[t], "dns-subdomain"), cell(TN[t], "dns-label"), "not-read", "not-read", "not-read", "not-read", mc, mm, "not-read", "not-read"  # a top row with no pod row
  }

  print "# vpa VPA TARGET_KIND TARGET MODE CONTAINER CPU_TARGET MEM_TARGET CPU_LOWER MEM_LOWER CPU_UPPER MEM_UPPER"
  if (vpa == "failed") print "# vpa: not read, the command failed (the type may not be installed)"  # a failed command leaves a trace
  else if (NV == 0 && NV_BAD == 0) print "# vpa: none in this namespace"
  for (i = 1; i <= NV; i++) {
    head = "vpa " cell(VF[i, 2], "dns-subdomain") " " cell(VF[i, 3], "kind-name") " " cell(VF[i, 4], "dns-subdomain") " " cell(VF[i, 5], "update-mode")
    if (VF[i, 6] == "<none>") { print head, "-", "-", "-", "-", "-", "-", "-"; continue }
    nc = split(VF[i, 6], c, ",")
    for (col = 7; col <= 12; col++) {
      spread_vpa(VF[i, col], nc, (col % 2 == 1) ? "qty-cpu" : "qty-mem")
      for (j = 1; j <= nc; j++) V[col, j] = OUT[j]
    }
    for (j = 1; j <= nc; j++)
      print head, cell(c[j], "dns-label"), V[7, j], V[8, j], V[9, j], V[10, j], V[11, j], V[12, j]
  }

  print "# hpa HPA TARGET_KIND TARGET MIN MAX CURRENT DESIRED METRIC_TYPE METRIC UTILIZATION"
  if (hpa == "failed") print "# hpa: not read, the command failed"
  else if (NH == 0 && NH_BAD == 0) print "# hpa: none in this namespace"
  for (i = 1; i <= NH; i++) {
    head = "hpa " cell(HF[i, 2], "dns-subdomain") " " cell(HF[i, 3], "kind-name") " " cell(HF[i, 4], "dns-subdomain")
    head = head " " cell(HF[i, 5], "int") " " cell(HF[i, 6], "int") " " cell(HF[i, 7], "int") " " cell(HF[i, 8], "int")
    if (HF[i, 9] == "<none>") { print head, "-", "-", "-"; continue }
    nc = split(HF[i, 9], c, ",")
    spread_hpa(HF[i, 10], nc, "metric-resource"); for (j = 1; j <= nc; j++) HM[j] = OUT[j]
    spread_hpa(HF[i, 11], nc, "int"); for (j = 1; j <= nc; j++) HU[j] = OUT[j]
    for (j = 1; j <= nc; j++) print head, cell(c[j], "metric-type"), HM[j], HU[j]
  }

  print "# rows not placed: top=" NT_BAD " pods=" NP_BAD " vpa=" NV_BAD " hpa=" NH_BAD
}'
}

# Put a tag in front of every line. A line with a control character (a
# carriage return, or a tab inside a cell) gets the tag with an X, and its
# row is counted and not printed, because the copies of awk do not agree on
# where such a line splits.
tag() {
  sed -e "s/^/$1 /" -e "/[[:cntrl:]]/s/^$1 /$1X /"  # a row with a control character
}

# The context name in its shape, or "other".
context_name() {
  printf '%s\n' "$1" | awk '
    NR == 1 { v = $0 }
    END {
      n = split(ENVIRON["SHAPES"], L, "\n")
      for (i = 1; i <= n; i++) if (index(L[i], "context-name ") == 1) {
        rest = substr(L[i], 14); p = index(rest, " ")
        max = substr(rest, 1, p - 1) + 0; pat = substr(rest, p + 1)
      }
      print (NR == 1 && length(v) <= max && v ~ pat) ? v : "other"
    }'
}

# ---- The front door ----

[ $# -gt 0 ] || die 2 "usage: $me --context | NAMESPACE [NAMESPACE ...]"
mode=namespaces
case $1 in
  -h | --help)
    [ $# -eq 1 ] || die 2 "--help takes no other argument"
    usage
    exit 0
    ;;
  --context)
    [ $# -eq 1 ] || die 2 "--context takes no other argument"
    mode=context
    ;;
  *)
    for a in "$@"; do
      is_ns "$a" || die 2 "an argument is not a namespace name (lower case letters, digits, and -, at most 63 characters, starting and ending with a letter or a digit)"
    done
    ;;
esac

# ---- The commands ----

command -v kubectl >/dev/null 2>&1 || die 5 "kubectl is not installed"  # kubectl missing: exit 5

raw=$(kube "$CMD_CONTEXT" "") || die 5 "no current context: kubectl config current-context failed"  # no context: exit 5
[ -n "$raw" ] || die 5 "no current context"
ctx=$(context_name "$raw")  # the context name has its shape

if [ "$mode" = context ]; then
  printf '%s\n' "$ctx"
  exit 0
fi

echo "# context $ctx"
echo "# Measured in the cluster: one sample from kubectl top, which is one moment in time."
echo "# Values: - means none is set or none was measured; other means a value was seen and does not fit its shape; not-read means a value was seen and cannot be placed on one container."
echo "# POD_LAST_END is the last termination reason of any container of the pod, given for the pod as a whole and not for each container."

for ns in "$@"; do
  top=$(kube "$CMD_TOP" "$ns") || die 6 "no metrics for namespace $ns: kubectl top pod failed. A metrics source such as the Metrics Server may be missing, or the metrics are not ready yet."  # no metrics: exit 6
  pods_state=ok; pods=$(kube "$CMD_PODS" "$ns") || { pods_state=failed; pods=; }
  vpa_state=ok; vpas=$(kube "$CMD_VPA" "$ns") || { vpa_state=failed; vpas=; }
  hpa_state=ok; hpas=$(kube "$CMD_HPA" "$ns") || { hpa_state=failed; hpas=; }
  echo "# namespace $ns"
  {
    printf '%s\n' "$top" | tag T
    printf '%s\n' "$pods" | tag P
    printf '%s\n' "$vpas" | tag V
    printf '%s\n' "$hpas" | tag H
  } | table "$pods_state" "$vpa_state" "$hpa_state" || die 1 "the table of namespace $ns could not be printed"
done
exit 0
