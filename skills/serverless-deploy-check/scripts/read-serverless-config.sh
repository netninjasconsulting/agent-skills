#!/bin/sh
# read-serverless-config.sh: list the serverless platform configuration files
# of a repository, and print one of them with its values hidden.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   sh read-serverless-config.sh [path]        list platform files in the repository at path
#   sh read-serverless-config.sh --show FILE   print FILE with line numbers and values hidden
#
# List output, one line per file, sorted by path: <path>:<platform>:<kind>:<state>
#   platform: aws-lambda | vercel | cloudflare-workers | supabase | shared
#   kind:     functions | infrastructure | env | workflow
#   state:    tracked | untracked | ignored | no-git
#
# The script reads files and Git objects. It writes nothing, changes nothing,
# and makes no network request. The files it lists, and the keys whose values
# it shows, are the ones named in references/platforms.md.
#
# Hiding is the default. --show prints keys and structure, and a value only
# when its key is on the list of shown keys for that file and sits in its
# home (a container that the list names), the value has the
# shape of a setting (a number, a word, a schedule, a path, or an origin), and
# it then passes the token, address, and long-word filters. It works by line
# and does not parse, so a broken file is still hidden. A value that spans
# lines, a heredoc, a block scalar, a multi-line string, and a comment are
# hidden whole. A value that only names where a secret lives, such as
# ${{ secrets.NAME }} or env(NAME), is shown.
#   env files, *.tfvars   Names only.
#   Exit 4                A file type this reader does not show. Nothing is printed.

set -u
LC_ALL=C
export LC_ALL

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

MODE=list
ROOT=.
SHOW_FILE=

while [ $# -gt 0 ]; do
  case "$1" in
    --show)
      MODE=show
      shift
      [ $# -gt 0 ] || { echo "read-serverless-config: --show needs a file" >&2; exit 2; }
      SHOW_FILE=$1
      ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "read-serverless-config: unknown option: $1" >&2; exit 2 ;;
    *) ROOT=$1 ;;
  esac
  shift
done

# Keys whose values are shown, by file, from references/platforms.md.
#
# Every map and list the reader enters gets a context: the top of the file is
# "top", and each entry ctx>key=next names the context of the container that
# key opens. ctx>*=next does the same for every key, which is how a name the
# user picks (a function, a resource, a job) leads to its settings. A key that
# no entry names opens the context "x", and so does every key below it: there
# the reader prints key names only, at any depth. A shown key is a real
# setting only in its home, so a list of homes, not a list of maps to hide,
# decides what prints.
#
# ctx>[] marks a context that is a list: an item of a sequence or array is in
# that context only when it is marked so, and otherwise in "x".
#
# ctx>key:shape shows the value of key in context ctx, when the value has that
# shape. ctx>*:shape does the same for every key. A shape that ends in ! holds
# over the never-shown list. Shapes: n number, m number or "max", b boolean,
# d date, w word, t short text, c schedule, p path or route, r method and path,
# o origin, a address, u action reference, pm workflow permission, rp a
# Worker route pattern (a path with a slash). The other
# shapes are closed sets or fixed forms, in the ENUM table of the awk program.
SHOW_SERVERLESS='
top>service:w top>provider=prov top>functions=fns top>package=pkg
prov>name:w prov>runtime:w prov>memorySize:n prov>timeout:n prov>architecture:arch
prov>logRetentionInDays:n prov>region:rg prov>stage:w prov>role:w prov>layers:lyr
prov>tracing=trc trc>lambda:b trc>apiGateway:b
prov>iam=iam iam>role:w iam>role=iamr iamr>mode:iamm iamr>managedPolicies:w iamr>statements=stmt
stmt>Effect:eff stmt>Action:w stmt>Resource:w
prov>apiGateway=apigw apigw>usagePlan=up up>*=up up>throttle=thr up>quota=quota
thr>burstLimit:n thr>rateLimit:n quota>limit:n quota>period:perd quota>offset:n
prov>httpApi=hapi hapi>disableDefaultEndpoint:b hapi>cors:b hapi>cors=cors
hapi>authorizers=auths auths>*=auth auth>type:atype auth>scopes:w
prov>logs=logs logs>lambda:b logs>restApi:b logs>httpApi:b logs>websocket:b
fns>[] evs>[] stmt>[] up>[]
fns>*=fn fn>handler:w fn>runtime:w fn>memorySize:n fn>timeout:n fn>architecture:arch
fn>reservedConcurrency:n fn>provisionedConcurrency:n fn>logRetentionInDays:n fn>role:w
fn>layers:lyr fn>url:b fn>url=url fn>events=evs fn>package=pkg
fn>iam=fniam fniam>inheritStatements:b fniam>role=iamr
url>authorizer:atype url>invokeMode:inv url>cors:b url>cors=cors
cors>allowedOrigins:o cors>allowedHeaders:w cors>allowedMethods:w cors>allowCredentials:b
cors>exposedResponseHeaders:w cors>maxAge:n cors>origin:o cors>origins:o cors>headers:w
evs>schedule:c evs>sqs:arn evs>http:r evs>httpApi:r
evs>http=ev evs>httpApi=ev evs>schedule=ev evs>sqs=ev
ev>path:r ev>method:meth ev>private:b ev>batchSize:n ev>maximumConcurrency:n ev>rate:c
ev>enabled:b ev>arn:arn ev>cors:b ev>cors=cors ev>authorizer:w ev>authorizer=authz
authz>name:w authz>type:atype authz>scopes:w
pkg>patterns:p pkg>individually:b pkg>excludeDevDependencies:b'
SHOW_SAM='
top>AWSTemplateFormatVersion:w top>Transform:w top>Resources=res top>Globals=glob
res>*=rsc rsc>Type:w rsc>Properties=props glob>Function=props
props>Runtime:w props>Handler:w props>CodeUri:p props>MemorySize:n props>Timeout:n
props>Architectures:arch props>ReservedConcurrentExecutions:n props>AutoPublishAlias:w
props>PackageType:pkg props>Policies:w props>Role:w props>PermissionsBoundary:w
props>Tracing:trc props>RetentionInDays:n
props>ProvisionedConcurrencyConfig=pcc pcc>ProvisionedConcurrentExecutions:n
props>EphemeralStorage=eph eph>Size:n
props>FunctionUrlConfig=furl furl>AuthType:auth furl>InvokeMode:inv furl>Cors=scors
scors>AllowOrigins:o scors>AllowMethods:w scors>AllowHeaders:w scors>AllowCredentials:b
scors>MaxAge:n scors>ExposeHeaders:w
props>LoggingConfig=logc logc>LogFormat:lfmt logc>ApplicationLogLevel:llvl logc>SystemLogLevel:llvl
props>RuntimeManagementConfig=rmc rmc>UpdateRuntimeOn:upd props>SnapStart=snapc snapc>ApplyOn:snap
props>Events=sevs sevs>*=sev sev>Type:w sev>Properties=sevp
sevp>Path:p sevp>Method:meth sevp>Schedule:c sevp>Auth=sauth
sauth>Authorizer:w sauth>DefaultAuthorizer:w sauth>ApiKeyRequired:b! sauth>AddDefaultAuthorizerToCorsPreflight:b
props>Policies=pols pols>Statement=stmts pols>[] stmts>[]
props>PolicyDocument=pdoc props>AssumeRolePolicyDocument=pdoc pdoc>Statement=stmts
stmts>Effect:eff stmts>Action:w stmts>Resource:w stmts>Principal:prsv stmts>Principal=prin
prin>Service:svc prin>AWS:prin'
# The settings of the top of a Wrangler file, written with @ for the context.
# An environment, env.<name>, holds the same settings, but not another env.
WRANGLER_SETTINGS='
@>name:w @>main:p @>compatibility_date:d @>compatibility_flags:w @>workers_dev:b
@>route:rp @>routes:rp @>upload_source_maps:b @>keep_vars:b
@>routes=rt rt>pattern:rp rt>custom_domain:b rt>[]
@>triggers=trig trig>crons:c @>limits=lim lim>cpu_ms:n @>placement=plc plc>mode:plc
@>observability=obs obs>enabled:b obs>head_sampling_rate:n obs>invocation_logs:b obs>logs=obs
@>assets=as as>directory:p as>run_worker_first:b as>binding:w
@>secrets=sec sec>required:w
@>kv_namespaces=bind @>d1_databases=bind @>hyperdrive=bind @>vectorize=bind
@>analytics_engine_datasets=bind @>ai=bind @>browser=bind @>images=bind
@>version_metadata=bind @>dispatch_namespaces=bind @>mtls_certificates=bind
@>send_email=bind bind>binding:w bind>[]
@>r2_buckets=r2 r2>binding:w r2>bucket_name:w r2>[]
@>services=svc svc>binding:w svc>service:w svc>entrypoint:w svc>[]
@>queues=qs qs>producers=qp qp>binding:w qp>queue:w qp>[] qs>consumers=qc qc>queue:w qc>[]
@>durable_objects=dob dob>bindings=dobb dobb>name:w dobb>class_name:w dobb>script_name:w dobb>[]
@>workflows=wfl wfl>binding:w wfl>name:w wfl>class_name:w wfl>script_name:w wfl>[]
@>ratelimits=rl rl>name:w rl>[] rl>simple=rls rls>limit:n rls>period:n
'
SHOW_WRANGLER="$(printf '%s\n' "$WRANGLER_SETTINGS" | sed 's/@>/top>/g')
top>env=envs envs>*=envt
$(printf '%s\n' "$WRANGLER_SETTINGS" | sed 's/@>/envt>/g')"
# shellcheck disable=SC2016  # $schema is a key name, not a variable
SHOW_VERCEL='
top>$schema:a top>framework:w top>regions:vrg top>functionFailoverRegions:vrg top>fluid:b top>bunVersion:w
top>functions=vfns vfns>*=vfn vfn>memory:n vfn>maxDuration:m vfn>runtime:w vfn>includeFiles:p
vfn>excludeFiles:p vfn>supportsCancellation:b vfn>regions:vrg
top>crons=vcron vcron>path:p vcron>schedule:c
top>schedules=scheds scheds>*=sched sched>schedule:c sched>path:p sched>requestMethod:meth
sched>function:p sched>topic:w sched>timezone:w sched>jitter:n
top>headers=hdrs hdrs>source:p hdrs>headers=hdr hdr>key:t!
top>rewrites=rw rw>source:p vcron>[] hdrs>[] hdr>[] rw>[]'
SHOW_WORKFLOW='
top>name:t top>on:w top>on=on on>*=onev on>schedule=onsch onsch>cron:c
onev>branches:w onev>branches-ignore:w onev>tags:w onev>paths:p onev>types:w
top>permissions:pm top>permissions=perm perm>*:pm!
top>jobs=jobs jobs>*=job job>runs-on:w job>name:t job>environment:w job>uses:u
job>permissions:pm job>permissions=perm job>environment=jenv jenv>name:t job>secrets=x
job>steps=step step>[] onsch>[] step>name:t step>uses:u step>with=with with>role-to-assume:iamrole with>aws-region:rg'
SHOW_SAMCONFIG='
top>version:n top>*=sce sce>*=scc scc>parameters=scp
scp>stack_name:w scp>capabilities:w scp>confirm_changeset:b scp>resolve_s3:b scp>region:rg
scp>cached:b scp>parallel:b scp>watch:b'
SHOW_SUPABASE='
top>api=sapi sapi>enabled:b sapi>port:n sapi>schemas:w sapi>extra_search_path:w sapi>max_rows:n
top>db=sdb sdb>port:n sdb>major_version:n sdb>pooler=spool spool>enabled:b spool>port:n
spool>pool_mode:pool spool>default_pool_size:n spool>max_client_conn:n
sdb>seed=sseed sseed>enabled:b sseed>sql_paths:p
top>auth=sauth sauth>enabled:b sauth>site_url:a sauth>additional_redirect_urls:a sauth>jwt_expiry:n
sauth>enable_signup:b sauth>enable_anonymous_sign_ins:b
sauth>email=smail smail>enable_signup:b smail>enable_confirmations:b
sauth>external=sext sext>*=sextp sextp>enabled:b
top>functions=sfns sfns>*=sfn sfn>verify_jwt:b sfn>entrypoint:p sfn>import_map:p
sfn>static_files:p sfn>enabled:b
top>edge_runtime=ser ser>enabled:b ser>policy:epol
top>storage=sst sst>enabled:b sst>file_size_limit:w'
# In HCL a block of type resource or data is named by its type, as in
# resource.aws_lambda_function.
SHOW_HCL='
top>resource.aws_lambda_function=lam
lam>function_name:w lam>runtime:w lam>handler:w lam>role:w lam>memory_size:n lam>timeout:n
lam>architectures:arch lam>reserved_concurrent_executions:n lam>package_type:pkg
lam>filename:p lam>layers:lyr
lam>ephemeral_storage=heph heph>size:n lam>tracing_config=htc htc>mode:trc
lam>logging_config=hlc hlc>log_format:lfmt hlc>application_log_level:llvl hlc>system_log_level:llvl
top>resource.aws_lambda_function_url=hfurl hfurl>authorization_type:auth hfurl>invoke_mode:inv
hfurl>cors=hcors hcors>allow_origins:o hcors>allow_methods:w hcors>allow_headers:w
hcors>allow_credentials:b hcors>max_age:n
top>resource.aws_lambda_permission=hperm hperm>action:w hperm>principal:prsv
hperm>function_url_auth_type:auth hperm>invoked_via_function_url:b hperm>function_name:w
top>resource.aws_cloudwatch_log_group=hlg hlg>retention_in_days:n
top>resource.aws_iam_role_policy=hpol top>resource.aws_iam_policy=hpol top>resource.aws_iam_role=hpol
hpol>role:w hpol>policy=jpol hpol>assume_role_policy=jpol
jpol>Statement=jst jst>Effect:eff jst>Action:w jst>Resource:w
top>data.aws_iam_policy_document=hpd hpd>statement=hpst hpst>effect:eff hpst>actions:w
hpst>resources:w hpst>condition=hcond hcond>test:w hcond>variable:w'

# Never shown, matched by name in any file. A key whose name holds secret,
# token, password, credential, private key, API key, access key, connection
# string, or database URL is never shown either. Under one of these keys,
# names and values are hidden.
NEVER_KEYS='secret secrets token password passwd apikey api_key apiKeys access_key secret_key client_secret auth_token private_key localConnectionString connection_string database_url aws-access-key-id aws-secret-access-key CRON_SECRET input request buildCommand installCommand run key parameter_overrides'

# A SAM or CloudFormation template, whatever its name.
TEMPLATE_MARK='AWSTemplateFormatVersion|AWS::Serverless'

is_git() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

git_state() {
  if ! is_git; then
    echo no-git
  elif git -C "$ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1; then
    echo tracked
  elif git -C "$ROOT" check-ignore -q -- "$1" 2>/dev/null; then
    echo ignored
  else
    echo untracked
  fi
}

# The platform of a Terraform or OpenTofu file, by the first resource type that matches.
tf_platform() {
  if grep -Eq 'resource[[:space:]]+"aws_lambda_' "$1" 2>/dev/null; then
    echo aws-lambda
  elif grep -Eq 'resource[[:space:]]+"cloudflare_worker' "$1" 2>/dev/null; then
    echo cloudflare-workers
  elif grep -Eq 'resource[[:space:]]+"supabase_' "$1" 2>/dev/null; then
    echo supabase
  else
    echo shared
  fi
}

# $1 = path relative to the repository. Prints "<platform> <kind>", or nothing.
classify() {
  case "$1" in
    .github/workflows/*/*) return ;;
    .github/workflows/*.yml | .github/workflows/*.yaml) echo "shared workflow"; return ;;
  esac
  case "${1##*/}" in
    wrangler.toml | wrangler.json | wrangler.jsonc) echo "cloudflare-workers functions" ;;
    .dev.vars | .dev.vars.*) echo "cloudflare-workers env" ;;
    vercel.json) echo "vercel functions" ;;
    serverless.yml | serverless.yaml) echo "aws-lambda functions" ;;
    template.yaml | template.yml | template.json | samconfig.toml) echo "aws-lambda infrastructure" ;;
    *.tf | *.tofu) echo "$(tf_platform "$ROOT/$1") infrastructure" ;;
    *.tfvars) echo "shared env" ;;
    config.toml)
      case "$1" in
        supabase/config.toml | */supabase/config.toml) echo "supabase functions" ;;
      esac
      ;;
    .env | .env.*) echo "shared env" ;;
    *.yml | *.yaml | *.json)
      if grep -Eq -e "$TEMPLATE_MARK" "$ROOT/$1" 2>/dev/null; then
        echo "aws-lambda infrastructure"
      fi
      ;;
  esac
}

list() {
  [ -d "$ROOT" ] || { echo "read-serverless-config: not a directory: $ROOT" >&2; exit 2; }
  (
    cd "$ROOT" || exit 2
    find . \( -name .git -o -name node_modules -o -name .terraform -o -name .next \
      -o -name .serverless -o -name .wrangler -o -name .aws-sam -o -name .turbo \
      -o -name .venv -o -name venv \) -prune -o -type f -print
  ) | sed 's#^\./##' | while IFS= read -r path; do
    found=$(classify "$path")
    [ -n "$found" ] || continue
    printf '%s:%s:%s:%s\n' "$path" "${found% *}" "${found#* }" "$(git_state "$path")"
  done | sort
}

show() {
  [ -f "$SHOW_FILE" ] || { echo "read-serverless-config: not a file: $SHOW_FILE" >&2; exit 2; }
  base=$(basename "$SHOW_FILE")
  dir=$(cd "$(dirname "$SHOW_FILE")" && pwd)
  family=
  format=
  case "$dir/$base" in
    */.github/workflows/*.yml | */.github/workflows/*.yaml) family=workflow; format=yaml ;;
  esac
  if [ -z "$family" ]; then
    case "$base" in
      wrangler.toml) family=wrangler; format=toml ;;
      wrangler.json | wrangler.jsonc) family=wrangler; format=json ;;
      vercel.json) family=vercel; format=json ;;
      serverless.yml | serverless.yaml) family=serverless; format=yaml ;;
      template.yaml | template.yml) family=sam; format=yaml ;;
      template.json) family=sam; format=json ;;
      samconfig.toml) family=samconfig; format=toml ;;
      config.toml)
        if [ "${dir##*/}" = supabase ]; then family=supabase; format=toml; fi
        ;;
      *.tf | *.tofu) family=hcl; format=hcl ;;
      *.tfvars) family=tfvars; format=hcl ;;
      .env | .env.* | .dev.vars | .dev.vars.*) family='env'; format='env' ;;
      *.yml | *.yaml)
        if grep -Eq -e "$TEMPLATE_MARK" "$SHOW_FILE" 2>/dev/null; then family=sam; format=yaml; fi
        ;;
      *.json)
        if grep -Eq -e "$TEMPLATE_MARK" "$SHOW_FILE" 2>/dev/null; then family=sam; format=json; fi
        ;;
    esac
  fi
  if [ -z "$family" ]; then
    echo "read-serverless-config: not a file type this reader shows: $SHOW_FILE" >&2
    exit 4
  fi

  case "$family" in
    wrangler) keys=$SHOW_WRANGLER ;;
    vercel) keys=$SHOW_VERCEL ;;
    sam) keys=$SHOW_SAM ;;
    serverless) keys=$SHOW_SERVERLESS ;;
    workflow) keys=$SHOW_WORKFLOW ;;
    samconfig) keys=$SHOW_SAMCONFIG ;;
    supabase) keys=$SHOW_SUPABASE ;;
    hcl) keys=$SHOW_HCL ;;
    *) keys= ;;
  esac
  keys=$(printf '%s\n' "$keys" | tr -s ' \n' '  ')

  # A word that marks a name as the name of a credential, in either case.
  W='([Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss]|[Pp][Ww][Dd]|[Aa][Uu][Tt][Hh]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll]|[Bb][Ee][Aa][Rr][Ee][Rr]|[Cc][Oo][Oo][Kk][Ii][Ee]|[Ss][Ee][Ss][Ss][Ii][Oo][Nn])'
  Q="'"

  awk -v format="$format" -v family="$family" -v showkeys="$keys" -v neverkeys="$NEVER_KEYS" '
    BEGIN {
      n = split(showkeys, list, " ")
      for (i = 1; i <= n; i++) {
        if (length(list[i]) > 3 && substr(list[i], length(list[i]) - 2) == ">[]") LISTCTX[substr(list[i], 1, length(list[i]) - 3)] = 1
        else if (match(list[i], /=[A-Za-z0-9_]+$/)) HOME[substr(list[i], 1, RSTART - 1)] = substr(list[i], RSTART + 1)
        else if (match(list[i], /:[A-Za-z!]+$/)) ALLOW[substr(list[i], 1, RSTART - 1)] = substr(list[i], RSTART + 1)
      }
      n = split(neverkeys, list, " "); for (i = 1; i <= n; i++) NEVER[list[i]] = 1
      UNKNOWN = "\001"
      # Closed sets of values, and two fixed forms.
      ENUM["arch"] = "x86_64|arm64"
      ENUM["auth"] = "AWS_IAM|NONE"
      ENUM["inv"] = "BUFFERED|RESPONSE_STREAM"
      ENUM["trc"] = "Active|PassThrough|Disabled"
      ENUM["pkg"] = "Zip|Image"
      ENUM["lfmt"] = "Text|JSON"
      ENUM["llvl"] = "TRACE|DEBUG|INFO|WARN|ERROR|FATAL"
      ENUM["eff"] = "Allow|Deny"
      ENUM["iamm"] = "shared|perFunction"
      ENUM["perd"] = "DAY|WEEK|MONTH"
      ENUM["atype"] = "jwt|request|token|aws_iam|cognito_user_pools|JWT|REQUEST|TOKEN|AWS_IAM|COGNITO_USER_POOLS"
      ENUM["meth"] = "get|post|put|patch|delete|head|options|any|GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|ANY|[*]"
      ENUM["plc"] = "smart|off"
      ENUM["pool"] = "transaction|session"
      ENUM["epol"] = "oneshot|per_worker"
      ENUM["upd"] = "Auto|FunctionUpdate|Manual"
      ENUM["snap"] = "PublishedVersions|None"
      ENUM["rg"] = "[a-z][a-z](-gov)?-[a-z]+-[0-9]+"
      ENUM["vrg"] = "[a-z][a-z][a-z][0-9]|all"
      ENUM["iamrole"] = "arn:aws[a-z-]*:iam::[0-9]+:role/[A-Za-z0-9_+=,.@/-]+"
      ENUM["prin"] = "[*]|[0-9]+|arn:aws[a-z-]*:iam::[0-9]+:[A-Za-z0-9_+=,.@/:-]+"
      ENUM["svc"] = "[a-z0-9.-]+[.]amazonaws[.]com([.]cn)?"
      ENUM["prsv"] = ENUM["prin"] "|" ENUM["svc"]
      ENUM["lyr"] = "arn:aws[a-z-]*:lambda:[a-z0-9-]+:[0-9]+:layer:[A-Za-z0-9_-]+:[0-9]+"
      ENUM["arn"] = "arn:aws[a-z-]*:[a-z0-9-]+:[a-z0-9-]*:[0-9]*:[A-Za-z0-9_+=,.@/:*-]+"
      ENUM["hl"] = "[A-Za-z0-9*-]+(, *[A-Za-z0-9*-]+)*"
      # JSON
      jsp = 0; jexp = "v"; jcur = ""; jstr = 0; jcom = 0
      # YAML
      ysp = 0; yrootchild = ""; yh = -1; yhd = 0; yq = ""; yflow = 0; ypend = 0
      # TOML
      tml = ""; tq = ""; tarr = 0; tctx = "top"; tl = 0
      # HCL
      hsp = 0; hdepth = 0; hdoc = ""; hblk = 0; hstr = 0
      # env
      envq = ""
    }

    function max(a, b) { return (a > b) ? a : b }

    function cnt(s, ch,    c, i) {
      c = 0
      for (i = 1; i <= length(s); i++) if (substr(s, i, 1) == ch) c++
      return c
    }

    # A line that still holds a carriage return after its end is cut is not
    # a line the handlers can judge: it is hidden whole.
    function emit(s) { printf "%6d\t%s\n", NR, (CRLINE ? "<redacted>" : s) }

    # 2 for a key that is never shown (below it, names hide too), else 0.
    function keyclass(k,    lk) {
      if (k == UNKNOWN || index(k, "\\")) return 2
      if (k in NEVER) return 2
      if (k == "parameters" && family == "serverless") return 2
      lk = tolower(k); gsub(/[-_]/, "", lk)
      if (lk ~ /secret|token|passw|credential|privatekey|apikey|accesskey|connectionstring|databaseurl/) return 2
      return 0
    }

    # The context of the container that key opens, inside context ctx.
    # A key that no entry names opens "x", where only names print.
    function ctxof(ctx, key) {
      if (key == UNKNOWN || index(key, "\\")) return "x"
      if ((ctx ">" key) in HOME) return HOME[ctx ">" key]
      if ((ctx ">*") in HOME && keyclass(key) < 2) return HOME[ctx ">*"]
      return "x"
    }

    # The level below key: 2 hides names and values, 0 shows names. A key
    # that an entry names as a home holds over the never-shown list.
    function lvlof(ctx, key, lvl) {
      if (lvl >= 2) return 2
      if ((ctx ">" key) in HOME && !index(key, "\\")) return lvl
      return (keyclass(key) >= 2) ? 2 : lvl
    }

    # The shape a shown value must have, or "" when the value hides.
    function decide(key, ctx, lvl,    e) {
      if (lvl >= 2 || key == UNKNOWN || index(key, "\\")) return ""
      e = ""
      if ((ctx ">" key) in ALLOW) e = ALLOW[ctx ">" key]
      else if ((ctx ">*") in ALLOW) e = ALLOW[ctx ">*"]
      if (e == "") return ""
      if (substr(e, length(e)) == "!") return substr(e, 1, length(e) - 1)
      if (keyclass(key) == 2) return ""
      return e
    }

    # A value without its quotes. UNKNOWN when a quote has no partner.
    function unq(v,    q) {
      q = substr(v, 1, 1)
      if (q != "\"" && q != "\047") return v
      if (length(v) >= 2 && substr(v, length(v)) == q) return substr(v, 2, length(v) - 2)
      return UNKNOWN
    }

    # A path or a route: no query, no user, no fragment, and no part that looks like a token.
    # A segment of the path itself (not the host) longer than 15 characters can
    # be a shared secret made of letters only, so it hides the value too.
    function pathok(s,    n, parts, i, seg, t, host) {
      if (length(s) > 200) return 0
      if (s ~ /[?=@#%" \t\\]/ || index(s, "\047")) return 0
      host = (s ~ /^https?:\/\//)
      sub(/^https?:\/\//, "", s)
      if (index(s, "://")) return 0
      n = split(s, parts, "/")
      if (!host && n > 1 && parts[1] ~ /[A-Za-z0-9-][.][A-Za-z]/ && parts[1] !~ /^[.]/) host = 1
      for (i = 1; i <= n; i++) {
        seg = parts[i]
        if (length(seg) > 40) return 0
        if (length(seg) > 15 && !(host && i == 1)) return 0
        t = seg; gsub(/[A-Za-z0-9._*:{}()$+~-]/, "", t); gsub(/\[/, "", t); gsub(/\]/, "", t)
        if (t != "") return 0
        if (length(seg) >= 8 && seg ~ /[0-9]/ && seg ~ /[A-Za-z]/) return 0
        if (seg ~ /[A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z][A-Z]/) return 0
      }
      return 1
    }

    function okval(v, shape,    s, t) {
      s = unq(v)
      if (s == UNKNOWN || s == "") return 0
      if (index(s, "\\") || index(s, "\"") || index(s, "\047")) return 0
      if (shape != "n" && shape != "m" && substr(s, 1, 1) == "-") return 0
      if (shape in ENUM) return s ~ ("^(" ENUM[shape] ")$")
      if (shape == "n") return s ~ /^-?[0-9]+([.][0-9]+)?$/
      if (shape == "m") return s ~ /^[0-9]+$/ || s == "max"
      if (shape == "b") return s ~ /^(true|false|True|False|TRUE|FALSE|yes|no|on|off)$/
      if (shape == "d") return s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/
      if (shape == "w") {
        t = s; gsub(/[$][{][A-Za-z0-9_.:-]*[}]/, "S", t)
        return length(s) <= 128 && t ~ /^[A-Za-z0-9_.:*\/+,-]+$/ && index(s, "//") == 0
      }
      if (shape == "t") return length(s) <= 80 && s ~ /^[A-Za-z0-9 _.:,()\/*+-]+$/
      # A schedule has fields, or is rate(<number> <unit>), cron(<fields>), or @name.
      if (shape == "c") {
        if (length(s) > 64 || s !~ /^[A-Za-z0-9 *\/,?#().-]+$/) return 0
        if (s ~ /^rate[(]/) return s ~ /^rate[(][0-9]+ [a-z]+[)]$/
        if (s ~ /^cron[(]/) return s ~ /^cron[(][0-9A-Z*?\/,#L-]+( [0-9A-Z*?\/,#L-]+)+[)]$/
        return index(s, " ") > 0 || s ~ /^@[a-z]+$/
      }
      if (shape == "p") return pathok(s)
      if (shape == "rp") return pathok(s) && index(s, "/") > 0
      if (shape == "r") { t = s; sub(/^[A-Za-z*]+ +/, "", t); return pathok(t) }
      if (shape == "o") return s == "*" || s ~ /^https?:\/\/[A-Za-z0-9.*-]+(:[0-9]+)?\/?$/
      if (shape == "a") return s ~ /^https?:\/\/[A-Za-z0-9.-]+(:[0-9]+)?(\/.*)?$/ && pathok(s)
      if (shape == "u") return length(s) <= 128 && s ~ /^[A-Za-z0-9_.\/-]+(@[A-Za-z0-9_.-]+)?$/
      if (shape == "pm") return s ~ /^(read|write|none|read-all|write-all)$/
      return 0
    }

    # A value that only names where a secret lives.
    function isref(v,    s) {
      s = unq(v)
      if (s == UNKNOWN || length(s) > 120) return 0
      if (s ~ /^[$][{][{] *(secrets|vars|env|matrix|inputs|github|steps|needs|runner|job)[.][A-Za-z0-9_.-]+ *[}][}]$/) return 1
      if (s ~ /^env[(][A-Za-z_][A-Za-z0-9_]*[)]$/) return 1
      if (s ~ /^[$][{](ssm|secretsmanager|env)(:|[(][a-z]+[)]:)[A-Za-z0-9_\/.:~-]+[}]$/) return 1
      return 0
    }

    # A list on one line, element by element. "" when it cannot be shown so.
    # An element that starts with a dash is a flag: it hides, and so does the next.
    function listval(v, shape,    inner, n, parts, i, e, out, pend) {
      if (substr(v, 1, 1) != "[" || substr(v, length(v)) != "]") return ""
      inner = substr(v, 2, length(v) - 2)
      if (index(inner, "[") || index(inner, "]") || index(inner, "{") || index(inner, "}")) return ""
      n = split(inner, parts, ",")
      out = ""; pend = 0
      for (i = 1; i <= n; i++) {
        e = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", e)
        if (i > 1) out = out ", "
        if (e == "") continue
        if (substr(unq(e), 1, 1) == "-") { pend = 1; out = out "<redacted>"; continue }
        if (pend) { pend = 0; out = out "<redacted>"; continue }
        out = out (okval(e, shape) ? e : "<redacted>")
      }
      return "[" out "]"
    }

    function render(v, shape, namesvisible,    r) {
      if (shape != "" && substr(v, 1, 1) == "[") {
        r = listval(v, shape)
        return (r == "") ? "<redacted>" : r
      }
      if (shape != "" && okval(v, shape)) return v
      if (namesvisible && isref(v)) return v
      return "<redacted>"
    }

    # Where an unescaped double quote closes, from position from. 0 when none.
    function strend(s, from,    i, c, n) {
      n = length(s)
      for (i = from; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\") { i++; continue }
        if (c == "\"") return i
      }
      return 0
    }

    # ---- JSON and JSON with comments ----
    # A frame for each open object or array: its type, the key it belongs
    # to, the context and level of its children, and the context and level
    # where its key sits. An object inside an array shares the array s frame data.

    function jpush(t,    k, c, l, pc, pl) {
      if (jsp == 0) { k = ""; c = "top"; l = 0; pc = ""; pl = 0 }
      else if (jt[jsp] == "o") {
        k = (jexp == "v") ? jcur : UNKNOWN
        pc = jc[jsp]; pl = jl[jsp]
        c = ctxof(pc, k); l = lvlof(pc, k, pl)
      } else {
        k = jk[jsp]; c = jc[jsp]; l = jl[jsp]; pc = jpc[jsp]; pl = jpl[jsp]
        # An object in an array is in a home only when the home is a list.
        if (t == "o" && !(c in LISTCTX)) c = "x"
      }
      jsp++
      jt[jsp] = t; jk[jsp] = k; jc[jsp] = c; jl[jsp] = l; jpc[jsp] = pc; jpl[jsp] = pl
      jack[jsp] = 0; jpend[jsp] = 0; jln[jsp] = NR
    }

    function jvalue(tok,    hidden, key, fl, shape, r) {
      hidden = (substr(tok, 1, 1) == "\"") ? "\"<redacted>\"" : "<redacted>"
      if (jsp == 0) return hidden
      if (jt[jsp] == "o") {
        if (jexp != "v") return hidden
        key = jcur; fl = jl[jsp]
        shape = decide(key, jc[jsp], fl)
        # A vercel.json header: the value shows only for an Access-Control- key,
        # as an origin for Allow-Origin and as a list of words for the others.
        if (family == "vercel" && jc[jsp] == "hdr" && fl == 0) {
          if (key == "key") jack[jsp] = (unq(tok) == "Access-Control-Allow-Origin") ? 1 : ((unq(tok) ~ /^Access-Control-/) ? 2 : 0)
          if (key == "value") shape = (jack[jsp] == 1) ? "o" : ((jack[jsp] == 2) ? "hl" : "")
        }
        r = render(tok, shape, fl < 2)
        return (r == "<redacted>") ? hidden : r
      }
      # An element of an array: shown only on the line the array opens, and
      # never after a flag.
      if (NR != jln[jsp] || jl[jsp] >= 2) return hidden
      if (jpend[jsp]) { jpend[jsp] = 0; return hidden }
      if (substr(unq(tok), 1, 1) == "-") { jpend[jsp] = 1; return hidden }
      shape = decide(jk[jsp], jpc[jsp], jpl[jsp])
      if (shape != "" && okval(tok, shape)) return tok
      return hidden
    }

    function json_line(line,    out, i, n, ch, p, s, j, tok) {
      out = ""; i = 1; n = length(line)
      if (jcom) {
        p = index(line, "*/")
        if (!p) return "<redacted>"
        jcom = 0; out = "<redacted> */"; i = p + 2
      }
      if (jstr) {
        p = strend(line, 1)
        if (!p) return "<redacted>"
        jstr = 0; out = out "<redacted>\""; i = p + 1; jexp = "c"
      }
      while (i <= n) {
        ch = substr(line, i, 1)
        if (ch == " " || ch == "\t") { out = out ch; i++; continue }
        if (ch == "/" && substr(line, i + 1, 1) == "/") { out = out "// <redacted>"; break }
        if (ch == "/" && substr(line, i + 1, 1) == "*") {
          p = index(substr(line, i + 2), "*/")
          if (!p) { jcom = 1; out = out "/* <redacted>"; break }
          out = out "/* <redacted> */"; i = i + p + 3; continue
        }
        if (ch == "\"") {
          p = strend(line, i + 1)
          if (!p) { jstr = 1; out = out "\"<redacted>"; break }
          s = substr(line, i + 1, p - i - 1)
          i = p + 1
          if (jsp > 0 && jt[jsp] == "o" && jexp == "k") {
            jexp = ":"
            if (substr(line, i) ~ /^[ \t]*:/ && !index(s, "\\")) {
              jcur = s
              out = out ((jl[jsp] >= 2) ? "\"<redacted>\"" : "\"" s "\"")
            } else { jcur = UNKNOWN; out = out "\"<redacted>\"" }
            continue
          }
          out = out jvalue("\"" s "\""); jexp = "c"
          continue
        }
        if (ch == ":") { out = out ch; if (jexp == ":") jexp = "v"; i++; continue }
        if (ch == ",") { out = out ch; jexp = (jsp > 0 && jt[jsp] == "o") ? "k" : "v"; i++; continue }
        if (ch == "{" || ch == "[") {
          jpush((ch == "{") ? "o" : "a"); out = out ch; jexp = (ch == "{") ? "k" : "v"; i++; continue
        }
        if (ch == "}" || ch == "]") { if (jsp > 0) jsp--; out = out ch; jexp = "c"; i++; continue }
        # A bare value: a number, true, false, null, or anything else.
        j = i
        while (j <= n) {
          ch = substr(line, j, 1)
          if (ch ~ /[ \t,:{}"\/]/ || ch == "[" || ch == "]") break
          j++
        }
        if (j == i) j = i + 1
        tok = substr(line, i, j - i)
        out = out jvalue(tok); jexp = "c"; i = j
      }
      return out
    }

    # ---- YAML ----
    # A stack of the keys that hold a block, with their indent. A line more
    # indented than yh is hidden: the rest of a block scalar, of a plain
    # scalar that goes on, or of a key that is never shown.

    function quoteend(s, q,    i, c) {
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == "\"" && c == "\\") { i++; continue }
        if (c == q) {
          if (q == "\047" && substr(s, i + 1, 1) == q) { i++; continue }
          return 1
        }
      }
      return 0
    }

    # Brackets opened minus brackets closed, outside quotes.
    function flowdelta(s,    i, c, q, d) {
      d = 0; q = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q != "") {
          if (q == "\"" && c == "\\") { i++; continue }
          if (c == q) q = ""
          continue
        }
        if (c == "\"" || c == "\047") { q = c; continue }
        if (c == "[" || c == "{") d++
        if (c == "]" || c == "}") d--
      }
      return d
    }

    # A key at the start of s. Sets YK, YKL (the length of the key and its colon), and YV.
    function ykeyparse(s,    q, i, c, n) {
      YK = ""; YKL = 0; YV = ""
      n = length(s); q = substr(s, 1, 1)
      if (q == "\"" || q == "\047") {
        for (i = 2; i <= n; i++) {
          c = substr(s, i, 1)
          if (q == "\"" && c == "\\") { i++; continue }
          if (c == q) { if (q == "\047" && substr(s, i + 1, 1) == q) { i++; continue } break }
        }
        if (i > n || substr(s, i + 1, 1) != ":") return 0
        c = substr(s, i + 2, 1)
        if (c != "" && c != " " && c != "\t") return 0
        YK = substr(s, 2, i - 2)
        if (index(YK, "\\")) YK = UNKNOWN
        YKL = i + 1; YV = substr(s, i + 2)
        return 1
      }
      if (q == "" || index("[]{},&*!|>%@`#?", q)) return 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "#" && substr(s, i - 1, 1) ~ /[ \t]/) return 0
        if (c == ":") {
          c = substr(s, i + 1, 1)
          if (c == "" || c == " " || c == "\t") break
        }
      }
      if (i > n) return 0
      YK = substr(s, 1, i - 1); sub(/[ \t]+$/, "", YK)
      if (YK == "") return 0
      YKL = i; YV = substr(s, i + 1)
      return 1
    }

    # The value without a trailing comment. Sets YC when there was one.
    function ystrip(v,    i, c, q, n) {
      YC = 0; q = ""; n = length(v)
      for (i = 1; i <= n; i++) {
        c = substr(v, i, 1)
        if (q != "") {
          if (q == "\"" && c == "\\") { i++; continue }
          if (c == q) { if (q == "\047" && substr(v, i + 1, 1) == q) { i++; continue } q = "" }
          continue
        }
        if ((c == "\"" || c == "\047") && (i == 1 || substr(v, i - 1, 1) ~ /[ \t,{]/ || substr(v, i - 1, 1) == "[")) { q = c; continue }
        if (c == "#" && (i == 1 || substr(v, i - 1, 1) ~ /[ \t]/)) { YC = 1; return substr(v, 1, i - 1) }
      }
      return v
    }

    # One value after a key or a dash. col is the indent under which a value
    # that goes on is hidden. Returns the text to print.
    function yvalue(v, shape, namesvisible, col,    q, pre) {
      pre = ""
      while (v ~ /^[&!][^ \t]*([ \t]|$)/) {
        match(v, /^[&!][^ \t]*[ \t]*/)
        pre = pre substr(v, 1, RLENGTH); v = substr(v, RLENGTH + 1)
      }
      if (pre !~ /^([&!][A-Za-z0-9_:!.-]*[ \t]+)*([&!][A-Za-z0-9_:!.-]*)?$/) pre = "<redacted> "
      if (pre != "" && pre !~ /[ \t]$/) pre = pre " "
      q = substr(v, 1, 1)
      if (v == "") { yh = col; return pre "<redacted>" }
      if (q == "|" || q == ">") { yh = col; return pre "<redacted>" }
      if ((q == "\"" || q == "\047") && !quoteend(substr(v, 2), q)) { yq = q; return pre "<redacted>" }
      yh = col; yhd = 0
      if (q == "[" || q == "{") {
        if (flowdelta(v) > 0) { yflow = flowdelta(v); return pre "<redacted>" }
        if (q == "{") return pre "<redacted>"
      }
      return pre render(v, shape, namesvisible)
    }

    function yaml_line(line,    ind, rest, col, ndash, top, ctx, fl, nl, shape, v, prefix, out, cm) {
      if (yq != "") { if (quoteend(line, yq)) yq = ""; return "<redacted>" }
      if (yflow > 0) { yflow += flowdelta(line); if (yflow < 0) yflow = 0; return "<redacted>" }
      if (line ~ /^[ \t]*$/) return line
      match(line, /^ */); ind = RLENGTH
      if (yh >= 0) {
        if (ind > yh) return "<redacted>"
        if (yhd && ind == yh && substr(line, ind + 1) ~ /^-([ \t]|$)/) return "<redacted>"
        yh = -1; yhd = 0
      }
      if (substr(line, ind + 1, 1) == "\t") return "<redacted>"
      if (line ~ /^[ ]*#/) return "# <redacted>"
      if (line ~ /^(---|[.][.][.])[ \t]*$/) return line
      if (line ~ /^(---|[.][.][.])/) return "<redacted>"

      rest = substr(line, ind + 1); col = ind; ndash = 0
      while (rest ~ /^-([ \t]|$)/) {
        ndash++; match(rest, /^-[ \t]*/); col += RLENGTH; rest = substr(rest, RLENGTH + 1)
      }
      if (ndash > 1) { yh = ind; return "<redacted>" }
      if (ndash == 0) ypend = 0

      if (ndash == 1) {
        # An item of a sequence: a frame at the dash, in its home only when
        # the home is a list, and otherwise in "x".
        while (ysp > 0 && (yind[ysp] > ind || (yind[ysp] == ind && ykey[ysp] == "-"))) ysp--
        if (rest == "" || ykeyparse(rest)) {
          top = ysp
          ysp++; yind[ysp] = ind; ykey[ysp] = "-"
          yctx[ysp] = (top && (yctx[top] in LISTCTX)) ? yctx[top] : "x"
          ylvl[ysp] = top ? ylvl[top] : 0; ypctx[ysp] = yctx[ysp]; yplvl[ysp] = ylvl[ysp]
          ychild[ysp] = (rest == "") ? "" : col
          if (rest == "") return line
        }
      }
      if (ykeyparse(rest)) {
        while (ysp > 0 && yind[ysp] >= col) ysp--
        # The keys of one map share an indent. A key at another indent is
        # broken YAML: it and everything below it are hidden.
        if (ysp > 0) { if (ychild[ysp] == "") ychild[ysp] = col; else if (ychild[ysp] != col) { yh = col; yhd = 1; return "<redacted>" } }
        else { if (yrootchild == "") yrootchild = col; else if (yrootchild != col) { yh = col; yhd = 1; return "<redacted>" } }
        if (ndash == 1) ypend = 0
        top = ysp; ctx = top ? yctx[top] : "top"; fl = top ? ylvl[top] : 0
        if (fl >= 2) { yh = col; yhd = 1; return "<redacted>" }
        prefix = substr(line, 1, col + YKL)
        v = ystrip(YV); cm = YC ? " # <redacted>" : ""
        gsub(/^[ \t]+|[ \t]+$/, "", v)
        nl = lvlof(ctx, YK, fl)
        if (v == "" ) {
          if (nl >= 2) { yh = col; yhd = 1 }
          else { ysp++; yind[ysp] = col; ykey[ysp] = YK; yctx[ysp] = ctxof(ctx, YK); ylvl[ysp] = nl; ypctx[ysp] = ctx; yplvl[ysp] = fl; ychild[ysp] = "" }
          return prefix cm
        }
        shape = decide(YK, ctx, fl)
        out = yvalue(v, shape, 1, col)
        # A key that is never shown, with a block below it: its sequence hides too.
        if (nl >= 2 && yh == col) yhd = 1
        return prefix " " out cm
      }

      if (ndash == 0) { yh = ind; return "<redacted>" }
      # An item of a sequence.
      while (ysp > 0 && (yind[ysp] > ind || (yind[ysp] == ind && ykey[ysp] == "-"))) ysp--
      v = ystrip(rest); cm = YC ? " # <redacted>" : ""
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      top = ysp
      if (top == 0) { yvalue(v, "", 0, ind); return substr(line, 1, col) "<redacted>" cm }
      shape = decide(ykey[top], ypctx[top], yplvl[top])
      if (ypend) { ypend = 0; shape = "" }
      if (substr(unq(v), 1, 1) == "-") { ypend = 1; shape = "" }
      return substr(line, 1, col) yvalue(v, shape, 0, ind) cm
    }

    # ---- TOML ----

    # The text with strings emptied. Sets TCOM (where a comment starts, 0 for
    # none) and TOPEN (the quote of a string that stays open).
    function tstrip(s,    out, i, c, q, n) {
      out = ""; q = ""; TCOM = 0; TOPEN = ""; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q != "") {
          if (c == "\\" && q == "\"") { i++; continue }
          if (c == q) { q = ""; out = out c }
          continue
        }
        if (c == "\"" || c == "\047") { q = c; out = out c; continue }
        if (c == "#") { TCOM = i; break }
        out = out c
      }
      TOPEN = q
      return out
    }

    function tdepth(st) { return cnt(st, "[") + cnt(st, "{") - cnt(st, "]") - cnt(st, "}") }

    # A line that opens a multi-line string. Sets TMLD to its delimiter.
    function tmlopen(s,    t, n) {
      t = s; n = gsub(/"""/, "", t)
      if (n % 2) { TMLD = "\"\"\""; return 1 }
      t = s; n = gsub(/\047\047\047/, "", t)
      if (n % 2) { TMLD = "\047\047\047"; return 1 }
      return 0
    }

    function toml_line(line,    st, plain, inner, n, parts, i, ktxt, k, v, vv, fl, c, leaf, d, hidden) {
      if (tml != "") { if (index(line, tml)) tml = ""; return "<redacted>" }
      if (tq != "") { if (index(line, tq)) tq = ""; return "<redacted>" }
      if (tarr > 0) {
        if (tmlopen(line)) { tml = TMLD; return "<redacted>" }
        st = tstrip(line); tarr += tdepth(st)
        if (TOPEN != "") tq = TOPEN
        if (tarr < 0) tarr = 0
        return "<redacted>"
      }
      if (line ~ /^[ \t]*$/) return line
      if (line ~ /^[ \t]*#/) return "# <redacted>"
      st = tstrip(line)
      plain = TCOM ? substr(line, 1, TCOM - 1) : line
      sub(/[ \t]+$/, "", plain)
      if (TOPEN == "" && plain ~ /^[ \t]*\[\[?[ \t]*[A-Za-z0-9_."\047 -]+[ \t]*\]\]?$/) {
        inner = plain; gsub(/[ \t"\047]/, "", inner); gsub(/\[/, "", inner); gsub(/\]/, "", inner)
        n = split(inner, parts, ".")
        tl = 0; tctx = "top"
        for (i = 1; i <= n; i++) { tl = lvlof(tctx, parts[i], tl); tctx = ctxof(tctx, parts[i]) }
        return plain (TCOM ? " # <redacted>" : "")
      }
      # A header the reader does not recognise: nothing below it shows until the next good one.
      if (plain ~ /^[ \t]*\[/) { tl = 2; tctx = "x"; return "<redacted>" }
      if (match(line, /^[ \t]*([A-Za-z0-9_-]+|"[^"\\]*"|\047[^\047]*\047)([ \t]*[.][ \t]*([A-Za-z0-9_-]+|"[^"\\]*"|\047[^\047]*\047))*[ \t]*=/)) {
        ktxt = substr(line, 1, RLENGTH); v = substr(line, RLENGTH + 1)
        k = ktxt; sub(/=$/, "", k); gsub(/[ \t"\047]/, "", k)
        n = split(k, parts, ".")
        fl = tl; c = tctx
        for (i = 1; i < n; i++) { fl = lvlof(c, parts[i], fl); c = ctxof(c, parts[i]) }
        leaf = parts[n]
        hidden = (fl >= 2) ? "<redacted>" : ktxt " <redacted>"
        sub(/^[ \t]+/, "", v)
        if (substr(v, 1, 3) == "\"\"\"" || substr(v, 1, 3) == "\047\047\047") {
          d = substr(v, 1, 3)
          if (index(substr(v, 4), d) == 0) tml = d
          return hidden
        }
        st = tstrip(v)
        if (TOPEN != "") { tq = TOPEN; return hidden }
        d = tdepth(st)
        if (d > 0) { tarr = d; return hidden }
        if (fl >= 2) return hidden
        vv = TCOM ? substr(v, 1, TCOM - 1) : v
        sub(/[ \t]+$/, "", vv)
        return ktxt " " render(vv, decide(leaf, c, fl), 1) (TCOM ? " # <redacted>" : "")
      }
      if (tmlopen(line)) tml = TMLD
      else if (TOPEN != "") tq = TOPEN
      return "<redacted>"
    }

    # ---- HCL: Terraform, OpenTofu, and variable files ----
    # A frame for each open block or value: its key, the level of its
    # children, the level it sits at, and the depth inside it.

    # The text with strings emptied and comments cut. Sets HCOM (where the
    # comment starts, 0 for none), HBLK (a block comment stays open), HOPEN
    # (a string stays open), and HDOC (the end word of a heredoc).
    function hstrip(s,    out, i, c, n, q, p) {
      out = ""; n = length(s); HCOM = 0; HBLK = 0; HOPEN = 0; HDOC = ""; q = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (q) {
          if (c == "\\") { i++; continue }
          if (c == "\"") { q = 0; out = out c }
          continue
        }
        if (c == "\"") { q = 1; out = out c; continue }
        if (c == "#" || (c == "/" && substr(s, i + 1, 1) == "/")) { if (!HCOM) HCOM = i; break }
        if (c == "/" && substr(s, i + 1, 1) == "*") {
          if (!HCOM) HCOM = i
          p = index(substr(s, i + 2), "*/")
          if (!p) { HBLK = 1; break }
          i = i + p + 2; continue
        }
        if (c == "<" && substr(s, i + 1, 1) == "<" && match(substr(s, i + 2), /^-?[A-Za-z_][A-Za-z0-9_]*/)) {
          HDOC = substr(s, i + 2, RLENGTH); sub(/^-/, "", HDOC)
          out = out "<<"; i = i + 1 + RLENGTH; continue
        }
        out = out c
      }
      if (q) HOPEN = 1
      return out
    }

    function hnet(st) {
      return cnt(st, "{") + cnt(st, "[") + cnt(st, "(") - cnt(st, "}") - cnt(st, "]") - cnt(st, ")")
    }

    # A frame: the context and level of its children, and the depth inside it.
    function hpush(c, l, d) { hsp++; hc[hsp] = c; hl[hsp] = l; hd[hsp] = d }

    function hmove(net,    fl) {
      if (net > 0) hpush("x", 2, hdepth + net)
      hdepth += net
      while (hsp > 0 && hd[hsp] > hdepth) hsp--
    }

    # What follows the end of a hidden span on the same line counts for depth only.
    function hrest(s,    st) {
      st = hstrip(s); hmove(hnet(st))
      hblk = HBLK; hstr = HOPEN; if (HDOC != "") hdoc = HDOC
    }

    function onlystruct(s,    t) {
      t = s; gsub(/[ \t{}(),]/, "", t); gsub(/\[/, "", t); gsub(/\]/, "", t)
      return t == ""
    }

    # The lowest depth reached on the line, relative to its start.
    function hdip(st,    i, c, d, m) {
      d = 0; m = 0
      for (i = 1; i <= length(st); i++) {
        c = substr(st, i, 1)
        if (c == "{" || c == "[" || c == "(") d++
        else if (c == "}" || c == "]" || c == ")") { d--; if (d < m) m = d }
      }
      return m
    }

    function hcl_onlystruct(line, com,    t) {
      t = com ? substr(line, 1, com - 1) : line
      return onlystruct(t)
    }

    function hcl_line(line,    t, p, st, net, disp, cm, top, ctx, fl, out, key, pre, v, tfvars, lab, mind) {
      if (hdoc != "") { t = line; gsub(/^[ \t]+|[ \t]+$/, "", t); if (t == hdoc) hdoc = ""; return "<redacted>" }
      if (hblk) {
        p = index(line, "*/"); if (!p) return "<redacted>"
        hblk = 0; hrest(substr(line, p + 2)); return "<redacted>"
      }
      if (hstr) {
        p = strend(line, 1); if (!p) return "<redacted>"
        hstr = 0; hrest(substr(line, p + 1)); return "<redacted>"
      }
      if (line ~ /^[ \t]*$/) return line
      tfvars = (family == "tfvars")
      st = hstrip(line)
      net = hnet(st)
      # A line that closes a block and then opens another: the new block is
      # unknown, so nothing below it shows until it closes.
      mind = hdip(st)
      if (mind < 0 && net > mind && !hcl_onlystruct(line, HCOM)) {
        hdepth += mind
        while (hsp > 0 && hd[hsp] > hdepth) hsp--
        hpush("x", 2, hdepth + net - mind)
        hdepth += net - mind
        hblk = HBLK; hstr = HOPEN; if (HDOC != "") hdoc = HDOC
        return "<redacted>"
      }
      disp = HCOM ? substr(line, 1, HCOM - 1) : line
      sub(/[ \t]+$/, "", disp)
      cm = (HCOM && !tfvars) ? " # <redacted>" : ""
      top = hsp; ctx = top ? hc[top] : "top"; fl = top ? hl[top] : 0
      if (disp ~ /^[ \t]*$/) {
        out = HCOM ? "# <redacted>" : "<redacted>"
        if (net > 0) hpush("x", 2, hdepth + net)
      } else if (!tfvars && disp ~ /^[ \t]*[A-Za-z_][A-Za-z0-9_-]*([ \t]+("[^"\\]*"|[A-Za-z_][A-Za-z0-9_-]*))*[ \t]*[{]$/) {
        key = disp; sub(/^[ \t]+/, "", key); sub(/[ \t"{].*$/, "", key)
        # A resource or data block is named by its type.
        if ((key == "resource" || key == "data") && match(disp, /"[A-Za-z0-9_]+"/)) {
          lab = substr(disp, RSTART + 1, RLENGTH - 2); key = key "." lab
        }
        out = (fl >= 2) ? "<redacted>" : disp cm
        if (net > 0) hpush(ctxof(ctx, key), lvlof(ctx, key, fl), hdepth + net)
      } else if (match(disp, /^[ \t]*("[^"\\]*"|[A-Za-z_][A-Za-z0-9_-]*)[ \t]*[=:]/) && substr(disp, RLENGTH + 1, 1) != "=") {
        pre = substr(disp, 1, RLENGTH); v = substr(disp, RLENGTH + 1); sub(/^[ \t]+/, "", v)
        key = pre; sub(/^[ \t]+/, "", key); sub(/[ \t]*[=:]$/, "", key); gsub(/"/, "", key)
        if (tfvars) {
          out = (top == 0) ? pre " <redacted>" : "<redacted>"
          if (net > 0) hpush("x", 2, hdepth + net)
        } else {
          if (fl >= 2) out = "<redacted>"
          else if (HDOC != "" || HOPEN || HBLK || net != 0) out = (net > 0 && v ~ /^[[{( \t]+$/) ? pre " " v : pre " <redacted>"
          else out = pre " " render(v, decide(key, ctx, fl), 1)
          if (net > 0) hpush(ctxof(ctx, key), lvlof(ctx, key, fl), hdepth + net)
          if (out != "<redacted>") out = out cm
        }
      } else if (onlystruct(disp)) {
        out = disp cm
      } else {
        out = "<redacted>"
        if (net > 0) hpush("x", 2, hdepth + net)
      }
      hdepth += net
      while (hsp > 0 && hd[hsp] > hdepth) hsp--
      hblk = HBLK; hstr = HOPEN; if (HDOC != "") hdoc = HDOC
      return out
    }

    # ---- env files: names only ----

    function envclose(s, q,    i, c) {
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (q == "\"" && c == "\\") { i++; continue }
        if (c == q) return 1
      }
      return 0
    }

    function env_line(line,    name, v, q) {
      if (envq != "") { if (envclose(line, envq)) envq = ""; return "<redacted>" }
      if (line ~ /^[ \t]*$/) return line
      if (line ~ /^[ \t]*#/) return "# <redacted>"
      if (match(line, /^[ \t]*(export[ \t]+)?[A-Za-z_][A-Za-z0-9_.-]*[ \t]*=/)) {
        name = substr(line, 1, RLENGTH); sub(/^[ \t]+/, "", name)
        v = substr(line, RLENGTH + 1); sub(/^[ \t]+/, "", v)
        q = substr(v, 1, 1)
        if ((q == "\"" || q == "\047" || q == "`") && !envclose(substr(v, 2), q)) envq = q
        return name "<redacted>"
      }
      return "<redacted>"
    }

    { sub(/\r$/, ""); CRLINE = (index($0, "\r") > 0) }
    format == "json" { emit(json_line($0)); next }
    format == "yaml" { emit(yaml_line($0)); next }
    format == "toml" { emit(toml_line($0)); next }
    format == "hcl" { emit(hcl_line($0)); next }
    format == "env" { emit(env_line($0)); next }
    { emit("<redacted>") }
  ' < "$SHOW_FILE" | sed -E \
    -e 's/\\.*$/<redacted:escaped-text>/' \
    -e 's/(AKIA|ASIA)[0-9A-Z]{16}/<redacted:aws-access-key-id>/g' \
    -e 's/-----BEGIN ([A-Z]+ )?PRIVATE KEY-----.*/<redacted:private-key-block>/g' \
    -e 's/(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/<redacted:github-token>/g' \
    -e 's/glpat-[A-Za-z0-9_-]{16,}/<redacted:gitlab-token>/g' \
    -e 's/[sr]k_(live|test)_[A-Za-z0-9_]{8,}/<redacted:stripe-secret-key>/g' \
    -e 's/whsec_[A-Za-z0-9_]{8,}/<redacted:stripe-webhook-secret>/g' \
    -e 's/sk-ant-[A-Za-z0-9_-]{16,}/<redacted:anthropic-api-key>/g' \
    -e 's/sk-(proj-|svcacct-)?[A-Za-z0-9_-]{20,}/<redacted:openai-api-key>/g' \
    -e 's/AIza[0-9A-Za-z_-]{35}/<redacted:google-api-key>/g' \
    -e 's/xox[baprs]-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/xapp-[A-Za-z0-9-]{10,}/<redacted:slack-token>/g' \
    -e 's/sb_secret_[A-Za-z0-9_-]{10,}/<redacted:supabase-secret-key>/g' \
    -e 's/npm_[A-Za-z0-9]{20,}/<redacted:npm-token>/g' \
    -e 's/hf_[A-Za-z0-9]{20,}/<redacted:hugging-face-token>/g' \
    -e 's/SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}/<redacted:sendgrid-key>/g' \
    -e 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/<redacted:json-web-token>/g' \
    -e "s#([A-Za-z][A-Za-z0-9+.-]*://)[^[:space:]\"$Q]*@#\1<redacted>@#g" \
    -e "s#(://[^[:space:]\"$Q?]*)\?[^[:space:]\"$Q]*#\1?<redacted>#g" \
    -e "s#(://[^[:space:]\"$Q]*/)[A-Za-z0-9_-]{20,}#\1<redacted>#g" \
    -e "s/((-H|--header)[[:space:]=]+\\\\?[\"$Q]?)[^\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/((-u|--user)[[:space:]=]+)[^[:space:]\"$Q\\\\]+/\1<redacted>/g" \
    -e "s/([[:space:]]-[pa][[:space:]]+)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/([[:space:]]-[pa][[:space:]]+)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/([[:space:]]-p)[[:space:]]?[^[:space:]\"$Q\\\\-][^[:space:]\"$Q\\\\]*/\1 <redacted>/g" \
    -e "s/([[:space:]]-a[[:space:]]+)[^[:space:]\"$Q\\\\-][^[:space:]\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/(--?[Pp][Aa][Tt][=[:space:]]+)[^[:space:]\"$Q\\\\]+/\1<redacted>/g" \
    -e "s#[A-Za-z0-9._-]+:[^[:space:]\"$Q@/<]+@([A-Za-z0-9.-]+)#<redacted>@\1#g" \
    -e "s#(://[^[:space:]\"$Q\#]*)\#[^[:space:]\"$Q]*#\1\#<redacted>#g" \
    -e "s#(^|[\"${Q}[:space:]=:])[A-Za-z0-9/+]{40}([\"${Q}[:space:],]|\$)#\1<redacted>\2#g" \
    -e "s/((Authorization|Proxy-Authorization|Cookie|Set-Cookie|[Xx]-[A-Za-z-]+):[[:space:]]*)[^\"$Q\\\\,]+/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/([A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*=)[^[:space:]\"$Q,;<\$\\\\]+/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)\\\\?\"[^\"]*\"/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)${Q}[^$Q]*$Q/\1<redacted>/g" \
    -e "s/(--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*[[:space:]]+)[^[:space:]\"$Q<\$\\\\-][^[:space:]\"$Q\\\\]*/\1<redacted>/g" \
    -e "s/(\"--?[A-Za-z0-9_-]*${W}[A-Za-z0-9_-]*\"[[:space:]]*,[[:space:]]*\")[^\"]*\"/\1<redacted>\"/g" \
    -e 's/(([Bb]earer|[Bb]asic)[[:space:]]+)[A-Za-z0-9._~+\/=-]{8,}/\1<redacted>/g' |
    # A long word that mixes letters and digits is hidden, whatever its place.
    # A name in capitals with underscores is the name of a variable, and it stays.
    # Inside an address the limit is lower: 8 characters for a label of the
    # host, and for a part of the path.
    awk '
      function mixed(w) { return w ~ /[0-9]/ && w ~ /[A-Za-z]/ }
      function flush(    limit) {
        limit = (url > 0) ? 8 : 20
        if (length(run) >= limit && mixed(run) && !(url == 0 && run ~ /^[A-Z0-9_]+$/ && run ~ /_/) && run !~ /^redacted/) out = out "<redacted>"
        else out = out run
        run = ""
      }
      {
        tab = index($0, "\t")
        s = substr($0, tab + 1); out = ""; run = ""; url = 0
        n = length(s)
        for (i = 1; i <= n; i++) {
          ch = substr(s, i, 1)
          # url: 0 outside an address, 1 in its host, 2 in its path.
          if (url == 0 && substr(s, i, 3) == "://") { flush(); out = out "://"; i += 2; url = 1; continue }
          if (url > 0 && ch ~ /[] \t"\047<>(),;[]/) { flush(); url = 0; out = out ch; continue }
          if (url == 1 && ch == "/") { flush(); url = 2; out = out ch; continue }
          if (url == 2 && ch ~ /[A-Za-z0-9_.~%:+=-]/) { run = run ch; continue }
          if (url == 1 && ch ~ /[A-Za-z0-9]/) { run = run ch; continue }
          if (url == 0 && ch ~ /[A-Za-z0-9_+=-]/) { run = run ch; continue }
          flush(); out = out ch
        }
        flush()
        print substr($0, 1, tab) out
      }
    '
}

case "$MODE" in
  list) list ;;
  show) show ;;
esac
