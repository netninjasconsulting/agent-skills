#!/bin/sh
# read-serverless-config.test.sh: run the serverless configuration reader against the quickship fixture.
#
# Copyright 2026 Net Ninjas Consulting
# SPDX-License-Identifier: Apache-2.0
#
# Usage: sh tests/read-serverless-config.test.sh
#
# Checks four things: the reader lists the platform files the fixture plants
# and nothing else, the hidden view keeps the settings the checks need, env
# files and *.tfvars print names only, and no output of any mode contains a
# planted value. Every planted value holds the marker FIXTUREVALUE. The attack
# files start with the five layouts that defeated the first agent
# configuration reader, then add the layouts of the formats this reader reads.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
reader="$root/skills/serverless-deploy-check/scripts/read-serverless-config.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
fail() {
  echo "FAIL: $1"
  failures=$((failures + 1))
}

expect_line() {
  # $1 = output, $2 = a line that must be present, $3 = label
  printf '%s\n' "$1" | grep -qxF -e "$2" || fail "$3: missing line $2"
}

expect_text() {
  # $1 = output, $2 = text that must be present, $3 = label
  printf '%s\n' "$1" | grep -qF -e "$2" || fail "$3: missing $2"
}

expect_re() {
  # $1 = output, $2 = an extended regular expression that must match a line, $3 = label
  printf '%s\n' "$1" | grep -qE -e "$2" || fail "$3: no line matches $2"
}

no_marker() {
  # $1 = output, $2 = label
  if printf '%s\n' "$1" | grep -qF -e FIXTUREVALUE; then
    fail "$2: a planted value leaked"
  fi
}

names_only() {
  # $1 = output of --show on an env file or *.tfvars, $2 = label
  # Every line is a name with a hidden value, a hidden comment, a hidden line, or blank.
  bad=$(printf '%s\n' "$1" | sed 's/^ *[0-9][0-9]*	//' |
    grep -vxE -e '' -e '# <redacted>' -e '<redacted>' -e '(export )?[A-Za-z_][A-Za-z0-9_.-]* *= *<redacted>' || true)
  [ -z "$bad" ] || fail "$2: a line that is not a name: $bad"
}

[ -f "$reader" ] || { echo "FAIL: the reader does not exist: $reader"; exit 1; }

sh "$root/tests/fixtures/serverless-deploy-check/make-repo.sh" "$work/fx" >/dev/null
repo="$work/fx"

# 1. The list holds exactly the planted configuration files, sorted by path.
list=$(sh "$reader" "$repo")
expected='.dev.vars:cloudflare-workers:env:ignored
.env.local:shared:env:ignored
.github/workflows/deploy.yml:shared:workflow:tracked
infra/main.tf:aws-lambda:infrastructure:tracked
infra/terraform.tfvars:shared:env:tracked
lambda/serverless.yml:aws-lambda:functions:tracked
supabase/config.toml:supabase:functions:tracked
vercel.json:vercel:functions:tracked
worker/wrangler.toml:cloudflare-workers:functions:tracked'
[ "$list" = "$expected" ] || fail "list: expected
$expected
got
$list"
no_marker "$list" "list"

# 2. The hidden view never shows a planted value, for any listed file.
printf '%s\n' "$list" | while IFS= read -r line; do
  path=${line%%:*}
  sh "$reader" --show "$repo/$path" 2>&1 || echo "EXIT $? $path"
done > "$work/all-shown"
grep -q '^EXIT ' "$work/all-shown" && fail "show: a listed file did not show: $(grep '^EXIT ' "$work/all-shown")"
grep -qF -e FIXTUREVALUE "$work/all-shown" && fail "show: a planted value leaked from a listed file"
grep -qE '^ +[0-9]+	' "$work/all-shown" || fail "show: line numbers are missing"

# 3. The hidden view keeps what the checks need.
sls=$(sh "$reader" --show "$repo/lambda/serverless.yml")
expect_re "$sls" 'memorySize: 1769$' "show serverless.yml"
expect_re "$sls" 'timeout: 900$' "show serverless.yml"
expect_re "$sls" 'runtime: nodejs20\.x$' "show serverless.yml"
expect_re "$sls" 'architecture: x86_64$' "show serverless.yml"
expect_re "$sls" 'Action: "\*"$' "show serverless.yml"
expect_re "$sls" 'Resource: "\*"$' "show serverless.yml"
expect_re "$sls" 'logRetentionInDays: 30$' "show serverless.yml"
expect_re "$sls" 'private: true$' "show serverless.yml"
expect_re "$sls" 'url: true$' "show serverless.yml"
expect_re "$sls" 'burstLimit: 20$' "show serverless.yml"
expect_re "$sls" 'path: ingest$' "show serverless.yml"
expect_text "$sls" "apiKeys:" "show serverless.yml"
expect_text "$sls" "DB_PASSWORD:" "show serverless.yml"

wrangler=$(sh "$reader" --show "$repo/worker/wrangler.toml")
expect_text "$wrangler" 'compatibility_date = "2022-03-01"' "show wrangler.toml"
expect_text "$wrangler" 'binding = "CACHE"' "show wrangler.toml"
expect_text "$wrangler" 'name = "LIMITER"' "show wrangler.toml"
expect_text "$wrangler" 'main = "src/index.ts"' "show wrangler.toml"
expect_text "$wrangler" 'limit = 60' "show wrangler.toml"
expect_text "$wrangler" 'CARRIER_TOKEN = <redacted>' "show wrangler.toml"
expect_text "$wrangler" '[vars]' "show wrangler.toml"

supa=$(sh "$reader" --show "$repo/supabase/config.toml")
expect_text "$supa" 'verify_jwt = false' "show supabase config.toml"
expect_text "$supa" '[functions.notify]' "show supabase config.toml"

tf=$(sh "$reader" --show "$repo/infra/main.tf")
expect_re "$tf" 'memory_size += 512$' "show main.tf"
expect_re "$tf" 'timeout += 30$' "show main.tf"
expect_re "$tf" 'architectures += \["arm64"\]$' "show main.tf"
expect_re "$tf" 'runtime += "nodejs24\.x"$' "show main.tf"
expect_re "$tf" 'retention_in_days += 30$' "show main.tf"
expect_text "$tf" 'resource "aws_lambda_function" "resize" {' "show main.tf"

vercel=$(sh "$reader" --show "$repo/vercel.json")
expect_text "$vercel" '"maxDuration": 800' "show vercel.json"
expect_text "$vercel" '"memory": 3009' "show vercel.json"
expect_text "$vercel" '"path": "/api/cron/sync"' "show vercel.json"
expect_text "$vercel" '"schedule": "0 * * * *"' "show vercel.json"
expect_text "$vercel" '"CARRIER_API_TOKEN"' "show vercel.json"

wf=$(sh "$reader" --show "$repo/.github/workflows/deploy.yml")
expect_text "$wf" 'aws-access-key-id:' "show workflow"
expect_text "$wf" 'secrets.AWS_ACCESS_KEY_ID' "show workflow"
expect_text "$wf" 'aws-region: us-east-1' "show workflow"
expect_text "$wf" 'runs-on: ubuntu-latest' "show workflow"
expect_text "$wf" 'uses: aws-actions/configure-aws-credentials@v4' "show workflow"
expect_text "$wf" 'run: <redacted>' "show workflow"

# 4. Env files and *.tfvars print names only.
for path in .env.local .dev.vars infra/terraform.tfvars; do
  out=$(sh "$reader" --show "$repo/$path")
  no_marker "$out" "show $path"
  names_only "$out" "show $path"
done
expect_text "$(sh "$reader" --show "$repo/.env.local")" "SUPABASE_SERVICE_ROLE_KEY=<redacted>" "show .env.local"
expect_text "$(sh "$reader" --show "$repo/infra/terraform.tfvars")" "registry_password = <redacted>" "show terraform.tfvars"

# 5. Attack files. Each is named as the reader expects, so that it is shown,
# and each holds the marker in a place where a weaker reader prints it.
a="$work/attack"
put() {
  # $1 = path under the attack folder; the file content comes on standard input.
  mkdir -p "$(dirname "$a/$1")"
  cat > "$a/$1"
}

# 5a. A flag and its value on separate lines.
put flag/vercel.json <<'JSON'
{
  "includeFiles": [
    "--token",
    "FIXTUREVALUE"
  ],
  "regions": ["iad1",
    "FIXTUREVALUE"]
}
JSON
put flag/wrangler.toml <<'TOML'
compatibility_flags = [
  "--token",
  "FIXTUREVALUE",
]
TOML
put flag/serverless.yml <<'YAML'
package:
  patterns:
    - '--token'
    - FIXTUREVALUE
    - --password
    - FIXTUREVALUE-flag-01
YAML
put flag/main.tf <<'HCL'
resource "aws_lambda_function" "f" {
  layers = [
    "--token",
    "FIXTUREVALUE",
  ]
}
HCL

# 5b. A value that spans lines.
put span/vercel.json <<'JSON'
{
  "regions": "iad1
FIXTUREVALUE",
  "framework": "kept"
}
JSON
put span/wrangler.toml <<'TOML'
name = """
FIXTUREVALUE
"""
main = '''FIXTUREVALUE
'''
route = "example.com/*
FIXTUREVALUE"
compatibility_date = "2024-01-01"
TOML
put span/serverless.yml <<'YAML'
service: kept
provider:
  runtime: "nodejs22.x
    FIXTUREVALUE"
  region: 'us-east-1
    FIXTUREVALUE'
  memorySize: 1024
    FIXTUREVALUE: continued
  timeout: 30
YAML
# shellcheck disable=SC2016  # the backticks quote a value in the env file
printf 'A="first\nFIXTUREVALUE=second\nlast"\nB=`one\nFIXTUREVALUE`\nC=kept\n' > "$a/span.env"
mkdir -p "$a/span-env" && mv "$a/span.env" "$a/span-env/.env"
put span/main.tf <<'HCL'
resource "aws_lambda_function" "f" {
  runtime = "nodejs22.x
FIXTUREVALUE = "x"
  handler = "kept"
}
HCL

# 5c. A bracket inside a TOML string.
put bracket/wrangler.toml <<'TOML'
compatibility_flags = ["a[", "b"]
other = "FIXTUREVALUE"
name = "x" # [ a note
another = "FIXTUREVALUE"
[vars]
A = "]"
B = "FIXTUREVALUE"
C = "[["
[[kv_namespaces]]
binding = "KV"
id = "FIXTUREVALUE"
TOML

# 5d. A value in a comment, in every format.
put comment/serverless.yml <<'YAML'
# token: FIXTUREVALUE
provider:
  runtime: nodejs22.x # FIXTUREVALUE
  #memorySize: FIXTUREVALUE
  timeout: 10 #FIXTUREVALUE
YAML
put comment/wrangler.toml <<'TOML'
# CARRIER_TOKEN = "FIXTUREVALUE"
name = "w" # FIXTUREVALUE
main = "src/index.ts"#FIXTUREVALUE
TOML
put comment/main.tf <<'HCL'
# password = "FIXTUREVALUE"
// token = "FIXTUREVALUE"
/* FIXTUREVALUE
   FIXTUREVALUE } */
resource "aws_lambda_function" "f" {
  runtime = "nodejs22.x" # FIXTUREVALUE
  timeout = 3 // FIXTUREVALUE
  memory_size = 128 /* FIXTUREVALUE */
}
HCL
put comment/.env <<'ENV'
# DB_PASS=FIXTUREVALUE
#SESSION=FIXTUREVALUE
NAME=value # FIXTUREVALUE
ENV
put comment/prod.tfvars <<'HCL'
# old = "FIXTUREVALUE"
region = "us-east-1" # FIXTUREVALUE
HCL

# 5e. Single-quoted and double-quoted values, after an assignment or a flag.
put quoted/serverless.yml <<'YAML'
provider:
  environment:
    A: 'FIXTUREVALUE'
    B: "FIXTUREVALUE"
    C: 'it''s FIXTUREVALUE'
    D: "say \"FIXTUREVALUE\""
  runtime: "X_SECRET=\"FIXTUREVALUE\" run"
  handler: 'API_TOKEN=FIXTUREVALUE'
YAML
put quoted/vercel.json <<'JSON'
{
  "buildCommand": "API_TOKEN='FIXTUREVALUE' next build",
  "installCommand": "npm ci --token \"FIXTUREVALUE\"",
  "framework": "say \"FIXTUREVALUE\""
}
JSON
put quoted/.env <<'ENV'
A='FIXTUREVALUE'
B="FIXTUREVALUE"
C="escaped \" FIXTUREVALUE"
export D=FIXTUREVALUE
ENV
put quoted/wrangler.toml <<'TOML'
[vars]
A = 'FIXTUREVALUE'
B = "FIXTUREVALUE"
C = "esc \" FIXTUREVALUE"
TOML
put quoted/.github/workflows/q.yml <<'YAML'
name: deploy --token 'FIXTUREVALUE'
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - name: "API_TOKEN=FIXTUREVALUE"
        run: tool --password "FIXTUREVALUE"
YAML

# 5f. A Terraform heredoc.
put heredoc/main.tf <<'HCL'
locals {
  note = <<EOT
FIXTUREVALUE
  runtime = "FIXTUREVALUE"
EOT
  other = <<-EOT
    FIXTUREVALUE
    EOT
}
resource "aws_lambda_function" "f" {
  runtime = <<EOF
FIXTUREVALUE
EOF
  timeout = 5
}
HCL

# 5g. A jsonencode block.
put jsonencode/main.tf <<'HCL'
resource "aws_iam_role_policy" "p" {
  policy = jsonencode({
    Version = "FIXTUREVALUE"
    Statement = [{
      Sid      = "FIXTUREVALUE"
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::bucket/*"
      Condition = {
        StringEquals = { "aws:SourceAccount" = "FIXTUREVALUE" }
      }
    }]
  })
  one_line = jsonencode({ token = "FIXTUREVALUE" })
}
resource "aws_lambda_function" "f" {
  environment {
    variables = {
      API_KEY = "FIXTUREVALUE"
      runtime = "FIXTUREVALUE"
    }
  }
  timeout = 5
}
HCL

# 5h. A YAML block scalar.
put block/serverless.yml <<'YAML'
provider:
  environment:
    KEY: |
      FIXTUREVALUE
      runtime: FIXTUREVALUE
    OTHER: >-
      FIXTUREVALUE
  runtime: |
    FIXTUREVALUE
  timeout: 10
YAML
put block/template.yaml <<'YAML'
AWSTemplateFormatVersion: "2010-09-09"
Transform: AWS::Serverless-2016-10-31
Parameters:
  Pass:
    Type: String
    Default: FIXTUREVALUE
Globals:
  Function:
    Environment:
      Variables:
        TOKEN: FIXTUREVALUE
Resources:
  Fn:
    Type: AWS::Serverless::Function
    Properties:
      Runtime: nodejs22.x
      MemorySize: 512
      InlineCode: !Sub |
        FIXTUREVALUE
      Policies:
        - Statement:
            - Effect: Allow
              Action: s3:GetObject
              Resource: !Sub "arn:aws:s3:::${Bucket}/*"
              Condition:
                StringEquals:
                  aws:SourceAccount: FIXTUREVALUE
      Events:
        Api:
          Type: Api
          Properties:
            Path: /FIXTUREVALUE
            Method: get
YAML

# 5i. A JSON file with comments.
put comments/wrangler.jsonc <<'JSON'
{
  // "vars": { "A": "FIXTUREVALUE" }
  /* FIXTUREVALUE */
  /* FIXTUREVALUE
     "name": "FIXTUREVALUE" } */
  "name": "w", // FIXTUREVALUE
  "vars": {
    // }
    "TOKEN": "FIXTUREVALUE"
  },
  "compatibility_date": "2024-01-01" /* FIXTUREVALUE */
}
JSON

# 5j. CRLF line endings.
mkdir -p "$a/crlf" "$a/crlf-env"
printf 'name = "w"\r\n[vars]\r\nCARRIER_TOKEN = "FIXTUREVALUE"\r\nNOTE = """\r\nFIXTUREVALUE\r\n"""\r\n' > "$a/crlf/wrangler.toml"
printf 'provider:\r\n  environment:\r\n    A: FIXTUREVALUE\r\n    B: |\r\n      FIXTUREVALUE\r\n  timeout: 10\r\n' > "$a/crlf/serverless.yml"
printf 'A=FIXTUREVALUE\r\nB="FIXTUREVALUE\r\nFIXTUREVALUE"\r\n' > "$a/crlf-env/.dev.vars"

# 5k. An address with a user and a password.
put userinfo/wrangler.toml <<'TOML'
routes = ["https://user:FIXTUREVALUE@example.com/*"]
route = "user:FIXTUREVALUE@example.com/*"
TOML
put userinfo/supabase/config.toml <<'TOML'
[auth]
site_url = "https://admin:FIXTUREVALUE@app.example.com"
additional_redirect_urls = ["https://a:FIXTUREVALUE@app.example.com/cb"]
[auth.external.github]
enabled = true
client_id = "FIXTUREVALUE"
secret = "FIXTUREVALUE"
TOML
put userinfo/vercel.json <<'JSON'
{ "$schema": "https://u:FIXTUREVALUE@openapi.vercel.sh/vercel.json" }
JSON
put userinfo/.env <<'ENV'
DATABASE_URL=postgres://app:FIXTUREVALUE@db.example.com:5432/x
ENV

# 5l. An address with a query string.
put query/supabase/config.toml <<'TOML'
[auth]
site_url = "https://app.example.com/?token=FIXTUREVALUE"
TOML
put query/vercel.json <<'JSON'
{ "crons": [{ "path": "/api/cron?key=FIXTUREVALUE", "schedule": "0 * * * *" }] }
JSON
put query/serverless.yml <<'YAML'
functions:
  f:
    events:
      - http:
          path: ingest?key=FIXTUREVALUE
          method: post
YAML

# 5m. A marker inside a shown key, such as a route.
put route/wrangler.toml <<'TOML'
route = "example.com/hooks/FIXTUREVALUE0a1b2c"
routes = ["api.example.com/FIXTUREVALUE/*", "api.example.com/k/FIXTUREVALUE"]
TOML
put route/vercel.json <<'JSON'
{
  "rewrites": [{ "source": "/hooks/FIXTUREVALUE", "destination": "/api/hooks" }],
  "headers": [{
    "source": "/(.*)",
    "headers": [
      { "key": "Authorization", "value": "Bearer FIXTUREVALUE" },
      { "key": "Access-Control-Allow-Origin", "value": "https://u:FIXTUREVALUE@x.example.com" },
      { "key": "Access-Control-Allow-Methods", "value": "GET,POST" }
    ]
  }]
}
JSON
put route/serverless.yml <<'YAML'
functions:
  f:
    events:
      - http:
          path: hooks/FIXTUREVALUE
          method: post
      - httpApi: 'POST /hooks/FIXTUREVALUE'
YAML

# 5n. More forms: a never-shown list, a flow map, an escaped key, one-line JSON,
# a CloudFormation template under another name, and a workflow.
put more/serverless.yml <<'YAML'
provider:
  apiGateway:
    apiKeys:
      - name: FIXTUREVALUE
        value: FIXTUREVALUE
    apiKeys2:
    - FIXTUREVALUE
  environment: {A: FIXTUREVALUE}
  tags: [FIXTUREVALUE, "FIXTUREVALUE"]
  runtime: &rt FIXTUREVALUE-anchor-01
YAML
# The key below is "regions" written with a JSON escape (backslash u0072).
printf '{"env":{"A":"FIXTUREVALUE"},"build":{"env":{"B":"FIXTUREVALUE"}},"\134u0072egions":["FIXTUREVALUE"],"crons":[{"path":"/ok","schedule":"0 0 * * *"}]}\n' | put more/vercel.json
put more/stack.json <<'JSON'
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Parameters": { "Pass": { "Type": "String", "Default": "FIXTUREVALUE" } },
  "Resources": {
    "Fn": {
      "Type": "AWS::Lambda::Function",
      "Properties": {
        "Runtime": "nodejs22.x",
        "Environment": { "Variables": { "TOKEN": "FIXTUREVALUE" } },
        "Code": { "ZipFile": "FIXTUREVALUE" }
      }
    }
  }
}
JSON
put more/.github/workflows/deploy.yaml <<'YAML'
name: deploy
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: FIXTUREVALUE
jobs:
  a:
    runs-on: ubuntu-latest
    environment: production
    env:
      TOKEN: FIXTUREVALUE
      REF: ${{ secrets.DEPLOY_TOKEN }}
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/deploy
          aws-region: eu-west-1
          password: FIXTUREVALUE
      - run: |
          echo FIXTUREVALUE
      - run: echo FIXTUREVALUE
YAML

# 5o. Values on the line after their key, a complex key, settings inside
# names-only and never-shown maps, dotted TOML keys, an HCL call that spans
# lines, nested quotes in an HCL template, and a flag inside a step name.
put next/serverless.yml <<'YAML'
provider:
  runtime:
    FIXTUREVALUE
  environment:
    nested:
      runtime: FIXTUREVALUE
  ? complex
  : FIXTUREVALUE
  db_password: !Sub
    - FIXTUREVALUE
  apiKeys: [FIXTUREVALUE]
  timeout: 5
YAML
put next/vercel.json <<'JSON'
{
  "env": { "x": { "runtime": "FIXTUREVALUE" } },
  "token":
    { "path": "/FIXTUREVALUE" },
  "regions" : ["iad1"], "memory": "FIXTUREVALUE",
  "maxDuration": 60
}
JSON
put next/wrangler.toml <<'TOML'
vars.A = "FIXTUREVALUE"
env.production.vars.B = "FIXTUREVALUE"
[[secret_things]]
binding = "FIXTUREVALUE"
[env.production]
routes = [ { pattern = "FIXTUREVALUE.example.com/*", zone_name = "x" } ]
compatibility_date = "2024-01-01"
TOML
put next/main.tf <<'HCL'
resource "aws_lambda_function" "f" {
  runtime = lookup(var.m,
    "FIXTUREVALUE")
  handler = "${var.a == "x" ? "FIXTUREVALUE" : "y"}"
  timeout = 10
}
variable "db_password" {
  default = "FIXTUREVALUE"
}
HCL
put next/.github/workflows/w.yml <<'YAML'
jobs:
  a:
    steps:
      - name: deploy -p FIXTUREVALUE
      - name: ok step
        with:
          role-to-assume: FIXTUREVALUE0123456789abcdef
YAML

# 5p. Review round 1.
# I1: a table header the reader does not recognise must not keep the table before it.
put header/wrangler.toml <<'TOML'
[[routes]]
pattern = "api.example.com/hooks/x"
[env.é.vars]
service = "FIXTUREVALUE"
[[routes]]
pattern = "api.example.com/x"
[env."eu/prod".vars]
service = "FIXTUREVALUE"
TOML
put header/supabase/config.toml <<'TOML'
[edge_runtime]
policy = "per_worker"
[remotes."feature/x".db]
policy = "FIXTUREVALUE"
TOML
# I2: a file with CR-only line endings.
mkdir -p "$a/cr/.github/workflows" "$a/cr-toml"
printf 'name: Deploy\renv:\r  TOKEN: FIXTUREVALUE\r' > "$a/cr/.github/workflows/cr.yml"
printf 'name = "w"\r[vars]\rTOKEN = "FIXTUREVALUE"\r' > "$a/cr-toml/wrangler.toml"
# I3: samconfig.toml shows its deploy settings.
put samconfig/samconfig.toml <<'TOML'
version = 0.1
[default.deploy.parameters]
stack_name = "quickship"
capabilities = "CAPABILITY_IAM"
region = "us-east-1"
parameter_overrides = "DbPassword=FIXTUREVALUE"
TOML
# I4: maps whose key names the user picks are names only.
put usermaps/main.tf <<'HCL'
locals {
  handler = "FIXTUREVALUE"
}
variable "x" {
  type    = string
  default = "FIXTUREVALUE"
}
module "m" {
  runtime = "FIXTUREVALUE"
}
resource "aws_lambda_function" "f" {
  timeout = 7
}
HCL
put usermaps/serverless.yml <<'YAML'
params:
  prod:
    handler: FIXTUREVALUE
custom:
  x:
    region: FIXTUREVALUE
provider:
  runtime: nodejs22.x
YAML
put usermaps/template.yaml <<'YAML'
AWSTemplateFormatVersion: "2010-09-09"
Mappings:
  M:
    prod:
      Handler: FIXTUREVALUE
Parameters:
  P:
    Type: FIXTUREVALUE
Resources:
  Fn:
    Properties:
      MemorySize: 256
YAML
put usermaps/.github/workflows/m.yml <<'YAML'
on:
  workflow_dispatch:
    inputs:
      env:
        type: FIXTUREVALUE
jobs:
  a:
    strategy:
      matrix:
        branches: [FIXTUREVALUE]
        runtime: FIXTUREVALUE
    runs-on: ubuntu-latest
YAML
put usermaps/supabase/config.toml <<'TOML'
[db.vault]
policy = "FIXTUREVALUE"
[edge_runtime.secrets]
policy = "FIXTUREVALUE"
[edge_runtime]
policy = "oneshot"
TOML
# I4: a key with a small closed set of values shows only a value from that set.
put closed/serverless.yml <<'YAML'
provider:
  architecture: FIXTUREVALUE
  region: FIXTUREVALUE
  iam:
    role:
      mode: FIXTUREVALUE
      statements:
        - Effect: FIXTUREVALUE
  apiGateway:
    usagePlan:
      quota:
        period: FIXTUREVALUE
  httpApi:
    authorizers:
      a:
        type: FIXTUREVALUE
functions:
  f:
    url:
      invokeMode: FIXTUREVALUE
    events:
      - http:
          method: FIXTUREVALUE
      - http:
          method: post
YAML
put closed/template.yaml <<'YAML'
Resources:
  Fn:
    Properties:
      AuthType: FIXTUREVALUE
      Tracing: FIXTUREVALUE
      PackageType: FIXTUREVALUE
      Architectures: [FIXTUREVALUE, arm64]
YAML
put closed/main.tf <<'HCL'
resource "aws_lambda_function_url" "u" {
  authorization_type = "FIXTUREVALUE"
  invoke_mode        = "FIXTUREVALUE"
}
resource "aws_lambda_function" "f" {
  logging_config {
    log_format = "FIXTUREVALUE"
  }
  tracing_config {
    mode = "FIXTUREVALUE"
  }
}
HCL
put closed/vercel.json <<'JSON'
{ "regions": ["FIXTUREVALUE", "iad1"], "schedules": { "n": { "requestMethod": "FIXTUREVALUE" } } }
JSON
put closed/.github/workflows/c.yml <<'YAML'
jobs:
  a:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: FIXTUREVALUE
YAML
# 5q. Shown keys with a fixed form show only that form (from the reviewer's files).
put fixedform/wrangler.toml <<'TOML'
[triggers]
crons = ["0 * * * *", "FIXTUREVALUE"]
[vars2]
service = "FIXTUREVALUE"
binding = "FIXTUREVALUE"
[[services]]
binding = "AUTH"
service = "auth-worker"
TOML
put fixedform/vercel.json <<'JSON'
{ "headers": [{ "source": "/(.*)", "headers": [
  { "key": "Access-Control-Allow-Origin", "value": "FIXTUREVALUE" },
  { "key": "Access-Control-Expose-Headers", "value": "X, FIXTUREVALUE one two" },
  { "key": "Access-Control-Allow-Origin", "value": "https://app.example.com" }
] }] }
JSON
put fixedform/main.tf <<'HCL'
resource "aws_lambda_function" "f" {
  layers = ["arn:aws:lambda:us-east-1:123456789012:layer:x:1", "FIXTUREVALUE"]
}
HCL
put fixedform/template.yaml <<'YAML'
Resources:
  P:
    Properties:
      PolicyDocument:
        Statement:
          - Principal:
              AWS: FIXTUREVALUE
              Service: FIXTUREVALUE
          - Principal:
              Service: lambda.amazonaws.com
YAML
put fixedform/serverless.yml <<'YAML'
functions:
  f:
    events:
      - sqs: FIXTUREVALUE
      - schedule: FIXTUREVALUE
      - schedule: rate(1 hour)
YAML
put fixedform/.github/workflows/f.yml <<'YAML'
jobs:
  a:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: FIXTUREVALUE
YAML
# 5r. Review round 2: a shown key prints only under a container that is its home.
put home/serverless.yml <<'YAML'
provider:
  runtime: nodejs22.x
  stackTags:
    runtime: FIXTUREVALUE
functions:
  f:
    handler: index.handler
    tags:
      handler: FIXTUREVALUE
resources:
  Mappings:
    M:
      us-east-1:
        handler: FIXTUREVALUE
  Parameters:
    P:
      runtime: FIXTUREVALUE
  Outputs:
    O:
      handler: FIXTUREVALUE
YAML
put home/main.tf <<'HCL'
resource "aws_cloudformation_stack" "s" {
  parameters = {
    runtime = "FIXTUREVALUE"
    handler = "FIXTUREVALUE"
    role    = "FIXTUREVALUE"
  }
}
resource "aws_lambda_function" "f" {
  runtime = "nodejs22.x"
  tags = {
    runtime = "FIXTUREVALUE"
  }
}
resource "aws_s3_bucket" "b" {
  runtime = "FIXTUREVALUE"
}
HCL
put home/template.yaml <<'YAML'
Conditions:
  C:
    Handler: FIXTUREVALUE
Metadata:
  X:
    Runtime: FIXTUREVALUE
Resources:
  Fn:
    Type: AWS::Serverless::Function
    Properties:
      Runtime: nodejs22.x
      Tags:
        Runtime: FIXTUREVALUE
YAML
put home/vercel.json <<'JSON'
{
  "images": { "runtime": "FIXTUREVALUE" },
  "functions": { "api/*.ts": { "runtime": "nodejs22.x" } }
}
JSON
put home/wrangler.toml <<'TOML'
name = "w"
[unsafe]
name = "FIXTUREVALUE"
[env.production]
name = "w-prod"
TOML
put home/.github/workflows/h.yml <<'YAML'
jobs:
  a:
    runs-on: ubuntu-latest
    services:
      db:
        runs-on: FIXTUREVALUE
YAML
put home/supabase/config.toml <<'TOML'
[studio]
schemas = ["FIXTUREVALUE"]
[api]
schemas = ["public"]
TOML
# A route or path segment longer than 15 characters is hidden.
put longseg/wrangler.toml <<'TOML'
routes = [ "api.example.com/hooks/FIXTUREVALUEsharedsecret" ]
route = "api.example.com/hooks/abcdefghijklmnopq"
TOML
put longseg/vercel.json <<'JSON'
{ "crons": [{ "path": "/api/FIXTUREVALUEsharedsecret", "schedule": "0 * * * *" }] }
JSON
# A schedule rate is a number and a unit, and a Worker route is a pattern with a slash.
put fixedform2/serverless.yml <<'YAML'
functions:
  f:
    events:
      - schedule: rate(FIXTUREVALUE)
      - schedule: rate(5 minutes)
YAML
put fixedform2/wrangler.json <<'JSON'
{ "route": "FIXTUREVALUE", "routes": ["api.example.com/*"] }
JSON

attack_count=0
for file in $(cd "$a" && find . -type f | sort); do
  attack_count=$((attack_count + 1))
  code=0
  out=$(sh "$reader" --show "$a/$file" 2>&1) || code=$?
  [ "$code" -eq 0 ] || fail "attack $file: exit $code, so the file was not read"
  no_marker "$out" "attack $file"
done
[ "$attack_count" -ge 75 ] || fail "attack: only $attack_count files were written"

# The attack files still show what the checks need.
expect_text "$(sh "$reader" --show "$a/span/vercel.json")" '"framework": "kept"' "attack span/vercel.json"
expect_text "$(sh "$reader" --show "$a/span/wrangler.toml")" 'compatibility_date = "2024-01-01"' "attack span/wrangler.toml"
expect_re "$(sh "$reader" --show "$a/span/serverless.yml")" 'timeout: 30$' "attack span/serverless.yml"
expect_text "$(sh "$reader" --show "$a/span-env/.env")" "C=<redacted>" "attack span .env"
expect_text "$(sh "$reader" --show "$a/bracket/wrangler.toml")" 'binding = "KV"' "attack bracket/wrangler.toml"
expect_text "$(sh "$reader" --show "$a/comment/wrangler.toml")" 'name = "w"' "attack comment/wrangler.toml"
expect_re "$(sh "$reader" --show "$a/comment/main.tf")" 'memory_size = 128' "attack comment/main.tf"
expect_re "$(sh "$reader" --show "$a/heredoc/main.tf")" 'timeout = 5$' "attack heredoc/main.tf"
expect_re "$(sh "$reader" --show "$a/jsonencode/main.tf")" 'Effect += "Allow"$' "attack jsonencode/main.tf"
expect_re "$(sh "$reader" --show "$a/jsonencode/main.tf")" 'timeout = 5$' "attack jsonencode/main.tf"
expect_text "$(sh "$reader" --show "$a/jsonencode/main.tf")" 'API_KEY = <redacted>' "attack jsonencode/main.tf"
expect_re "$(sh "$reader" --show "$a/block/serverless.yml")" 'timeout: 10$' "attack block/serverless.yml"
expect_re "$(sh "$reader" --show "$a/block/template.yaml")" 'MemorySize: 512$' "attack block/template.yaml"
expect_re "$(sh "$reader" --show "$a/block/template.yaml")" 'Effect: Allow$' "attack block/template.yaml"
expect_text "$(sh "$reader" --show "$a/block/template.yaml")" 'StringEquals:' "attack block/template.yaml"
expect_text "$(sh "$reader" --show "$a/comments/wrangler.jsonc")" '"compatibility_date": "2024-01-01"' "attack comments/wrangler.jsonc"
expect_text "$(sh "$reader" --show "$a/comments/wrangler.jsonc")" '"TOKEN"' "attack comments/wrangler.jsonc"
expect_text "$(sh "$reader" --show "$a/crlf/wrangler.toml")" 'CARRIER_TOKEN = <redacted>' "attack crlf/wrangler.toml"
expect_re "$(sh "$reader" --show "$a/crlf/serverless.yml")" 'timeout: 10$' "attack crlf/serverless.yml"
expect_text "$(sh "$reader" --show "$a/userinfo/supabase/config.toml")" 'enabled = true' "attack userinfo supabase"
expect_text "$(sh "$reader" --show "$a/query/vercel.json")" '"schedule": "0 * * * *"' "attack query/vercel.json"
expect_text "$(sh "$reader" --show "$a/query/serverless.yml")" 'method: post' "attack query/serverless.yml"
expect_text "$(sh "$reader" --show "$a/route/vercel.json")" '"source": "/(.*)"' "attack route/vercel.json"
expect_text "$(sh "$reader" --show "$a/route/vercel.json")" '"value": "GET,POST"' "attack route/vercel.json"
expect_text "$(sh "$reader" --show "$a/route/vercel.json")" '"key": "Authorization"' "attack route/vercel.json"
expect_text "$(sh "$reader" --show "$a/more/stack.json")" '"Runtime": "nodejs22.x"' "attack more/stack.json"
expect_text "$(sh "$reader" --show "$a/more/vercel.json")" '"schedule":"0 0 * * *"' "attack more/vercel.json"
more_wf=$(sh "$reader" --show "$a/more/.github/workflows/deploy.yaml")
expect_text "$more_wf" 'id-token: write' "attack more workflow"
expect_text "$more_wf" 'role-to-assume: arn:aws:iam::123456789012:role/deploy' "attack more workflow"
expect_text "$more_wf" 'environment: production' "attack more workflow"
# shellcheck disable=SC2016  # the expression is literal text in the workflow
expect_text "$more_wf" 'REF: ${{ secrets.DEPLOY_TOKEN }}' "attack more workflow"
expect_text "$more_wf" 'branches: [main]' "attack more workflow"
expect_re "$(sh "$reader" --show "$a/next/serverless.yml")" 'timeout: 5$' "attack next/serverless.yml"
# maxDuration is a setting under functions.<glob> only, so here it hides; regions is a top-level setting.
expect_text "$(sh "$reader" --show "$a/next/vercel.json")" '"regions" : ["iad1"]' "attack next/vercel.json"
expect_text "$(sh "$reader" --show "$a/next/wrangler.toml")" 'compatibility_date = "2024-01-01"' "attack next/wrangler.toml"
expect_re "$(sh "$reader" --show "$a/next/main.tf")" 'timeout = 10$' "attack next/main.tf"
expect_text "$(sh "$reader" --show "$a/next/.github/workflows/w.yml")" 'name: ok step' "attack next workflow"
expect_text "$(sh "$reader" --show "$a/header/supabase/config.toml")" 'policy = "per_worker"' "review I1 supabase"
expect_text "$(sh "$reader" --show "$a/samconfig/samconfig.toml")" 'stack_name = "quickship"' "review I3 samconfig"
expect_text "$(sh "$reader" --show "$a/samconfig/samconfig.toml")" 'capabilities = "CAPABILITY_IAM"' "review I3 samconfig"
expect_text "$(sh "$reader" --show "$a/samconfig/samconfig.toml")" 'region = "us-east-1"' "review I3 samconfig"
expect_text "$(sh "$reader" --show "$a/samconfig/samconfig.toml")" 'parameter_overrides = <redacted>' "review I3 samconfig"
expect_re "$(sh "$reader" --show "$a/usermaps/main.tf")" 'timeout = 7$' "review I4 main.tf"
expect_text "$(sh "$reader" --show "$a/usermaps/main.tf")" 'handler = <redacted>' "review I4 main.tf"
expect_re "$(sh "$reader" --show "$a/usermaps/serverless.yml")" 'runtime: nodejs22\.x$' "review I4 serverless.yml"
expect_re "$(sh "$reader" --show "$a/usermaps/template.yaml")" 'MemorySize: 256$' "review I4 template.yaml"
expect_text "$(sh "$reader" --show "$a/usermaps/.github/workflows/m.yml")" 'runs-on: ubuntu-latest' "review I4 workflow"
expect_text "$(sh "$reader" --show "$a/usermaps/supabase/config.toml")" 'policy = "oneshot"' "review I4 supabase"
expect_re "$(sh "$reader" --show "$a/closed/serverless.yml")" 'method: post$' "review I4 closed sets"
expect_text "$(sh "$reader" --show "$a/closed/template.yaml")" 'Architectures: [<redacted>, arm64]' "review I4 closed sets"
expect_text "$(sh "$reader" --show "$a/closed/vercel.json")" '"iad1"' "review I4 closed sets"
expect_text "$(sh "$reader" --show "$a/fixedform/wrangler.toml")" 'service = "auth-worker"' "fixed forms wrangler"
expect_text "$(sh "$reader" --show "$a/fixedform/wrangler.toml")" 'binding = "AUTH"' "fixed forms wrangler"
expect_text "$(sh "$reader" --show "$a/fixedform/vercel.json")" '"value": "https://app.example.com"' "fixed forms vercel"
expect_text "$(sh "$reader" --show "$a/fixedform/main.tf")" 'arn:aws:lambda:us-east-1:123456789012:layer:x:1' "fixed forms main.tf"
expect_text "$(sh "$reader" --show "$a/fixedform/template.yaml")" 'Service: lambda.amazonaws.com' "fixed forms template"
expect_text "$(sh "$reader" --show "$a/fixedform/serverless.yml")" 'schedule: rate(1 hour)' "fixed forms serverless"
expect_re "$(sh "$reader" --show "$a/home/serverless.yml")" 'runtime: nodejs22\.x$' "home serverless"
expect_re "$(sh "$reader" --show "$a/home/serverless.yml")" 'handler: index\.handler$' "home serverless"
expect_re "$(sh "$reader" --show "$a/home/main.tf")" 'runtime = "nodejs22\.x"$' "home main.tf"
expect_re "$(sh "$reader" --show "$a/home/template.yaml")" 'Runtime: nodejs22\.x$' "home template"
expect_text "$(sh "$reader" --show "$a/home/vercel.json")" '"runtime": "nodejs22.x"' "home vercel"
expect_text "$(sh "$reader" --show "$a/home/wrangler.toml")" 'name = "w-prod"' "home wrangler"
expect_text "$(sh "$reader" --show "$a/home/.github/workflows/h.yml")" 'runs-on: ubuntu-latest' "home workflow"
expect_text "$(sh "$reader" --show "$a/home/supabase/config.toml")" 'schemas = ["public"]' "home supabase"
expect_text "$(sh "$reader" --show "$a/fixedform2/serverless.yml")" 'schedule: rate(5 minutes)' "fixed forms rate"
expect_text "$(sh "$reader" --show "$a/fixedform2/wrangler.json")" '"api.example.com/*"' "fixed forms route"
sh "$reader" --show "$a/longseg/wrangler.toml" | grep -q abcdefghijklmnopq && fail "long segment: a route segment over 15 characters is shown"

# The other CloudFormation template is listed with the platform files.
git -C "$a" init -q -b main
attack_list=$(sh "$reader" "$a")
expect_line "$attack_list" "more/stack.json:aws-lambda:infrastructure:untracked" "list a template under another name"
expect_line "$attack_list" "block/template.yaml:aws-lambda:infrastructure:untracked" "list template.yaml"
expect_line "$attack_list" "comment/prod.tfvars:shared:env:untracked" "list *.tfvars"
expect_line "$attack_list" "crlf-env/.dev.vars:cloudflare-workers:env:untracked" "list .dev.vars"
printf '%s\n' "$attack_list" | grep -q 'more/.github/workflows' && fail "list: a workflow outside the top .github folder is listed"
no_marker "$attack_list" "attack list"

# 6. A source file and an unknown file type are refused with exit 4 and no output.
printf 'export const token = "FIXTUREVALUE";\n' > "$work/route.ts"
printf 'token=FIXTUREVALUE\n' > "$work/settings.ini"
for file in "$work/route.ts" "$work/settings.ini" "$repo/app/api/track/route.ts"; do
  code=0
  out=$(sh "$reader" --show "$file" 2>/dev/null) || code=$?
  [ "$code" -eq 4 ] || fail "show: $file did not exit 4 (exit $code)"
  [ -z "$out" ] || fail "show: $file printed to standard output"
done

# 7. No platform file, and no Git.
mkdir "$work/empty"
printf 'export {}\n' > "$work/empty/index.ts"
code=0
none=$(sh "$reader" "$work/empty") || code=$?
[ "$code" -eq 0 ] || fail "list: a folder with no platform file did not exit 0"
[ -z "$none" ] || fail "list: a folder with no platform file printed something"

cp -R "$repo" "$work/nogit"
rm -rf "$work/nogit/.git"
nogit=$(sh "$reader" "$work/nogit")
expect_line "$nogit" "worker/wrangler.toml:cloudflare-workers:functions:no-git" "list no-git"
expect_line "$nogit" ".dev.vars:cloudflare-workers:env:no-git" "list no-git"
printf '%s\n' "$nogit" | grep -vq ':no-git$' && fail "list no-git: a state other than no-git"

# 8. Usage errors.
code=0
sh "$reader" --show >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] || fail "usage: --show without a file did not exit 2"
code=0
sh "$reader" --nope >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] || fail "usage: an unknown option did not exit 2"

# 9. The reader writes nothing.
[ -z "$(git -C "$repo" status --porcelain)" ] || fail "the reader changed the repository"

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "read-serverless-config: all checks passed"
