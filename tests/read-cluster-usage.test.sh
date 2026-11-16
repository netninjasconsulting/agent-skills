#!/bin/sh
# read-cluster-usage.test.sh: run the cluster usage reader against the stand-in kubectl.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/read-cluster-usage.test.sh
#
# The real cluster is never contacted. The stand-in kubectl in
# tests/fixtures/kubernetes-workload-check/fake-kubectl is first on PATH. It
# logs every argument list, answers the commands of the fixed list with
# canned rows, and answers anything else with a line that holds the marker
# FIXTUREVALUE. Its hostile rows (namespace stand-in-rows) hold the marker
# in names, quantities, and reasons, so no output may hold it.
#
# Checks: the log holds only commands of the fixed list, each naming a
# namespace it was given; an argument that is not a namespace name exits 2
# and logs nothing; --context logs only "config current-context"; no output
# holds the marker; the tables print the canned rows in their shapes, with
# "other", "not-read", or a count where a value cannot be read or placed;
# a failed top exits 6, a missing context or kubectl exits 5; kubectl runs
# with the caller's environment as it is, in the C locale, with no input,
# and kuberc is never switched off.
#
# The pins at the end make a copy of the script with one safeguard switched
# off and expect this test to fail on the check named for that safeguard.
# The control case shows that each copy still works.

set -u

root=$(cd "$(dirname "$0")/.." && pwd)
real_script="$root/skills/kubernetes-workload-check/scripts/read-cluster-usage.sh"
fields_md="$root/skills/kubernetes-workload-check/references/fields.md"
fake="$root/tests/fixtures/kubernetes-workload-check/fake-kubectl"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
home="$work/home"
mkdir "$home"
total=0

[ -f "$real_script" ] || { echo "FAIL: the script does not exist: $real_script"; exit 1; }
[ -x "$fake/kubectl" ] || { echo "FAIL: the stand-in kubectl is not executable: $fake/kubectl"; exit 1; }

NL='
'
TAB=$(printf '\t')
CR=$(printf '\r')

# The fixed command list of references/fields.md, held here on its own. The
# test checks that fields.md and the script carry the same list.
T_CMDS='kubectl config current-context
kubectl top pod --containers --namespace=<name> --no-headers --all-namespaces=false --show-swap=false --sum=false --request-timeout=20s
kubectl get pods --namespace=<name> --no-headers --all-namespaces=false --watch=false --show-kind=false --show-labels=false --request-timeout=20s -o custom-columns=POD:.metadata.name,CONTAINERS:.spec.containers[*].name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory,STATUS_NAMES:.status.containerStatuses[*].name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_END:.status.containerStatuses[*].lastState.terminated.reason
kubectl get verticalpodautoscalers.autoscaling.k8s.io --namespace=<name> --no-headers --all-namespaces=false --watch=false --show-kind=false --show-labels=false --request-timeout=20s -o custom-columns=VPA:.metadata.name,TARGET_KIND:.spec.targetRef.kind,TARGET:.spec.targetRef.name,MODE:.spec.updatePolicy.updateMode,RECO_CONTAINER:.status.recommendation.containerRecommendations[*].containerName,CPU_TARGET:.status.recommendation.containerRecommendations[*].target.cpu,MEM_TARGET:.status.recommendation.containerRecommendations[*].target.memory,CPU_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.cpu,MEM_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.memory,CPU_UPPER:.status.recommendation.containerRecommendations[*].upperBound.cpu,MEM_UPPER:.status.recommendation.containerRecommendations[*].upperBound.memory
kubectl get horizontalpodautoscalers.autoscaling --namespace=<name> --no-headers --all-namespaces=false --watch=false --show-kind=false --show-labels=false --request-timeout=20s -o custom-columns=HPA:.metadata.name,TARGET_KIND:.spec.scaleTargetRef.kind,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,METRIC_TYPE:.spec.metrics[*].type,METRIC:.spec.metrics[*].resource.name,UTILIZATION:.spec.metrics[*].resource.target.averageUtilization'

# The shape block of the cluster script in references/fields.md. A shape
# that the reader's block holds as well must be the same line there.
T_SHAPES='int 10 ^[0-9]+$
qty-cpu 12 ^([0-9]+|[0-9]+\.[0-9]+|[0-9]+m)$
qty-mem 16 ^[0-9]+(\.[0-9]+)?(E|P|T|G|M|k|Ei|Pi|Ti|Gi|Mi|Ki|m)?$
dns-label 63 ^([a-z]|[a-z][-a-z0-9]*[a-z0-9])$
dns-subdomain 253 ^([a-z0-9]|[a-z0-9][-a-z0-9.]*[a-z0-9])$
kind-name 63 ^[A-Z][A-Za-z0-9]*$
update-mode 17 ^(Off|Initial|Recreate|Auto|InPlaceOrRecreate|InPlace)$
metric-type 18 ^(ContainerResource|External|Object|Pods|Resource)$
metric-resource 6 ^(cpu|memory)$
container-name 63 ^([a-z0-9]|[a-z0-9][-a-z0-9]*[a-z0-9])$
context-name 253 ^[A-Za-z0-9][A-Za-z0-9_.:@/+-]*$
end-reason 22 ^(OOMKilled|Error|Completed|ContainerCannotRun|DeadlineExceeded|StartError|ContainerStatusUnknown)$'

FIXTURE_NS='fleetboard-production fleetboard-staging fleetboard-tools dispatch-production dispatch-staging'

# ---- Running the script ----

# run SCRIPT MODE ARG...: run the script with the stand-in first on PATH, a
# KUBECONFIG, a KUBERC, a canary variable, and a locale that the script
# must set to C. Sets rc, and leaves standard output in $work/out and
# standard error in $work/err. Standard input holds a line that kubectl
# must never read.
run() {
  rs=$1; rm_=$2; shift 2
  rm -f "$home/log" "$home/env"
  rc=0
  printf 'typed-answer\n' | env -i PATH="$fake:$PATH" HOME="$home" KUBECONFIG="$work/kubeconfig" KUBERC="$work/kuberc" \
    CANARY=canary-value LC_ALL=C.UTF-8 FAKE_KUBECTL_LOG="$home/log" FAKE_KUBECTL_ENVLOG="$home/env" FAKE_KUBECTL_MODE="$rm_" \
    sh "$rs" "$@" > "$work/out" 2> "$work/err" || rc=$?
}
# The same with no KUBECONFIG and no KUBERC in the environment.
run_bare() {
  rs=$1; shift
  rm -f "$home/log" "$home/env"
  rc=0
  env -i PATH="$fake:$PATH" HOME="$home" FAKE_KUBECTL_LOG="$home/log" FAKE_KUBECTL_ENVLOG="$home/env" \
    sh "$rs" "$@" > "$work/out" 2> "$work/err" < /dev/null || rc=$?
}
log_text() { cat "$home/log" 2>/dev/null; }

# The allowed log lines for the namespaces given: each command of the fixed
# list, with <name> replaced, after the number of its arguments.
allowed_lines() {
  printf '%s\n' "$T_CMDS" | while IFS= read -r c; do
    case $c in
      *'<name>'*)
        for n in "$@"; do
          l=${c%%'<name>'*}$n${c#*'<name>'}
          words=$(printf '%s\n' "$l" | awk '{ print NF - 1 }')
          printf '%s %s\n' "$words" "${l#kubectl }"
        done
        ;;
      *)
        words=$(printf '%s\n' "$c" | awk '{ print NF - 1 }')
        printf '%s %s\n' "$words" "${c#kubectl }"
        ;;
    esac
  done
}

# ---- The suite ----

sf=0
fail() { echo "FAIL: $1"; sf=$((sf + 1)); }
expect_line() {  # $1 = check label, $2 = the exact line
  grep -qxF -e "$2" "$work/out" || fail "$1: missing line: $2"
}
no_line() {  # $1 = check label, $2 = a fixed string no output line may hold
  if grep -qF -e "$2" "$work/out"; then fail "$1: printed: $2"; fi
}
no_marker() {  # $1 = label
  if grep -q FIXTUREVALUE "$work/out"; then fail "$1: the marker is in standard output"; fi
  if grep -q FIXTUREVALUE "$work/err"; then fail "$1: the marker is in standard error"; fi
}
log_only() {  # $1 = label; the rest are the namespaces given
  ll=$1; shift
  allowed_lines "$@" > "$work/allowed"
  if [ ! -s "$home/log" ]; then fail "$ll: the stand-in logged nothing"; return; fi
  while IFS= read -r line; do
    grep -qxF -e "$line" "$work/allowed" || fail "$ll: the log holds a command outside the fixed list: $line"
    case " $line " in
      *' -A '* | *[Ss]ecret* | *' describe '* | *' logs '* | *' exec '* | *' -o yaml '* | *' -o json '* | *'-o=json'* | *'-o=yaml'* | *--output*)
        fail "$ll: the log holds a forbidden word: $line" ;;
    esac
    for w in $line; do
      case $w in --all-namespaces=false) ;; --all-namespaces*) fail "$ll: the log holds $w: $line" ;; esac
    done
    for v in apply create delete patch replace edit scale rollout label annotate set drain cordon taint port-forward cp attach; do
      case "$line" in "2 $v "* | *" $v "*) fail "$ll: the log holds the writing verb $v: $line" ;; esac
    done
  done < "$home/log"
}

bad_args() {
  # Each argument here is not a namespace name. The run must exit 2 and log
  # nothing.
  s=$1
  # They are numbered from 1 in the order of the list.
  long=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  i=0
  # shellcheck disable=SC2016 # literal text, not an expansion
  for a in "" "a b" "-n" "-A" "--all-namespaces" "--namespace=x" "a;b" "a/b" "../etc" "Abc" "a_b" "a-" "-a" "a.b" "a${NL}b" "a${NL}" "a${TAB}b" "a${CR}" "default;rm" '$(id)' '*' "$long" "kube-system${NL}"; do
    i=$((i + 1))
    run "$s" "" "$a"
    [ "$rc" -eq 2 ] || fail "front door: argument $i expected exit 2, got $rc"
    [ -z "$(log_text)" ] || fail "front door: argument $i logged a command"
  done
  run "$s" "" fleetboard-production "a b"
  [ "$rc" -eq 2 ] || fail "front door: a good name then a bad one expected exit 2, got $rc"
  [ -z "$(log_text)" ] || fail "front door: a good name then a bad one logged a command"
  run "$s" "" --context fleetboard-production
  [ "$rc" -eq 2 ] || fail "front door: --context with a name expected exit 2, got $rc"
  [ -z "$(log_text)" ] || fail "front door: --context with a name logged a command"
  run "$s" ""
  [ "$rc" -eq 2 ] || fail "front door: no argument expected exit 2, got $rc"
  [ -z "$(log_text)" ] || fail "front door: no argument logged a command"
  # 63 characters is the most a name may have.
  run "$s" "" "${long%a}"
  [ "$rc" -eq 0 ] || fail "front door: a name of 63 characters expected exit 0, got $rc"
}

suite() {
  s=$1
  sf=0

  # The fixed command list and the shapes, the same in fields.md and the script.
  md_cmds=$(awk '/^The fixed command list of the cluster script/ { s = 1; next } s == 1 && /^```text$/ { s = 2; next } s == 2 && /^```$/ { exit } s == 2' "$fields_md")
  [ "$md_cmds" = "$T_CMDS" ] || fail "the fixed command list of fields.md differs from the test's"
  sc_cmds=$(sed -n '/^# BEGIN the fixed command list/,/^# END the fixed command list/p' "$s" | sed -n "s/^CMD_[A-Z]*='\\(.*\\)'\$/\\1/p")
  [ "$sc_cmds" = "$T_CMDS" ] || fail "the fixed command list of the script differs from fields.md"
  md_shapes=$(awk '/^The shape block of the cluster script/ { s = 1; next } s == 1 && /^```text$/ { s = 2; next } s == 2 && /^```$/ { exit } s == 2' "$fields_md")
  [ "$md_shapes" = "$T_SHAPES" ] || fail "the cluster shape block of fields.md differs from the test's"
  sc_shapes=$(sed -n "/^SHAPES='\$/,/^'\$/p" "$s" | sed '1d;$d')
  [ "$sc_shapes" = "$T_SHAPES" ] || fail "the shape block of the script differs from fields.md"
  reader_shapes=$(awk '/^The shape block, one shape on each line/ { s = 1; next } s == 1 && /^```text$/ { s = 2; next } s == 2 && /^```$/ { exit } s == 2' "$fields_md")
  printf '%s\n' "$T_SHAPES" | while IFS= read -r line; do
    id=${line%% *}
    other=$(printf '%s\n' "$reader_shapes" | awk -v id="$id" '$1 == id')
    if [ -n "$other" ] && [ "$other" != "$line" ]; then echo "FAIL: the shape $id differs from the reader's"; fi
  done > "$work/shape-diff"
  if [ -s "$work/shape-diff" ]; then cat "$work/shape-diff"; sf=$((sf + 1)); fi

  bad_args "$s"

  # --help prints the usage and runs nothing.
  run "$s" "" --help
  [ "$rc" -eq 0 ] || fail "help: expected exit 0, got $rc"
  [ -z "$(log_text)" ] || fail "help: logged a command"

  run "$s" "" --help fleetboard-production
  [ "$rc" -eq 2 ] || fail "help with an argument: expected exit 2, got $rc"
  [ -z "$(log_text)" ] || fail "help with an argument: logged a command"

  # --context logs only config current-context.
  run "$s" "" --context
  [ "$rc" -eq 0 ] || fail "context: expected exit 0, got $rc"
  [ "$(log_text)" = "2 config current-context" ] || fail "context: the log holds more than config current-context"
  [ "$(cat "$work/out")" = "fleetboard-stand-in" ] || fail "context: the output is not the context name"
  no_marker "context"
  run "$s" "odd-context" --context
  [ "$(cat "$work/out")" = "other" ] || fail "context: a context name that is not a name printed as it came"
  no_marker "odd context"
  run "$s" "no-context" --context
  [ "$rc" -eq 5 ] || fail "no context: expected exit 5, got $rc"
  [ "$(log_text)" = "2 config current-context" ] || fail "no context: the log holds more than config current-context"
  no_marker "no context"
  run "$s" "empty-context" --context
  [ "$rc" -eq 5 ] || fail "an empty context answer: expected exit 5, got $rc"
  run "$s" "no-context" fleetboard-production
  [ "$rc" -eq 5 ] || fail "no context, namespace mode: expected exit 5, got $rc"
  [ "$(log_text)" = "2 config current-context" ] || fail "no context, namespace mode: a command ran after the context failed"
  no_marker "no context, namespace mode"

  # kubectl missing: exit 5.
  mkdir -p "$work/nokube"
  rc=0
  env -i PATH="$work/nokube" HOME="$home" FAKE_KUBECTL_LOG="$home/log" /bin/sh "$s" fleetboard-production > "$work/out" 2> "$work/err" || rc=$?
  [ "$rc" -eq 5 ] || fail "kubectl missing: expected exit 5, got $rc"
  grep -q "kubectl is not installed" "$work/err" || fail "kubectl missing: the message does not say kubectl is not installed"

  # The fixture's namespaces.
  # shellcheck disable=SC2086 # the namespace list
  run "$s" "" $FIXTURE_NS
  [ "$rc" -eq 0 ] || fail "fixture: expected exit 0, got $rc"
  # shellcheck disable=SC2086 # the namespace list
  log_only "fixture" $FIXTURE_NS
  [ "$(grep -c . "$home/log")" -eq 21 ] || fail "fixture: expected 21 commands in the log, got $(grep -c . "$home/log")"
  no_marker "fixture"
  [ ! -s "$work/err" ] || fail "fixture: standard error is not empty"
  expect_line "fixture" "# context fleetboard-stand-in"
  expect_line "fixture" "# namespace fleetboard-production"
  expect_line "fixture" "container api-7c9d8b6f4-2xkqp api 100m 500m 128Mi 192Mi 4m 61Mi 0 -"
  expect_line "fixture" "container web-5f6d7c8b9-4kxlp web 100m 500m 128Mi 512Mi 41m 498Mi 3 OOMKilled"
  expect_line "fixture" "vpa api Deployment api Off api 25m 262144k 15m 209715k 120m 524288k"
  expect_line "fixture" "container tracker-58c6d9f7b-h6j2k tracker - - - - 1m 22Mi 5 Error"
  expect_line "fixture" "container tracker-report-29371920-q8m4d report 100m - 128Mi 256Mi - - 0 -"
  expect_line "fixture" "container dispatch-6d9f8c7b5-k9s3q dispatch - - 256Mi 384Mi 97m 240Mi 1 Error"
  expect_line "fixture" "hpa dispatch Rollout dispatch 4 12 4 4 Resource cpu 70"
  expect_line "fixture" "hpa dispatch Rollout dispatch 1 2 1 1 Resource cpu 70"
  expect_line "fixture" "# vpa: none in this namespace"
  expect_line "fixture" "# hpa: none in this namespace"
  expect_line "fixture" "# rows not placed: top=0 pods=0 vpa=0 hpa=0"

  # One namespace, the whole output.
  run "$s" "" fleetboard-staging
  cat > "$work/want" <<'EOF'
# context fleetboard-stand-in
# Measured in the cluster: one sample from kubectl top, which is one moment in time.
# Values: - means none is set or none was measured; other means a value was seen and does not fit its shape; not-read means a value was seen and cannot be placed on one container.
# POD_LAST_END is the last termination reason of any container of the pod, given for the pod as a whole and not for each container.
# namespace fleetboard-staging
# container POD CONTAINER CPU_REQ CPU_LIM MEM_REQ MEM_LIM CPU_USED MEM_USED RESTARTS POD_LAST_END
container api-6b8c7d9e5-p3lmk api 100m 500m 128Mi 192Mi 2m 48Mi 0 -
container web-7d4f5a6b8-q9wzx web 100m 500m 128Mi 256Mi 12m 140Mi 0 -
# vpa VPA TARGET_KIND TARGET MODE CONTAINER CPU_TARGET MEM_TARGET CPU_LOWER MEM_LOWER CPU_UPPER MEM_UPPER
# vpa: none in this namespace
# hpa HPA TARGET_KIND TARGET MIN MAX CURRENT DESIRED METRIC_TYPE METRIC UTILIZATION
# hpa: none in this namespace
# rows not placed: top=0 pods=0 vpa=0 hpa=0
EOF
  cmp -s "$work/out" "$work/want" || { fail "one namespace: the output differs from the expected table"; diff "$work/want" "$work/out" | sed -n 1,10p; }

  # A namespace with no pods.
  run "$s" "" empty-ns
  [ "$rc" -eq 0 ] || fail "empty namespace: expected exit 0, got $rc"
  expect_line "empty namespace" "# pods: none in this namespace"
  log_only "empty namespace" empty-ns

  # The hostile rows.
  run "$s" "" stand-in-rows
  [ "$rc" -eq 0 ] || fail "hostile rows: expected exit 0, got $rc"
  no_marker "hostile rows"
  log_only "hostile rows" stand-in-rows
  # A pod whose first container has no requests: the counts differ, so the
  # request of app is never given to sidecar.
  expect_line "misaligned columns" "container two-1 sidecar not-read - 64Mi not-read 1m 12Mi 0 OOMKilled"
  expect_line "misaligned columns" "container two-1 app not-read - 128Mi not-read 20m 140Mi 3 OOMKilled"
  no_line "misaligned columns: the request of app went to sidecar" "container two-1 sidecar 100m"
  # Restarts follow the status names, which come in another order.
  no_line "restarts by status name" "container two-1 sidecar not-read - 64Mi not-read 1m 12Mi 3"
  expect_line "a container name that is a sentence" "container ignore-1 other 100m 500m 128Mi 256Mi - - 0 -"
  expect_line "a quantity that is a token" "container token-qty-1 app other 500m 128Mi other other other other other"
  expect_line "a status name that matches no container" "container stray-status-1 app 100m 500m 128Mi 256Mi - - not-read -"
  expect_line "a top row twice" "container dup-key-1 app 100m 500m 128Mi 256Mi not-read not-read 0 -"
  expect_line "reasons from a closed list" "container reasons-1 a 100m 500m 128Mi 256Mi - - 1 OOMKilled,other"
  no_line "a row with a carriage return" "crlf-1"
  expect_line "a top row with no pod row" "container late-1 app not-read not-read not-read not-read 2m 20Mi not-read not-read"
  no_line "a row with a reason with spaces" "reason-space-1"
  no_line "a row with an extra column" "extra-col-1"
  no_line "a row with a missing column" "missing-col-1"
  no_line "a row with no container list" "none-containers-1"
  no_line "a pod row twice" "dup-pod-1"
  no_line "a tab inside a cell" "tab-1"
  no_line "a top row with an extra column" "top-extra-1"
  no_line "a top row with a missing column" "top-missing-1"
  expect_line "vpa columns that differ in count" "vpa two-vpa Deployment two Auto sidecar not-read 64Mi - - - -"
  expect_line "vpa columns that differ in count" "vpa two-vpa Deployment two Auto app not-read 96Mi - - - -"
  expect_line "a vpa with no recommendation" "vpa fresh-vpa Deployment fresh Initial - - - - - - -"
  expect_line "a vpa with values out of shape" "vpa odd-vpa other other other app other 64Mi - - - -"
  no_line "a vpa row with a missing column" "short-vpa"
  expect_line "hpa metric columns that differ in count" "hpa mixed-hpa Deployment two 1 3 1 1 Resource not-read not-read"
  expect_line "hpa metric columns that differ in count" "hpa mixed-hpa Deployment two 1 3 1 1 Pods not-read not-read"
  expect_line "an hpa with two metrics" "hpa two-hpa Deployment two 1 3 1 2 Resource memory 80"
  expect_line "an hpa with values out of shape" "hpa odd-hpa Deployment other other 3 1 1 Resource other 70"
  expect_line "an hpa with no metrics" "hpa none-hpa Deployment none - 3 - - - - -"
  expect_line "a container name that starts with a digit" "container digit-1 1app 100m 500m 128Mi 256Mi - - 0 -"
  no_line "two containers with one name" "dupc-1"
  expect_line "a status name twice" "container repst-1 a 100m 500m 128Mi 256Mi - - not-read -"
  expect_line "a status name twice" "container repst-1 b 100m 500m 128Mi 256Mi - - not-read -"
  no_line "a row with a NUL" "nul-1"
  expect_line "rows not placed are counted" "# rows not placed: top=4 pods=10 vpa=1 hpa=0"

  # top fails: exit 6 with a plain message, and nothing kubectl wrote.
  run "$s" "no-top" fleetboard-production
  [ "$rc" -eq 6 ] || fail "no metrics: expected exit 6, got $rc"
  grep -q "kubectl top pod failed for namespace fleetboard-production" "$work/err" || fail "no metrics: the message does not name the failed command"
  no_marker "no metrics"
  # top fails in the second of three: the first table stays, and the
  # message names the namespaces not read. No command runs for the third.
  run "$s" "no-top-production" fleetboard-staging fleetboard-production dispatch-staging
  [ "$rc" -eq 6 ] || fail "no metrics in the second namespace: expected exit 6, got $rc"
  expect_line "no metrics in the second namespace" "# namespace fleetboard-staging"
  no_line "no metrics in the second namespace" "# namespace fleetboard-production"
  grep -q "Namespaces not read: fleetboard-production dispatch-staging$" "$work/err" || fail "no metrics in the second namespace: the message does not name the namespaces not read"
  if grep -q "dispatch-staging" "$home/log"; then fail "no metrics in the second namespace: a command ran for a later namespace"; fi
  # The VPA query fails: a trace, never the same as none.
  run "$s" "no-vpa" fleetboard-production
  [ "$rc" -eq 0 ] || fail "vpa query fails: expected exit 0, got $rc"
  expect_line "vpa query fails" "# vpa: not read, the query failed or the server has no such type"
  no_line "vpa query fails" "# vpa: none in this namespace"
  no_marker "vpa query fails"
  # The HPA query fails: the same.
  run "$s" "no-hpa" dispatch-staging
  [ "$rc" -eq 0 ] || fail "hpa query fails: expected exit 0, got $rc"
  expect_line "hpa query fails" "# hpa: not read, the query failed or the server has no such type"
  no_line "hpa query fails" "hpa dispatch"
  no_marker "hpa query fails"
  # get pods fails: measured use still prints, the rest is not-read.
  run "$s" "no-pods" fleetboard-staging
  [ "$rc" -eq 0 ] || fail "no pods: expected exit 0, got $rc"
  expect_line "get pods fails" "# pods: not read, the query failed"
  expect_line "get pods fails" "container api-6b8c7d9e5-p3lmk api not-read not-read not-read not-read 2m 48Mi not-read not-read"
  no_marker "get pods fails"

  # Output as a kuberc default would change it: a column added to top and
  # to every pod row, and a header line. A trace, and no value printed.
  run "$s" "kuberc" fleetboard-staging
  [ "$rc" -eq 0 ] || fail "output changed by kuberc: expected exit 0, got $rc"
  no_marker "output changed by kuberc"
  no_line "output changed by kuberc: a value printed" "api-6b8c7d9e5-p3lmk"
  no_line "output changed by kuberc: a value printed" "web-7d4f5a6b8-q9wzx"
  expect_line "output changed by kuberc" "# rows not placed: top=2 pods=2 vpa=0 hpa=0"

  # Standard input never reaches kubectl.
  run "$s" "read-stdin" fleetboard-staging
  if grep -q '^stdin ' "$home/log"; then fail "standard input reached kubectl"; fi

  # The environment kubectl sees: the caller's, with LC_ALL set to C, and
  # KUBERC as the caller had it.
  run "$s" "" fleetboard-staging
  grep -qxF -e "value CANARY=canary-value" "$home/env" || fail "environment: the caller's variable did not reach kubectl"
  grep -qxF -e "value KUBECONFIG=$work/kubeconfig" "$home/env" || fail "environment: KUBECONFIG did not reach kubectl"
  grep -qxF -e "value KUBERC=$work/kuberc" "$home/env" || fail "environment: KUBERC changed"
  grep -qxF -e "value LC_ALL=C" "$home/env" || fail "environment: LC_ALL is not C"
  run_bare "$s" fleetboard-staging
  [ "$rc" -eq 0 ] || fail "environment, bare: expected exit 0, got $rc"
  grep -qxF -e "value KUBERC=" "$home/env" || fail "environment, bare: KUBERC changed"
  if grep -qxF -e "name KUBERC" "$home/env"; then fail "environment, bare: KUBERC changed"; fi

  [ "$sf" -eq 0 ]
}

suite "$real_script" || total=$((total + sf))

# ---- Pins ----
# A copy of the script with one safeguard switched off must fail on the
# check named for that safeguard. The control case: a copy must still parse
# as shell, run its awk program, and print a table, so a pin fails only
# through the safeguard it switches off.
copy_works() {
  sh -n "$1" 2>/dev/null || return 1
  run "$1" "" fleetboard-staging
  [ "$rc" -eq 0 ] || return 1
  grep -qxF -e "container api-6b8c7d9e5-p3lmk api 100m 500m 128Mi 192Mi 2m 48Mi 0 -" "$work/out"
}
PIN_BREAK=
PIN_HELD=0
PIN_CAUGHT=0
pin() {
  # $1 = label, $2 = a fixed string that marks the safeguard's line,
  # $3 = a sed command, $4 = text of the failing check
  copy="$work/pin-script.sh"
  if [ "$(grep -cF -e "$2" "$real_script")" -ne 1 ]; then
    echo "FAIL: pin $1: the safeguard line is not in the script once"
    total=$((total + 1))
    return
  fi
  sed -e "$3" "$real_script" > "$copy"
  case "$PIN_BREAK" in
    awk) sed -e 's/^function cell(v, id) {$/function cell(v, id,, ) {/' "$copy" > "$copy.b" && mv "$copy.b" "$copy" ;;
    sh) sed -e 's/^kube() {$/kube() { if/' "$copy" > "$copy.b" && mv "$copy.b" "$copy" ;;
  esac
  if cmp -s "$copy" "$real_script"; then
    echo "FAIL: pin $1: the copy did not change"
    total=$((total + 1))
    return
  fi
  if ! copy_works "$copy"; then
    if [ -z "$PIN_BREAK" ]; then
      echo "FAIL: pin $1: broken copy"
      total=$((total + 1))
    else
      PIN_CAUGHT=$((PIN_CAUGHT + 1))
    fi
    return
  fi
  if [ -n "$PIN_BREAK" ]; then
    echo "FAIL: pin $1: a copy broken in $PIN_BREAK was not reported as broken"
    total=$((total + 1))
    return
  fi
  if suite "$copy" > "$work/pin.out" 2>&1; then
    echo "FAIL: pin $1: the test passed with the safeguard switched off"
    total=$((total + 1))
  elif ! grep -qF -e "$4" "$work/pin.out"; then
    echo "FAIL: pin $1: the test failed, but not on: $4"
    sed -n 1,5p "$work/pin.out"
    total=$((total + 1))
  else
    PIN_HELD=$((PIN_HELD + 1))
  fi
}
pins() {
  pin "a namespace is a DNS label" '# a namespace is a DNS label' 's/^\(is_ns() {\)  # a namespace is a DNS label$/\1 return 0/' "front door: argument 2 expected exit 2"
  pin "a namespace starts with no dash" '# no dash at either end' 's/  '"''"' | -\* | \*- | \*\[!a-z0-9-\]\*) return 1 ;;  # no dash at either end/  '"''"' | *[!a-z0-9-]*) return 1 ;;/' "front door: argument 3 expected exit 2"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "a namespace has at most 63 characters" '# at most 63 characters' 's/\[ "\${#1}" -le 63 \]  # at most 63 characters/true/' "front door: argument 22 expected exit 2"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "kubectl keeps the caller environment" '# kubectl: the caller environment' 's/{ "\$@" <\/dev\/null/{ env -i PATH="$PATH" "$@" <\/dev\/null/' "environment: the caller's variable did not reach kubectl"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "kuberc is left as it is" '# kubectl: the caller environment' 's/{ "\$@" <\/dev\/null/{ KUBERC=off "$@" <\/dev\/null/' "environment: KUBERC changed"
  pin "the C locale" '# kubectl and awk run in the C locale' 's/^LC_ALL=C  # kubectl and awk run in the C locale$/:/' "environment: LC_ALL is not C"
  pin "no input for kubectl" '# kubectl: the caller environment' 's/ <\/dev\/null 2>\/dev\/null;/ 2>\/dev\/null;/' "standard input reached kubectl"
  pin "the standard error of kubectl is dropped" '# kubectl: the caller environment' 's/ 2>\/dev\/null; printf/; printf/' "no metrics: the marker is in standard error"
  pin "a NUL becomes visible" '# a NUL in kubectl output' 's/^\( *\)tr .*)  # a NUL in kubectl output.*$/\1cat)/' "a row with a NUL: printed: nul-1"
  pin "the shape check" 'function fits(v, id) {' 's/^function fits(v, id) {$/function fits(v, id) { return 1/' "hostile rows: the marker is in standard output"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "the context name shape" '# the context name has its shape' 's/^ctx=\$(context_name "\$raw")  # the context name has its shape$/ctx=$raw/' "context: a context name that is not a name printed as it came"
  pin "a pod row with another number of columns" '# a pod row with another number of columns' 's/if (NF != 10) { NP_BAD++; next }  # a pod row with another number of columns//' "a row with an extra column: printed: extra-col-1"
  pin "a top row with another number of columns" '# a top row with another number of columns' 's/if (NF != 5) { NT_BAD++; next }  # a top row with another number of columns//' "a top row with an extra column: printed: top-extra-1"
  pin "one value for each container" '# one value for each container' 's/spread(PF\[i, col\], nc, id)  # one value for each container/split(PF[i, col], OUT, ",")/' "misaligned columns: the request of app went to sidecar"
  pin "vpa columns that differ in count" '# one value for each recommendation' 's/spread(VF\[i, col\], nc, id)  # one value for each recommendation/split(VF[i, col], OUT, ",")/' "vpa columns that differ in count: missing line"
  pin "hpa metric columns that differ in count" '# one value for each metric' 's/spread(HF\[i, col\], nc, id)  # one value for each metric/split(HF[i, col], OUT, ",")/' "hpa metric columns that differ in count: missing line"
  pin "restarts by status name" '# restarts by status name' 's/if (sn\[m\] == c\[j\]) { hit++; at = m }  # restarts by status name/if (m == j) { hit++; at = m }/' "restarts by status name: printed"
  pin "a status name that matches no container" '# a status name that matches no container' 's/if (!(sn\[m\] in CN)) ok = 0  # a status name that matches no container//' "a status name that matches no container: missing line"
  pin "a status name twice" '# a status name twice' 's/if (sn\[m\] in SEEN) ok = 0  # a status name twice//' "a status name twice: missing line"
  pin "two containers with one name" '# two containers with one name' 's/if (nc == 0 || dup) { NP_BAD++; continue }  # two containers with one name//' "two containers with one name: printed: dupc-1"
  pin "a pod row twice" '# a pod row twice' 's/if (PODS\[PF\[i, 2\]\] > 1) { NP_BAD++; continue }  # a pod row twice//' "a pod row twice: printed: dup-pod-1"
  pin "a top row twice" '# a top row twice' 's/if (k in TD) mc = mm = "not-read"  # a top row twice//' "a top row twice: missing line"
  pin "a top row with no pod row" '# a top row with no pod row' 's/^\( *\)print "container", .*  # a top row with no pod row$/\1continue/' "a top row with no pod row: missing line"
  pin "a failed vpa query leaves a trace" '# a failed vpa query leaves a trace' 's/^\( *\)if (vpa == "failed") .*  # a failed vpa query leaves a trace$/\1if (0) print/' "vpa query fails: missing line"
  pin "a failed hpa query leaves a trace" '# a failed hpa query leaves a trace' 's/^\( *\)if (hpa == "failed") .*  # a failed hpa query leaves a trace$/\1if (0) print/' "hpa query fails: missing line"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "no metrics exits 6" '# no metrics: exit 6' 's/^\[ -z "\$failed" \] || die 6 .*  # no metrics: exit 6$/:/' "no metrics: expected exit 6"
  pin "no context exits 5" '# no context: exit 5' 's/|| die 5 .*  # no context: exit 5$/|| :/' "no context: expected exit 5"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "an empty context answer exits 5" '# an empty context answer: exit 5' 's/^\[ -n "\$raw" \] || die 5 .*  # an empty context answer: exit 5$/:/' "an empty context answer: expected exit 5"
  pin "kubectl missing exits 5" '# kubectl missing: exit 5' 's/^\(.*\)  # kubectl missing: exit 5$/: /' "kubectl missing: the message does not say kubectl is not installed"
  # shellcheck disable=SC2016 # literal text, not an expansion
  pin "a row with a control character" '# a row with a control character' 's/ -e "\/\[\[:cntrl:\]\]\/s\/^$1 \/$1X \/"  # a row with a control character//' "a row with a carriage return: printed: crlf-1"
  pin "the fixed command list" "CMD_VPA='kubectl get verticalpodautoscalers" 's/^CMD_VPA=.kubectl get verticalpodautoscalers.autoscaling.k8s.io --namespace=<name> /CMD_VPA='"'"'kubectl get secrets --all-namespaces /' "the fixed command list of the script differs from fields.md"
}
copy_works "$real_script" || { echo "FAIL: the control case fails on the script itself"; total=$((total + 1)); }
pins
PIN_BREAK='awk'
pins
PIN_BREAK='sh'
pins
PIN_BREAK=
echo "pins: $PIN_HELD held on their own check; $PIN_CAUGHT copies broken in awk or in shell were reported as broken"

if [ "$total" -gt 0 ]; then
  echo "$total check(s) failed"
  exit 1
fi
echo "read-cluster-usage: all checks passed"
