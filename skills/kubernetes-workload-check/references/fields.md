# Fields

Every field the reader extracts, the shape its value has to fit, and where it sits in each object. Also the three command sections (render, refuse, cluster) and the Kubernetes facts behind them. This file is the single source of facts for the reader script, the cluster script, and the evidence rules in `checks.md`.

**Checked on 15 November 2026.** Each fact below is marked "checked" (read in the project's own documentation, in its own source file where the row says so, or in the output of a local tool whose version the row names, on that date; sources at the end) or "verify" (not read on that date: read the current documentation before relying on it). A status cell holds one word. A row with two facts of different status is split in two. The pages read named Kubernetes v1.37 as the current version, except the ContainerStatus page, which is the v1.35 reference. Field names and limits move between versions, so this file is re-checked at every release of the skill.

The skill never states a size, a saving, or a cost in the first pass. The defaults and limits below say what Kubernetes does when a setting is absent. They are not recommendations.

## Contents

1. [How the reader uses this file](#how-the-reader-uses-this-file)
2. [Shapes](#shapes)
3. [Object kinds the reader reads](#object-kinds-the-reader-reads)
4. [Fields of every object](#fields-of-every-object)
5. [Fields of a pod template](#fields-of-a-pod-template)
6. [Fields of each workload kind](#fields-of-each-workload-kind)
7. [Fields of autoscalers, limits, and quotas](#fields-of-autoscalers-limits-and-quotas)
8. [Fields of namespaces, accounts, and RBAC](#fields-of-namespaces-accounts-and-rbac)
9. [Fields of network policies](#fields-of-network-policies)
10. [Fields of Secrets and ConfigMaps](#fields-of-secrets-and-configmaps)
11. [Fields of Argo CD objects](#fields-of-argo-cd-objects)
12. [The values-file rule](#the-values-file-rule)
13. [Fields for each check](#fields-for-each-check)
14. [Command section 1: render commands](#command-section-1-render-commands)
15. [Command section 2: when the reader refuses to render](#command-section-2-when-the-reader-refuses-to-render)
16. [Command section 3: the cluster commands](#command-section-3-the-cluster-commands)
17. [Settings with no field](#settings-with-no-field)
18. [Not checked in version 1](#not-checked-in-version-1)
19. [Facts that conflict or moved](#facts-that-conflict-or-moved)
20. [Sources](#sources)

## How the reader uses this file

**Output lines.** One field per line:

```text
<file>:<line>:<object kind>/<namespace>/<name>:<container or ->:<field>=<value>
```

`<namespace>` is `metadata.namespace`, or `-` when the object has none or the value does not fit `dns-label`. An unrendered `{{ .Values.ns }}` therefore prints `-`, never the raw text. `<name>` is `metadata.name`, or `-` when it is missing or does not fit `dns-subdomain`. `<container>` is the container name when it fits `dns-label`, or `-` for a field of the pod, the object, or a rule and for a name that does not fit. `<line>` is the line of the key in the file. The reader writes `<container>` only for fields in the "Fields of a pod template" tables.

`<line>` of a rendered chart or overlay is the line of the rendered output, and `<file>` is the chart or overlay directory as it was given.

The list mode prints one line for each item, `<path>:<kind>:<state>`. The kinds are `manifest` (a file with top-level `apiVersion` and `kind` lines), `argo-application` (the same, with the kind `Application` or `ApplicationSet` and an `argoproj.io/` apiVersion), `chart` (a directory with `Chart.yaml` that is not inside another chart), `chart-values` (a `values*.yaml` file at the top of a chart, or one outside every chart with no `kind` line), `overlay`, and `kustomize-base` (a kustomization directory that another kustomization names in `resources`, `bases`, or `components`). The state is the file's Git state: `tracked`, `untracked`, `ignored`, or `no-git`. A file under a chart's `templates`, `crds`, or `charts` directory is not listed, and a chart there is a subchart and is not listed either. Every other file of a chart directory is listed by its own kind, so a `Chart.yaml` at the top of a repository hides nothing. A symbolic link is not listed, and a list root with a symbolic link in any part of its path (`linkdir/`, `link/deep`) is refused with exit code 4. A path that starts with `-` prints with `./` in front, so that it is never read as an option. A path with any character other than letters, digits, and `. _ / @ + -` (a space, a tab, a line break, a colon, a backslash, a quote, or a glob character) is not listed: the reader prints every other line, says on standard error how many paths it left out, and exits with code 4. `find` itself sorts the safe paths from the others, before any output is split into lines, so a line break in a name can neither repeat nor hide a path.

**Nothing prints by default.** A field prints only when its name is in a table below and its value passes the field's shape. A field whose key is absent prints no line. That is "not found", and it can neither pass nor fail a check. A field whose key is present and whose value the reader cannot read, or whose value fails its shape, prints `other` (see "On a miss"), so that a key the reader saw never looks the same as an absent key.

**Testing a value.** The reader cleans the text after the colon, then tests it, in this order:

1. Drop trailing spaces, trailing tabs, and a carriage return.
2. If the text starts with a single or double quote, it must end with the same quote. Remove that one pair, and remember that the text was quoted. Anything else after the closing quote means "not found". A quote that does not close on its line means the file is not read (exit code 4).
3. For unquoted text, drop everything from the first space or tab followed by `#`.
4. Unquoted text that is empty, or starts with one of `{`, `[` (except in a list field), `|`, `>`, `&`, `*`, `!`, `$`, or `%`, is not a scalar value. The leading-character test is for unquoted text only. Quoted text is a plain string, so `"*"` is the text `*`, and it goes on to steps 5 and 6. A quoted empty string (`""` or `''`) is the empty text, and for `rule.<n>.api-group` it is read as `core` before the empty-text test. For every other field, quoted empty text prints `other`. The one exception is a `$` at the start of a `rel-path` value, which is the `$ref/path` form of Argo CD (G2). An unquoted block scalar and Helm template (`{{`) end here, and print `other`. An anchor (`&`), an alias (`*`), and a tag (`!`) mean that the file is not read (exit code 4), because a field could then come from another place in the file. The text after `|` or `>` is never read, with one exception: the lines of a `helm.values` block scalar are read as a nested values file (see "The values-file rule"). Every other block scalar is never read.
5. The length must be at most the "Max" in the shape table. The reader tests this with `length()`, because the patterns hold no `{m,n}` interval, so no copy of awk has to support one.
6. The value must match the pattern. The reader uses the pattern as written in the shape block, in an awk `~` test.

**Layouts the reader does not read.** The reader works by line and does not parse. When it cannot place a line with certainty, it prints nothing for the whole file and exits with code 4: an anchor, an alias, a merge key (`<<`), a tag, a quoted value or a flow collection that goes on to the next line, a tab in the indent, a carriage return that does not end a line, a control character, a key at an indent no sibling uses, a key twice in one map, a key with characters outside letters, digits, and `_ $ . / + -`, a line that starts with `{{` (an unrendered template line), a directive (`%YAML`), a file that starts with `{` or `[` (JSON), a continuation line of a plain scalar, a flow map that is not empty (`securityContext: {privileged: true}`, `data: {KEY: value}`), a flow list with any item outside the allow shape below (which covers, among others, a map, a list, an implicit single-pair map such as `[hostPort: 22]` or `[?"hostPort":22]`, a key with no value such as `[key:]`, a `?` or `:` at the start, an alias, an anchor, a tag, an unrendered template, and an empty item), and the bytes of the Unicode line breaks NEL (U+0085), LS (U+2028), and PS (U+2029), which a YAML 1.1 reader takes as line breaks, so that a line the reader takes for a comment can hold a key for Kubernetes. The empty `{}` and `[]` are read, so `emptyDir: {}` names the volume type, and a one-line flow list of plain scalars (`drop: [ALL]`) is read item by item. In `--render kustomize`, a kustomization the reader does not read, in the overlay or in any base it reaches, stops the render before the tool runs, with the state `not read` and exit code 4. A key followed by a tab and a `#` comment is read like one followed by a space. The same rules hold for the lines of a `helm.values` block, where a layout the reader does not read drops the values lines of that block and prints `source.<n>.helm-values=other`.

A one-line flow list (`[ALL, NET_ADMIN]` or `["*"]`) is read item by item. **The allow shape.** The reader accepts a flow-list item only when it is one of two forms, with nothing but spaces around it: an unquoted token made of letters, digits, and `_ . / @ + = -` whose first character is a letter, a digit, `.`, or `/`, or a `-` with at least one more character after it (`ALL`, `80`, `../base`, `CreateNamespace=true`, `missingkey=error`, `-c`, `--token=abc`), or one single-quoted or double-quoted string with no quote, backslash, or control character inside (`"*"`, `"-c"`, `"echo a b"`). A `=` does not start a token, a `-` alone is not one, and a backslash is in neither form of token. No accepted item hides a map or a list, and Kubernetes reads the same number of items as the reader. Kubernetes may still type an unquoted word as null, a boolean, or a number (`NULL`, `Y`, `1e3`, `0x10`, `-1`) where the reader takes the word as text. Any other item makes the file unread (exit code 4), and in `--render kustomize` stops the render before the tool runs. Under the kustomization keys that carry a path, an accepted item is still tested as a path, so `resources: [-x=github.com/org/repo]` is refused as `remote base` before the tool runs. This is an allow list on purpose, so a form that no review has found yet is refused too. A plain scalar with a space is outside it and must be quoted. The statement about maps, lists, and the number of items was checked by generation (checked, T2, kubectl v1.37.2, 15 Nov 2026, `unshare -n kubectl annotate --local -f FILE zz=1 -o json`, which needs no cluster): every string of 1 to 4 characters over `a 1 - = . / : ? , " '` and the space, written as the items of a flow list and as a whole value, 22,620 strings each way. `tests/read-k8s-objects.gen.sh` repeats the check for 1 to 3 characters wherever kubectl is installed. Each accepted item is cleaned by steps 1 to 4 with its own quotes, and has to pass the shape on its own. A block list is read the same way. A list item that holds a map is not read.

**On a miss.** Every field prints the fixed word `other` when its key is present and its value fails the shape or is not a plain scalar (a template, a block, a YAML 1.1 form such as `yes`, `True`, or `0x0`, a quoted number or flag), so the report can say that a setting exists and was not read. Kubernetes may read such a value as set: `hostNetwork: yes` is `true` to the API server's YAML reader. The word `other` is written by the reader. It is never the value. A field that is a count, a state word, or `present` never misses.

**Credential-like names.** The reader removes `-`, `_`, and `.` from a key or variable name, makes it lower case, and tests it against this list: `pass`, `pwd`, `secret`, `token`, `apikey`, `accesskey`, `privatekey`, `signingkey`, `encryptionkey`, `credential`, `connectionstring`, `connstr`, `dsn`, `auth`, `salt`, `bearer`, `jwt`, `hmac`. A name that contains any of them is "credential-like". Six more terms were added on review: `license`, `cert`, `cookie`, and `session` match as a part of the name, and `pw` and `pat` match only as a whole word. A match is made like this: split the original name into words at `-`, `_`, `.`, and before a capital letter that follows a lower case letter or a digit, then make each word lower case. `pw` and `pat` match when a word is equal to them (`adminPw`, `github_pat`), so that `path` and `patch` do not match. Every other term matches when it is inside the name with the separators removed. A name written in one case with no separator (`ADMINPW`) is not split, so `pw` misses it. That is a stated limit. The list is the skill's own, and it is wider than needed on purpose. The value of a credential-like key never prints, even when it fits a shape. The evidence rule for K7 reads the same list.

**Counts and `present`.** A field with free text has no value row. It has a row whose printed value is a count (shape `int`), the word `present`, or a state word. The reader never prints the text itself. A count of things that are credential-like or outside a list (`annotation-credential-like-count`, `args-credential-like-count`, `env-other-count`, `pod-label-other-count`, `np-pod-label-other-count`, `quota-other-count`, `values-key-unreadable-count`) prints only when it is more than 0. Every other count prints whenever its key is present, 0 included.

**Refusals.** Every path argument of every mode (`[path]`, `--fields FILE`, `--values FILE`, the chart and values files of `--render helm`, and the directory of `--render kustomize`) is refused with a usage error (exit code 2) when it holds a control character, a tab and a line break included, before any other work. A control character here is a byte from 0 to 31 (the C0 set) or the byte 127 (DEL), which is what `[[:cntrl:]]` means under `LC_ALL=C`; the bytes from 128 to 159 (the C1 set) are not tested. The test runs on every argument, not only on paths, so the value of `--namespace` is covered too. A resolved path with a control character, for example a repository under a directory whose name holds a line break, is refused as well: `not a local file` in a render, and exit code 4 in the list. A line break at the end of a resolved path, or at the end of the top of the repository, is kept and refused the same way, so a directory whose name is `overlay` and a line break is never taken for the directory `overlay` beside it. A directory the overlay queue reaches that does not exist when it is taken from the queue is an error (`not a local file`), never an empty pass. A symbolic link is refused in every mode, and the reader reports the file as "not read", with exit code 4. A file the reader cannot place is reported the same way. The reader also tests for symbolic links inside a chart or an overlay tree before it renders (section 2).

**Objects with several documents.** A file with `---` separators is read one object at a time. A `List` kind is not followed, so the objects in its `items` are "not found". A YAML anchor or alias means the file is not read (see "Layouts the reader does not read").

## Shapes

Each shape is a POSIX extended regular expression and a maximum length. The reader tests the pattern with awk and the length with `length()`. The patterns use no interval expression, and they use explicit ranges in place of bracket classes, so that one copy runs in mawk, gawk, BusyBox awk, and BWK awk. The patterns below were run in all four of them on 15 November 2026, with the matching and non-matching examples in the next table.

A pattern is the skill's own, and it is tighter than the Kubernetes rule it implements. The "Status" column in the tables that follow says whether the Kubernetes fact behind a field was read. The "Basis" column here says which rule the pattern implements.

The shape block, one shape on each line: id, maximum length, pattern. The pattern is the rest of the line.

```text
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
env-source 17 ^(literal|secretKeyRef|configMapKeyRef|fieldRef|resourceFieldRef|fileKeyRef)$
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
```

What each shape holds, with two values that match and two that must not. A value that must not match is an example of text the shape refuses, such as a password with a capital letter or a symbol, a base64 string, a connection string, or a name with a user part. A shape does not refuse every secret: see the stated limits below the table.

| Shape | What it holds | Basis | Max | On a miss | Matches | Must not match | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bool` | A true or false flag | the Kubernetes boolean fields | 5 | other | `true`, `false` | `yes`, `"true; rm"` | K1 | 15 Nov 2026 | checked |
| `int` | A whole number: a count, a user number, or seconds | the Kubernetes integer fields | 10 | other | `0`, `1000` | `-1`, `12ab` | K1 | 15 Nov 2026 | checked |
| `port` | A port number, 1 to 65535 | a port is greater than 0 and less than 65536 | 5 | other | `80`, `65535` | `0`, `8080x` | K1 | 15 Nov 2026 | checked |
| `qty-cpu` | A CPU quantity: whole, decimal, or millicpu | 1 CPU unit, 0.1 or 100m, nothing finer than 1m | 12 | other | `250m`, `0.5` | `1Gi`, `p4ssw0rd` | K2 | 15 Nov 2026 | checked |
| `qty-mem` | A memory or storage quantity | a plain integer or fixed-point number with E, P, T, G, M, k, Ei, Pi, Ti, Gi, Mi, or Ki. A suffix m is allowed by the API and means millibytes | 16 | other | `512Mi`, `1.5G` | `Zm9vYmFy`, `hunter2` | K2 | 15 Nov 2026 | checked |
| `dns-label` | A DNS label: a namespace, a container name, or a volume name | at most 63 characters, lower case letters, digits, and -, starts with a letter, ends with a letter or digit | 63 | other | `fleetboard`, `api-2` | `Hunter2`, `-token` | K22 | 15 Nov 2026 | checked |
| `dns-subdomain` | A DNS subdomain: an object name | at most 253 characters, lower case letters, digits, -, and ., starts and ends with a letter or digit | 253 | other | `fleetboard-api`, `db.internal.example` | `Pass_word`, `user@host` | K22 | 15 Nov 2026 | checked |
| `short-name` | A short name from a generator list | the skill's own limit of 63 characters, on the DNS subdomain alphabet | 63 | other | `prod`, `eu-west-1` | `P4ss/word`, `a b` | not applicable | 15 Nov 2026 | checked |
| `api-version` | An apiVersion | a group, a slash, and a version such as v1, v1beta1, or v1alpha1, as in the pages' examples | 64 | other | `apps/v1`, `argoproj.io/v1alpha1` | `apps/latest`, `https://x/v1` | K4, K9, G1 | 15 Nov 2026 | checked |
| `kind-name` | A kind name | the skill's own limit: a capital letter then letters and digits, as in Deployment and HorizontalPodAutoscaler | 63 | other | `Deployment`, `HorizontalPodAutoscaler` | `deployment`, `Secret-Key` | K9, A1 | 15 Nov 2026 | checked |
| `env-name` | An environment variable name | the skill's own limit. The API allows any printable ASCII except = | 64 | other | `DATABASE_URL`, `LOG_LEVEL` | `9LIVES`, `A=B` | K1 | 15 Nov 2026 | checked |
| `key-name` | A Secret or ConfigMap key | letters, digits, -, _, and . only. The length limit of 64 is the skill's own | 64 | other | `password`, `.dockerconfigjson` | `a b`, `k=v` | K20, K21 | 15 Nov 2026 | checked |
| `label-value` | A label value, for a key on the label key list | at most 63 characters, starts and ends with a letter or digit, and holds -, _, and . between | 63 | other | `fleetboard-api`, `v1.2.3` | `-lead`, `has space` | K23 | 15 Nov 2026 | checked |
| `image-tag` | An image tag in a values file, tested and never printed | letters, digits, _, ., and -, not starting with . or -. The page allows 128 characters and the skill's own limit is 64 | 64 | other | `1.25-alpine`, `v2.0.1` | `-x`, `a:b` | K26 | 15 Nov 2026 | checked |
| `pull-policy` | An imagePullPolicy | one of Always, IfNotPresent, or Never | 12 | other | `Always`, `IfNotPresent` | `always`, `Sometimes` | K1 | 15 Nov 2026 | checked |
| `cap-name` | A Linux capability name | upper case words with underscores, as in NET_ADMIN and SYS_TIME in the page's example. The rule for the name is not stated | 32 | other | `ALL`, `NET_ADMIN` | `all`, `net admin` | K3 | 15 Nov 2026 | verify |
| `rbac-verb` | An RBAC verb | get, list, watch, create, update, patch, delete, deletecollection, escalate, bind, impersonate, or * | 16 | other | `get`, `*` | `GET`, `exec` | K16, K17 | 15 Nov 2026 | checked |
| `rbac-resource` | An RBAC resource word | a resource name with an optional /subresource, or *, as in pods and pods/log | 63 | other | `pods`, `pods/log` | `Pods`, `pods//log` | K16 | 15 Nov 2026 | checked |
| `rbac-group` | An RBAC API group | core for the empty string, *, or a DNS subdomain | 63 | other | `core`, `apps` | `Apps_x`, `a/b` | K16 | 15 Nov 2026 | checked |
| `role-name` | A Role or ClusterRole name | a DNS subdomain that also allows : in the middle. The page read does not state the name rule | 253 | other | `view`, `system:controller:x` | `Admin`, `a b` | K16 | 15 Nov 2026 | verify |
| `subject-kind` | A binding subject kind | User, Group, or ServiceAccount | 14 | other | `User`, `ServiceAccount` | `user`, `Robot` | K16 | 15 Nov 2026 | checked |
| `role-ref-kind` | A binding roleRef kind | Role or ClusterRole | 12 | other | `Role`, `ClusterRole` | `role`, `Binding` | K16 | 15 Nov 2026 | checked |
| `cidr-v4` | An IPv4 CIDR | four numbers from 0 to 255, a slash, and a prefix length from 0 to 32 | 18 | other | `10.0.0.0/8`, `172.17.0.0/16` | `256.1.1.1/8`, `10.0.0.0/33` | K18 | 15 Nov 2026 | checked |
| `cidr-v6` | An IPv6 CIDR | hexadecimal digits and at least one colon, a slash, and a prefix length from 0 to 128. The page shows no IPv6 example | 43 | other | `::/0`, `fd00::/8` | `deadbeef/8`, `::/129` | K18 | 15 Nov 2026 | verify |
| `psa-level` | A Pod Security level | privileged, baseline, or restricted | 10 | other | `restricted`, `baseline` | `Restricted`, `strict` | K19 | 15 Nov 2026 | checked |
| `psa-version` | A Pod Security version | latest or a minor version written v1.NN, as in the page's example | 8 | other | `latest`, `v1.37` | `1.37`, `v1` | K19 | 15 Nov 2026 | checked |
| `secret-type` | A built-in Secret type | the eight built-in types on the Secret page. A custom type prints other | 40 | other | `Opaque`, `kubernetes.io/tls` | `opaque`, `kubernetes.io/p4ss` | K20 | 15 Nov 2026 | checked |
| `update-mode` | A VerticalPodAutoscaler update mode | Off, Initial, Recreate, Auto, InPlaceOrRecreate, or InPlace | 17 | other | `Off`, `InPlaceOrRecreate` | `off`, `Manual` | K10, V1 | 15 Nov 2026 | checked |
| `concurrency-policy` | A CronJob concurrency policy | Allow, Forbid, or Replace | 7 | other | `Forbid`, `Allow` | `forbid`, `Skip` | K8 | 15 Nov 2026 | checked |
| `metric-type` | A HorizontalPodAutoscaler metric type | ContainerResource, External, Object, Pods, or Resource | 18 | other | `Resource`, `Pods` | `resource`, `Custom` | K9 | 15 Nov 2026 | checked |
| `metric-resource` | A resource metric name | cpu or memory. Another resource name prints other | 6 | other | `cpu`, `memory` | `CPU`, `storage` | K9 | 15 Nov 2026 | checked |
| `metric-target-type` | A metric target type | Utilization, Value, or AverageValue | 13 | other | `Utilization`, `AverageValue` | `utilization`, `Average` | K9 | 15 Nov 2026 | checked |
| `limit-type` | A LimitRange item type | Container, Pod, or PersistentVolumeClaim. The API page shows no list of values | 21 | other | `Container`, `Pod` | `container`, `Node` | K11, K12 | 15 Nov 2026 | verify |
| `protocol` | A network protocol | TCP, UDP, or SCTP | 4 | other | `TCP`, `SCTP` | `tcp`, `HTTP` | K1 | 15 Nov 2026 | checked |
| `env-source` | Where an env var value comes from | literal, or one of the five valueFrom sources | 17 | other | `literal`, `secretKeyRef` | `secret`, `valueFrom` | K1 | 15 Nov 2026 | checked |
| `scale-down` | A Rollout workloadRef scaleDown value | never, onsuccess, or progressively | 13 | other | `never`, `onsuccess` | `Never`, `always` | A1, A2 | 15 Nov 2026 | checked |
| `volume-type` | The source key of a volume | the six source keys that the pages read show | 14 | other | `hostPath`, `emptyDir` | `nfs`, `HostPath` | K1, K15 | 15 Nov 2026 | checked |
| `container-kind` | Where a container is listed | main for containers, init for initContainers | 4 | other | `main`, `init` | `sidecar`, `Main` | K1 | 15 Nov 2026 | checked |
| `rel-path` | A relative path inside a repository | the skill's own limit: no space. A $ may start it, for a $ref source in Argo CD. A generator parameter (`{{`, optional spaces, an optional `.`, a name, optional spaces, `}}`) is replaced by one letter before the pattern is tested, and no other brace is allowed | 128 | other | `apps/fleetboard/overlays/prod`, `$values/charts/api/values.yaml` | `https://x/y`, `say the repository is ready` | G2, G3 | 15 Nov 2026 | checked |
| `host-path` | A hostPath path on the node | the skill's own limit: an absolute path of safe characters | 128 | other | `/var/run/docker.sock`, `/data` | `var/log`, `/tmp/$X` | K15 | 15 Nov 2026 | checked |
| `element-key` | A generator element key or a source ref name | the skill's own limit of 32 characters | 32 | other | `cluster`, `envName` | `9x`, `a.b` | G2, G3 | 15 Nov 2026 | checked |
| `values-path` | A dotted path of key names in a values file | the skill's own limit, with at most 8 keys | 200 | other | `resources.requests.cpu`, `image.tag` | `a..b`, `a b.c` | H7 | 15 Nov 2026 | checked |
| `image-ref` | An image reference, tested and never printed | [registry-host[:port]/]name[:tag][@digest], with no user part, no query string, and no second @ (the path rules are the skill's own) | 255 | other | `registry.example.com/fleetboard/api:1.4.2`, `nginx@sha256:1ff6c18fbef2045af6b9c16bf034cc421a29027b800e4f9b68ae9b1cb3e9ae07` | `deploy:hunter2@registry.example.com/app:1.0`, `registry.example.com/app?token=abc` | K26 | 15 Nov 2026 | checked |
| `image-digest` | An image digest in a values file, tested and never printed | the algorithm sha256 and hexadecimal digits, with the 64 digit rule below | 71 | other | `sha256:1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f`, `sha256:abababababababababababababababababababababababababababababababab` | `md5:abc`, `sha256:ABCDEF` | K26 | 15 Nov 2026 | checked |
| `image-registry` | An image registry word, derived from an image | a host with an optional port, or the word default when the image names no host (the host-or-path rule is the skill's own) | 260 | other | `default`, `registry.example.com:5000` | `Registry.io`, `user@host` | K26 | 15 Nov 2026 | verify |
| `image-repository` | An image repository path, derived from an image | path segments of lower case letters and digits joined by ., _, or -, as in the page examples, with no registry, tag, or digest | 255 | other | `nginx`, `team/app-api` | `Team/App`, `a//b` | K26 | 15 Nov 2026 | checked |
| `medium` | An emptyDir medium | the page allows an empty string or Memory only. An empty string is never printed, so only the one value `Memory` can match, and the table lists one example | 6 | other | `Memory` (the only value) | `memory`, `Disk` | K1 | 15 Nov 2026 | checked |
| `policy-type` | A NetworkPolicy policy type | Ingress or Egress | 7 | other | `Ingress`, `Egress` | `ingress`, `Both` | K18 | 15 Nov 2026 | checked |

Stated limits of the shapes:

- A name shape does not stop a secret. A lower case password such as `hunter2`, a 32 digit hexadecimal string, or `changeme` fits `short-name` and `dns-label`. The examples that "must not match" are examples of other kinds of text. The control is that the reader prints a value only for a named key in a known place, and that a credential-like name never prints a value. The shapes alone are not the control.
- A value that a key cannot hold by its meaning, such as a token placed under `image.tag`, is not stopped by its shape. For that reason the reader never prints an image tag. It prints `image-pin` words instead.
- A repository path of an image fits `image-repository` whatever it spells, because the path rules allow the lower case letters and digits of a token. The reader prints it as written.

These rules live outside the patterns:

- `port` also needs a numeric value of 65535 or less. The documentation range is greater than 0 and less than 65536 (K1, checked).
- A `bool`, `int`, or `port` value must be unquoted, because a quoted one is a string that the API does not take for a number or a flag. `quota-hard.pods` is the exception, because a quota value is a quantity. An `int` or `port` value of more than one digit must not start with `0`, because a YAML 1.1 reader takes `010` as the octal number 8. Either case prints `other`.
- The 20-character rule. A name part that is 20 or more characters long and holds both a letter and a digit is taken for a token (tested with `length()` and two range matches). It prints as the word `other` in its place in a key segment of a values path (`values-path`), a segment of `image-repository`, the key of `secret-key.*`, `configmap-data.*`, `configmap-binary.*`, and `list-element.*`. An env var name that meets the rule prints no `env.<NAME>` line and is counted in `env-other-count`. Token shapes would otherwise pass as key names.
- `image-ref` and `image-digest` also need the text after `sha256:` to be exactly 64 characters. The page's example digest has 64 (K26, checked as an example). The rule that every sha256 digest has 64 hexadecimal digits is not stated on the page (verify).

Derived words, written by the reader and never copied from a file:

| Shape id | Words | Meaning |
| --- | --- | --- |
| `image-pin` | `digest`, `tag`, `latest`, `none` | `digest` when the image has `@sha256:`. `latest` for the tag `latest`. `none` when the image has neither a tag nor a digest, which Kubernetes treats as `latest` (K26). `tag` for any other tag. |
| `mount-mode` | `read-only`, `read-write` | `read-only` when `readOnly` is `true`. Otherwise `read-write` (`readOnly` defaults to false, K1). |
| `state-word` | `scalar`, `empty`, `block` | For a key whose value is never printed: `scalar` when it holds text on its own line, `empty` when it holds nothing or `""`, `null`, or `~`, `block` when the value continues on the next lines. |
| `selector-word` | `all`, `labels` | A selector that is `{}` is `all`. A selector with labels is `labels`. |
| `generator-word` | `list`, `other` | `list` for the key `list` (G3). Every other generator key is `other`. |
| `repo-word` | `this`, `other`, `unknown` | Whether a repository address names this repository. The reader compares the address with each `git remote` address after removing the scheme, a user part, a trailing `/`, and a trailing `.git`. With no remote, the answer is `unknown`. |

## Object kinds the reader reads

The reader reads these kinds and no others. A kind with no row is listed under "Not checked in version 1". The `kind` line of a file chooses the table. The `apiVersion` is printed as `api-version` and is not used to choose.

| Kind | apiVersion | Pod template at | Source | Read | Status |
| --- | --- | --- | --- | --- | --- |
| Pod | `v1` | `spec` | K27 | 15 Nov 2026 | checked |
| Deployment | `apps/v1` | `spec.template.spec` | K4 | 15 Nov 2026 | checked |
| StatefulSet | `apps/v1` | `spec.template.spec` | K5 | 15 Nov 2026 | checked |
| DaemonSet | `apps/v1` | `spec.template.spec` | K6 | 15 Nov 2026 | checked |
| Job | `batch/v1` | `spec.template.spec` | K7 | 15 Nov 2026 | checked |
| CronJob | `batch/v1` | `spec.jobTemplate.spec.template.spec` | K8 | 15 Nov 2026 | checked |
| Rollout (Argo Rollouts) | `argoproj.io/v1alpha1` | `spec.template.spec`, or none when `spec.workloadRef` is set | A1 | 15 Nov 2026 | checked |
| HorizontalPodAutoscaler | `autoscaling/v2` | not applicable | K9 | 15 Nov 2026 | checked |
| VerticalPodAutoscaler | `autoscaling.k8s.io/v1` | not applicable | K10, V1 | 15 Nov 2026 | checked |
| LimitRange | `v1` | not applicable | K11 | 15 Nov 2026 | checked |
| ResourceQuota | `v1` | not applicable | K13 | 15 Nov 2026 | checked |
| Namespace | `v1` | not applicable | K19, K24 | 15 Nov 2026 | verify |
| ServiceAccount | `v1` | not applicable | K27 | 15 Nov 2026 | checked |
| Role, ClusterRole | `rbac.authorization.k8s.io/v1` | not applicable | K16 | 15 Nov 2026 | checked |
| RoleBinding, ClusterRoleBinding | `rbac.authorization.k8s.io/v1` | not applicable | K16 | 15 Nov 2026 | checked |
| NetworkPolicy | `networking.k8s.io/v1` | not applicable | K18 | 15 Nov 2026 | checked |
| Secret | `v1` | not applicable | K20 | 15 Nov 2026 | verify |
| ConfigMap | `v1` | not applicable | K21 | 15 Nov 2026 | checked |
| Application (Argo CD) | `argoproj.io/v1alpha1` | not applicable | G1 | 15 Nov 2026 | checked |
| ApplicationSet (Argo CD) | `argoproj.io/v1alpha1` | `spec.template.spec` is an Application spec | G3 | 15 Nov 2026 | checked |

The Namespace and Secret rows are "verify" because the pages read name the kinds and show no `apiVersion` line for them. The Kubernetes pages read say a `Namespace` carries the labels (K19, K24).

In the tables below, `P` stands for the pod spec path in the third column above. `C` stands for one entry of `P.containers[]` or `P.initContainers[]`.

## Fields of every object

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `object` | every kind above | the object itself | the word `present` | not applicable | 15 Nov 2026 | checked |
| `api-version` | every kind above | `apiVersion` | `api-version` | K4, K7, K9, K16, K18, A1, G1 | 15 Nov 2026 | checked |
| `annotation-credential-like-count` | every kind above | `metadata.annotations`, and for a pod template kind also the template's `metadata.annotations` | `int`: how many annotation keys are credential-like and have a value | not applicable, a count of the reader | 15 Nov 2026 | checked |

`object=present` is the first line the reader prints for each object, so an object with no other readable field still shows up. Annotation values, label values with keys outside the list below, and every `command`, `args`, and env value have no row of their own.

## Fields of a pod template

These fields come from every kind in the "Pod template at" column: Pod, Deployment, StatefulSet, DaemonSet, Job, CronJob, and Rollout. A Rollout with `workloadRef` has no pod template, so it prints none of them. The pod template of the Deployment it points to is read from that Deployment.

An entry of `initContainers` is a container like any other. The reader prints `container-kind=init` for it, and every container field below applies. Container-level settings override pod-level settings of the same name (K1, K3), so the reader prints both levels under the same field name, one with `<container>` set to the container and one with `-`.

**Pod-level fields** (`<container>` is `-`):

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `host-network` | pod template kinds | `P.hostNetwork` | `bool` | K1 | 15 Nov 2026 | checked |
| `host-pid` | pod template kinds | `P.hostPID` | `bool` | K1 | 15 Nov 2026 | checked |
| `host-ipc` | pod template kinds | `P.hostIPC` | `bool` | K1 | 15 Nov 2026 | checked |
| `service-account` | pod template kinds | `P.serviceAccountName`, and its deprecated alias `P.serviceAccount` | `dns-subdomain` | K1 | 15 Nov 2026 | checked |
| `automount-sa-token` | pod template kinds | `P.automountServiceAccountToken` | `bool` | K1, K27 | 15 Nov 2026 | checked |
| `run-as-non-root` | pod template kinds | `P.securityContext.runAsNonRoot` | `bool` | K1, K3 | 15 Nov 2026 | checked |
| `run-as-user` | pod template kinds | `P.securityContext.runAsUser` | `int` | K1, K3 | 15 Nov 2026 | checked |
| `run-as-group` | pod template kinds | `P.securityContext.runAsGroup` | `int` | K1, K3 | 15 Nov 2026 | checked |
| `cpu-request`, `memory-request`, `cpu-limit`, `memory-limit` | pod template kinds | `P.resources.requests.cpu`, `P.resources.requests.memory`, `P.resources.limits.cpu`, `P.resources.limits.memory` | `qty-cpu` for the two cpu fields, `qty-mem` for the two memory fields | K1, K2 | 15 Nov 2026 | verify |
| `pod-active-deadline-seconds` | pod template kinds | `P.activeDeadlineSeconds` | `int` | K1 | 15 Nov 2026 | checked |
| `pod-label.<key>` | pod template kinds | the template's `metadata.labels` (a Pod's own `metadata.labels`), for the keys in the label key list below | `label-value` | K4, K23 | 15 Nov 2026 | checked |
| `pod-label-other-count` | pod template kinds | the same labels, for keys outside the list | `int` | K23 | 15 Nov 2026 | checked |
| `volume-name` | pod template kinds | `P.volumes[].name` | `dns-label` | K1 | 15 Nov 2026 | verify |
| `volume-type` | pod template kinds | the one source key of `P.volumes[]` | `volume-type` (on a miss: other) | K1, K15 | 15 Nov 2026 | checked |
| `host-path` | pod template kinds | `P.volumes[].hostPath.path` | `host-path` | K15 | 15 Nov 2026 | checked |
| `emptydir-medium` | pod template kinds | `P.volumes[].emptyDir.medium` | `medium` | K1, K15 | 15 Nov 2026 | checked |
| `emptydir-size-limit` | pod template kinds | `P.volumes[].emptyDir.sizeLimit` | `qty-mem` | K1, K15 | 15 Nov 2026 | checked |
| `secret-volume-name` | pod template kinds | `P.volumes[].secret.secretName` | `dns-subdomain` | K1 | 15 Nov 2026 | checked |
| `configmap-volume-name` | pod template kinds | `P.volumes[].configMap.name` | `dns-subdomain` | K1, K21 | 15 Nov 2026 | checked |

The pod-level `resources` row is "verify" because the two pages read disagree on whether the feature is alpha or beta. See "Facts that conflict or moved". A pod-level request does not stand in for a container's own request.

The label key list is the skill's own. The reader prints a label only when its key is one of `app`, `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `component`, `tier`, `role`, and `environment`. The `app.kubernetes.io/` keys are the recommended labels on K25. The names `component`, `tier`, `role`, and `environment` appear in the examples on K18 and K23. The key `app` is the skill's own choice (verify). Every other label key counts toward `pod-label-other-count`.

The volume field row for `volume-type` lists only the six source keys the pages read show. Any other source key prints `other`.

**Container-level fields** (`<container>` is the container's name):

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `container-kind` | pod template kinds | `P.containers[]` is `main`, `P.initContainers[]` is `init` | `container-kind` | K1 | 15 Nov 2026 | checked |
| `image-repository` | pod template kinds | derived from `C.image`: the text after the registry and before the tag or digest, as written. If `C.image` does not fit `image-ref`, the field prints `other` | `image-repository` (on a miss: other) | K1, K26 | 15 Nov 2026 | checked |
| `image-pin` | pod template kinds | derived from `C.image` | `image-pin` | K26 | 15 Nov 2026 | checked |
| `image-registry` | pod template kinds | derived from `C.image`: the host before the first `/` when it holds a `.` or a `:` or is `localhost`, or the word `default` when no host is written. The page says only that a missing registry means the Docker public registry, so the rule that tells a host from a path is not read | `image-registry` (on a miss: other) | K26 | 15 Nov 2026 | verify |
| `image-pull-policy` | pod template kinds | `C.imagePullPolicy` | `pull-policy` (on a miss: other) | K1, K26 | 15 Nov 2026 | checked |
| `cpu-request` | pod template kinds | `C.resources.requests.cpu` | `qty-cpu` | K2 | 15 Nov 2026 | checked |
| `memory-request` | pod template kinds | `C.resources.requests.memory` | `qty-mem` | K2 | 15 Nov 2026 | checked |
| `cpu-limit` | pod template kinds | `C.resources.limits.cpu` | `qty-cpu` | K2 | 15 Nov 2026 | checked |
| `memory-limit` | pod template kinds | `C.resources.limits.memory` | `qty-mem` | K2 | 15 Nov 2026 | checked |
| `ephemeral-storage-request` | pod template kinds | `C.resources.requests.ephemeral-storage` | `qty-mem` | K2 | 15 Nov 2026 | checked |
| `ephemeral-storage-limit` | pod template kinds | `C.resources.limits.ephemeral-storage` | `qty-mem` | K2 | 15 Nov 2026 | checked |
| `privileged` | pod template kinds | `C.securityContext.privileged` | `bool` | K1 | 15 Nov 2026 | checked |
| `allow-privilege-escalation` | pod template kinds | `C.securityContext.allowPrivilegeEscalation` | `bool` | K1, K3 | 15 Nov 2026 | checked |
| `read-only-root-fs` | pod template kinds | `C.securityContext.readOnlyRootFilesystem` | `bool` | K1 | 15 Nov 2026 | checked |
| `run-as-non-root` | pod template kinds | `C.securityContext.runAsNonRoot` | `bool` | K1, K3 | 15 Nov 2026 | checked |
| `run-as-user` | pod template kinds | `C.securityContext.runAsUser` | `int` | K1, K3 | 15 Nov 2026 | checked |
| `run-as-group` | pod template kinds | `C.securityContext.runAsGroup` | `int` | K1, K3 | 15 Nov 2026 | checked |
| `cap-drop` | pod template kinds | `C.securityContext.capabilities.drop[]`, one line for each item | `cap-name` | K1, K3 | 15 Nov 2026 | checked |
| `cap-add` | pod template kinds | `C.securityContext.capabilities.add[]`, one line for each item | `cap-name` | K1, K3 | 15 Nov 2026 | checked |
| `host-port` | pod template kinds | `C.ports[].hostPort` | `port` | K1 | 15 Nov 2026 | checked |
| `mount.<volume-name>` | pod template kinds | `C.volumeMounts[]`, from `name` and `readOnly` | `mount-mode` | K1 | 15 Nov 2026 | checked |
| `env.<NAME>` | pod template kinds | `C.env[]`: the source of the value | `env-source` (on a miss: other); the `<NAME>` part has to fit `env-name` | K1 | 15 Nov 2026 | checked |
| `env-ref.<NAME>` | pod template kinds | `C.env[].valueFrom.secretKeyRef.name` or `.configMapKeyRef.name` | `dns-subdomain` | K1 | 15 Nov 2026 | checked |
| `env-from-secret` | pod template kinds | `C.envFrom[].secretRef.name` | `dns-subdomain` | K1 | 15 Nov 2026 | checked |
| `env-from-configmap` | pod template kinds | `C.envFrom[].configMapRef.name` | `dns-subdomain` | K1 | 15 Nov 2026 | checked |
| `env-other-count` | pod template kinds | `C.env[]` entries whose name fails `env-name` or whose source the reader could not read | `int` | K1 | 15 Nov 2026 | checked |
| `args-credential-like-count` | pod template kinds | `C.command[]` and `C.args[]`: items whose flag or key part is credential-like, and items with a `://` followed by a user part and `@` | `int` | K1 | 15 Nov 2026 | checked |

Notes on the container rows:

- `env.<NAME>` is `literal` when the entry holds `value`, and the other words when it holds `valueFrom`. `valueFrom` and `value` cannot both be set (K1). The sources are `configMapKeyRef`, `fieldRef`, `fileKeyRef` (which needs the `EnvFiles` feature gate), `resourceFieldRef`, and `secretKeyRef` (K1). The value of an env var is never printed.
- A key in `envFrom` follows the rule that the last source wins, and an explicit `env` entry beats `envFrom` (K1). The reader prints each entry as written and does not merge.
- An env var name can be any printable ASCII text except `=` (K1). The `env-name` shape is tighter.
- If `allowPrivilegeEscalation` is not set, it defaults to true (K3). It is always true when the container is privileged or has `CAP_SYS_ADMIN` (K1). `readOnlyRootFilesystem` defaults to false, and `privileged` defaults to false (K1).
- `runAsUser` defaults to the user in the image metadata when it is unset (K1). The reader cannot see the image, so an unset `run-as-user` is "not found", and K1 is "ask the team" at best.
- `imagePullPolicy` defaults to `IfNotPresent` when the image has a digest or a tag other than `latest`, and to `Always` for `latest` or no tag (K26).
- `hostPort`, when `hostNetwork` is true, has to match `containerPort` (K1).

## Fields of each workload kind

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `replicas` | Deployment, StatefulSet, Rollout | `spec.replicas` (defaults to 1) | `int` | K4, K5, A1 | 15 Nov 2026 | checked |
| `workload-ref-kind` | Rollout | `spec.workloadRef.kind` | `kind-name` | A1, A2 | 15 Nov 2026 | checked |
| `workload-ref-name` | Rollout | `spec.workloadRef.name` | `dns-subdomain` | A1, A2 | 15 Nov 2026 | checked |
| `workload-ref-scale-down` | Rollout | `spec.workloadRef.scaleDown` | `scale-down` (on a miss: other) | A1, A2 | 15 Nov 2026 | checked |
| `active-deadline-seconds` | Job | `spec.activeDeadlineSeconds` | `int` | K7 | 15 Nov 2026 | checked |
| `backoff-limit` | Job | `spec.backoffLimit` (defaults to 6) | `int` | K7 | 15 Nov 2026 | checked |
| `ttl-seconds-after-finished` | Job | `spec.ttlSecondsAfterFinished` (unset means no automatic deletion) | `int` | K7 | 15 Nov 2026 | checked |
| `active-deadline-seconds` | CronJob | `spec.jobTemplate.spec.activeDeadlineSeconds` | `int` | K7, K8 | 15 Nov 2026 | checked |
| `backoff-limit` | CronJob | `spec.jobTemplate.spec.backoffLimit` | `int` | K7, K8 | 15 Nov 2026 | checked |
| `ttl-seconds-after-finished` | CronJob | `spec.jobTemplate.spec.ttlSecondsAfterFinished` | `int` | K7, K8 | 15 Nov 2026 | checked |
| `concurrency-policy` | CronJob | `spec.concurrencyPolicy` (defaults to `Allow`) | `concurrency-policy` (on a miss: other) | K8 | 15 Nov 2026 | checked |
| `starting-deadline-seconds` | CronJob | `spec.startingDeadlineSeconds` | `int` | K8 | 15 Nov 2026 | checked |
| `history-limit-successful` | CronJob | `spec.successfulJobsHistoryLimit` (defaults to 3) | `int` | K8 | 15 Nov 2026 | checked |
| `history-limit-failed` | CronJob | `spec.failedJobsHistoryLimit` (defaults to 1) | `int` | K8 | 15 Nov 2026 | checked |

Notes:

- A Rollout uses either `template` or `workloadRef`, never both (A1). With `workloadRef`, the page says a change is made to the pod template of the Deployment (A2), so the Deployment is the workload that holds the pod template, and the pair counts once. The Rollout's `scaleDown` values are `never`, `onsuccess`, and `progressively` (A1, A2).
- A Job's `restartPolicy` can only be `Never` or `OnFailure` (K7). The reader has no field for it.
- `schedule`, `timeZone`, `suspend`, `parallelism`, `completions`, and a Job's `podFailurePolicy` have no field.
- A Job's `activeDeadlineSeconds` counts from the start time, and the timer stops while the Job is suspended (K7). The value has to be a positive integer (K1, K7).

## Fields of autoscalers, limits, and quotas

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `scale-target-api-version` | HorizontalPodAutoscaler | `spec.scaleTargetRef.apiVersion` | `api-version` | K9, A3 | 15 Nov 2026 | checked |
| `scale-target-kind` | HorizontalPodAutoscaler | `spec.scaleTargetRef.kind` (`Rollout` is a valid target, A3) | `kind-name` | K9, A3 | 15 Nov 2026 | checked |
| `scale-target-name` | HorizontalPodAutoscaler | `spec.scaleTargetRef.name` | `dns-subdomain` | K9, A3 | 15 Nov 2026 | checked |
| `min-replicas` | HorizontalPodAutoscaler | `spec.minReplicas` (defaults to 1) | `int` | K9 | 15 Nov 2026 | checked |
| `max-replicas` | HorizontalPodAutoscaler | `spec.maxReplicas` (required) | `int` | K9 | 15 Nov 2026 | checked |
| `metric-type` | HorizontalPodAutoscaler | `spec.metrics[].type` | `metric-type` (on a miss: other) | K9 | 15 Nov 2026 | checked |
| `metric-resource` | HorizontalPodAutoscaler | `spec.metrics[].resource.name` | `metric-resource` (on a miss: other) | K9 | 15 Nov 2026 | checked |
| `metric-target-type` | HorizontalPodAutoscaler | `spec.metrics[].resource.target.type` | `metric-target-type` (on a miss: other) | K9 | 15 Nov 2026 | checked |
| `metric-average-utilization` | HorizontalPodAutoscaler | `spec.metrics[].resource.target.averageUtilization` | `int` | K9 | 15 Nov 2026 | checked |
| `scale-target-api-version` | VerticalPodAutoscaler | `spec.targetRef.apiVersion` | `api-version` | K10, V1 | 15 Nov 2026 | checked |
| `scale-target-kind` | VerticalPodAutoscaler | `spec.targetRef.kind` | `kind-name` | K10, V1 | 15 Nov 2026 | checked |
| `scale-target-name` | VerticalPodAutoscaler | `spec.targetRef.name` | `dns-subdomain` | K10, V1 | 15 Nov 2026 | checked |
| `update-mode` | VerticalPodAutoscaler | `spec.updatePolicy.updateMode` | `update-mode` (on a miss: other) | K10, V1 | 15 Nov 2026 | checked |
| `limit-type` | LimitRange | `spec.limits[].type` | `limit-type` (on a miss: other) | K11, K12 | 15 Nov 2026 | verify |
| `limit-default.cpu`, `limit-default.memory` | LimitRange | `spec.limits[].default.cpu`, `.memory` | `qty-cpu`, `qty-mem` | K11, K12 | 15 Nov 2026 | checked |
| `limit-default-request.cpu`, `limit-default-request.memory` | LimitRange | `spec.limits[].defaultRequest.cpu`, `.memory` | `qty-cpu`, `qty-mem` | K11, K12 | 15 Nov 2026 | checked |
| `limit-max.cpu`, `limit-max.memory` | LimitRange | `spec.limits[].max.cpu`, `.memory` | `qty-cpu`, `qty-mem` | K11, K12 | 15 Nov 2026 | checked |
| `limit-min.cpu`, `limit-min.memory` | LimitRange | `spec.limits[].min.cpu`, `.memory` | `qty-cpu`, `qty-mem` | K11, K12 | 15 Nov 2026 | checked |
| `limit-max-ratio.cpu`, `limit-max-ratio.memory` | LimitRange | `spec.limits[].maxLimitRequestRatio.cpu`, `.memory` (limit divided by request must not exceed it) | `qty-cpu` | K11 | 15 Nov 2026 | checked |
| `quota-hard.requests.cpu`, `quota-hard.limits.cpu`, `quota-hard.cpu` | ResourceQuota | `spec.hard` with the same key | `qty-cpu` | K13, K14 | 15 Nov 2026 | checked |
| `quota-hard.requests.memory`, `quota-hard.limits.memory`, `quota-hard.memory` | ResourceQuota | `spec.hard` with the same key | `qty-mem` | K13, K14 | 15 Nov 2026 | checked |
| `quota-hard.requests.ephemeral-storage`, `quota-hard.limits.ephemeral-storage`, `quota-hard.ephemeral-storage` | ResourceQuota | `spec.hard` with the same key | `qty-mem` | K14 | 15 Nov 2026 | checked |
| `quota-hard.pods` | ResourceQuota | `spec.hard.pods` | `int` | K14 | 15 Nov 2026 | checked |
| `quota-other-count` | ResourceQuota | the other keys of `spec.hard` | `int` | K13, K14 | 15 Nov 2026 | checked |

Notes:

- The reader prints quantities as written and does no arithmetic. The comparison of a memory limit with its request (R3) is the agent's, and it follows the rule in `checks.md`.
- A CPU value of `0.1` is the same as `100m`, and Kubernetes accepts nothing finer than `1m` (K2). In a memory value, `M` means megabytes and a lower case `m` means millibytes, so `400m` is 0.4 bytes (K2). The `qty-mem` shape lets `m` through so that the report can name the mistake.
- A LimitRange `default` or `defaultRequest` is filled in at admission for pods that set no value (K12). It is a different fact from a request in the pod template, and the evidence rule keeps them apart.
- With two or more LimitRange objects in a namespace, the page says it is not deterministic which default applies (K12).
- With a ResourceQuota on `cpu` or `memory`, every new pod must set a request or a limit for it, or the control plane may reject the pod (K14).
- A HorizontalPodAutoscaler `Utilization` target is a percentage of the requested value of the resource for the pods (K9). With no request, the target has nothing to measure against.
- A HorizontalPodAutoscaler on a Rollout works through the Rollout's `/scale` subresource (A3).
- A VerticalPodAutoscaler is a custom resource that must be installed in the cluster, and it needs a metrics source (K10).

## Fields of namespaces, accounts, and RBAC

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `psa-enforce` | Namespace | `metadata.labels` key `pod-security.kubernetes.io/enforce` | `psa-level` (on a miss: other) | K19 | 15 Nov 2026 | checked |
| `psa-enforce-version` | Namespace | `metadata.labels` key `pod-security.kubernetes.io/enforce-version` | `psa-version` | K19 | 15 Nov 2026 | checked |
| `psa-warn` | Namespace | `metadata.labels` key `pod-security.kubernetes.io/warn` | `psa-level` (on a miss: other) | K19 | 15 Nov 2026 | checked |
| `psa-warn-version` | Namespace | `metadata.labels` key `pod-security.kubernetes.io/warn-version` | `psa-version` | K19 | 15 Nov 2026 | checked |
| `automount-sa-token` | ServiceAccount | `automountServiceAccountToken` | `bool` | K27 | 15 Nov 2026 | checked |
| `rule.<n>.verb` | Role, ClusterRole | `rules[<n>].verbs[]`, one line for each item, `<n>` counted from 1 in file order | `rbac-verb` (on a miss: other) | K16, K17 | 15 Nov 2026 | checked |
| `rule.<n>.resource` | Role, ClusterRole | `rules[<n>].resources[]`, one line for each item | `rbac-resource` (on a miss: other) | K16 | 15 Nov 2026 | checked |
| `rule.<n>.api-group` | Role, ClusterRole | `rules[<n>].apiGroups[]`, one line for each item. An empty string is printed as `core` | `rbac-group` (on a miss: other) | K16 | 15 Nov 2026 | checked |
| `rule.<n>.resource-names-count` | Role, ClusterRole | `rules[<n>].resourceNames[]` | `int` | K16 | 15 Nov 2026 | checked |
| `rule.<n>.non-resource-urls-count` | Role, ClusterRole | `rules[<n>].nonResourceURLs[]` | `int` | K16 | 15 Nov 2026 | checked |
| `aggregation-rule` | ClusterRole | `aggregationRule` | the word `present` | K16 | 15 Nov 2026 | checked |
| `role-ref-kind` | RoleBinding, ClusterRoleBinding | `roleRef.kind` | `role-ref-kind` (on a miss: other) | K16 | 15 Nov 2026 | checked |
| `role-ref-name` | RoleBinding, ClusterRoleBinding | `roleRef.name` | `role-name` | K16 | 15 Nov 2026 | verify |
| `subject.<n>.kind` | RoleBinding, ClusterRoleBinding | `subjects[<n>].kind` | `subject-kind` (on a miss: other) | K16 | 15 Nov 2026 | checked |
| `subject.<n>.name` | RoleBinding, ClusterRoleBinding | `subjects[<n>].name`, printed only when the kind is `ServiceAccount` | `dns-subdomain` | K16 | 15 Nov 2026 | checked |
| `subject.<n>.namespace` | RoleBinding, ClusterRoleBinding | `subjects[<n>].namespace`, used for `ServiceAccount` subjects | `dns-label` | K16 | 15 Nov 2026 | checked |

Notes:

- The Pod Security level in a namespace label is one of `privileged`, `baseline`, and `restricted`, and the version is a minor version or `latest` (K19). Only the `enforce` mode rejects a pod. The other two modes only warn or write to the audit log, so they do not decide K10 (K19). The reader reads the `warn` pair for the "Also found" list and does not read the third mode label.
- The reader does not print the name of a `User` or a `Group` subject. A user name can be an email address.
- A rule item of `"*"` is a wildcard that stands for all verbs, resources, or API groups (K16). The documentation warns that a wildcard also covers kinds created later (K17).
- The verbs `escalate`, `bind`, and `impersonate` let a holder reach rights it was not given (K17). The verbs `get`, `list`, and `watch` on Secrets all reveal Secret contents (K17). The `create` verb on a workload implicitly grants the access of every ServiceAccount in the namespace (K17).
- A role rule may use other verbs, such as the ones custom resources define. The reader prints `other` for them. The verb `use` is not on the pages read (verify).
- When both the ServiceAccount and the pod set `automountServiceAccountToken`, the pod spec wins (K27). What the default is when neither sets it is not stated on the page, which implies "on" (verify).
- A pod with no `serviceAccountName` gets the `default` ServiceAccount of its namespace (K27).
- A binding's `roleRef` cannot change after creation (K16). The reader does not use this.

## Fields of network policies

A `NetworkPolicy` has `podSelector`, `policyTypes`, `ingress[]`, and `egress[]` (K18). The reader numbers rules from 1 within each direction (`<r>`) and peers from 1 within each rule (`<p>`).

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `np-pod-selector` | NetworkPolicy | `spec.podSelector`: `{}` selects every pod in the namespace | `selector-word` | K18 | 15 Nov 2026 | checked |
| `np-pod-label.<key>` | NetworkPolicy | `spec.podSelector.matchLabels`, for keys in the label key list | `label-value` | K18, K23 | 15 Nov 2026 | checked |
| `np-pod-label-other-count` | NetworkPolicy | `spec.podSelector.matchLabels` and `matchExpressions`, for keys outside the list | `int` | K23 | 15 Nov 2026 | checked |
| `np-policy-type` | NetworkPolicy | `spec.policyTypes[]`, one line for each item. With none set, `Ingress` is always set, and `Egress` is set when the policy has egress rules (K18) | `policy-type` (on a miss: other) | K18 | 15 Nov 2026 | checked |
| `np-ingress-rules`, `np-egress-rules` | NetworkPolicy | the number of items in `spec.ingress[]`, `spec.egress[]` | `int` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peers`, `np-egress.<r>.peers` | NetworkPolicy | the number of items in `from[]`, `to[]` of rule `<r>` | `int` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.pod-selector`, `np-egress.<r>.peer.<p>.pod-selector` | NetworkPolicy | `podSelector` of the peer | `selector-word` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.namespace-selector`, `np-egress.<r>.peer.<p>.namespace-selector` | NetworkPolicy | `namespaceSelector` of the peer. Both selectors in one peer are an AND. Separate peers are an OR (K18) | `selector-word` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.pod-label.<key>`, `np-egress.<r>.peer.<p>.pod-label.<key>` | NetworkPolicy | `podSelector.matchLabels` of the peer, for keys in the list | `label-value` | K18, K23 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.namespace-label.<key>`, `np-egress.<r>.peer.<p>.namespace-label.<key>` | NetworkPolicy | `namespaceSelector.matchLabels` of the peer, for keys in the list, and for the key `kubernetes.io/metadata.name`, which the API server sets on every namespace to the namespace's name (K24) | `label-value` | K18, K24 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.ip-block`, `np-egress.<r>.peer.<p>.ip-block` | NetworkPolicy | `ipBlock.cidr` of the peer | `cidr-v4` or `cidr-v6` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.peer.<p>.ip-block-except-count`, `np-egress.<r>.peer.<p>.ip-block-except-count` | NetworkPolicy | `ipBlock.except[]` | `int` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.port`, `np-egress.<r>.port` | NetworkPolicy | `ports[].port` of rule `<r>` | `port` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.end-port`, `np-egress.<r>.end-port` | NetworkPolicy | `ports[].endPort` (must be at least `port`, and only with a numeric `port`) | `port` | K18 | 15 Nov 2026 | checked |
| `np-ingress.<r>.protocol`, `np-egress.<r>.protocol` | NetworkPolicy | `ports[].protocol` | `protocol` (on a miss: other) | K1, K18 | 15 Nov 2026 | checked |

Notes:

- With no policy in a namespace, all ingress and egress is allowed to and from pods in it. A pod is isolated for a direction only when a policy selects it and lists that direction in `policyTypes`. Policies are additive (K18).
- A policy has no effect when the cluster's network plugin does not enforce it (K18). The file cannot show which plugin runs. That is a "Not checked" item.
- A default deny-all egress policy also blocks DNS (K18).
- A rule with no `from` or `to` entry: how Kubernetes reads it is not on the page text read (verify). The reader prints `peers=0` for it.
- A port given by name, a string port, is not read, because `port` needs a numeric value.
- The page says the `ipBlock` addresses should be cluster-external IPs (K18). The IPv6 form is not shown on the page (verify), and the `cidr-v6` shape carries that status.

## Fields of Secrets and ConfigMaps

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `secret-type` | Secret | `type` (an empty string means `Opaque`, and no `type` line also means `Opaque`). The reader prints `Opaque` for `""` and no line when there is no `type` line | `secret-type` (on a miss: other) | K20 | 15 Nov 2026 | checked |
| `secret-key.data` | Secret | the keys of `data`, one line for each, value is the key name | `key-name` | K20 | 15 Nov 2026 | checked |
| `secret-key.string-data` | Secret | the keys of `stringData`, one line for each, value is the key name | `key-name` | K20 | 15 Nov 2026 | checked |
| `secret-immutable` | Secret | `immutable` | `bool` | K20 | 15 Nov 2026 | checked |
| `configmap-data.<key>` | ConfigMap | the keys of `data`: a state, never the value | `state-word`, and `<key>` has to fit `key-name` | K21 | 15 Nov 2026 | checked |
| `configmap-binary.<key>` | ConfigMap | the keys of `binaryData`: the word `present` | `<key>` has to fit `key-name` | K21 | 15 Nov 2026 | checked |
| `configmap-immutable` | ConfigMap | `immutable` | `bool` | K21 | 15 Nov 2026 | checked |

Notes:

- A Secret prints its name, its type, and its key names, and never a value. The `data` values are base64 and the `stringData` values are plain text. The page says base64 hides a value from a glance and gives no useful level of confidentiality (K20). `stringData` values are merged into `data`, and `stringData` wins on a duplicate key (K20).
- The keys of a Secret or a ConfigMap are letters, digits, `-`, `_`, and `.` (K20, K21). The ConfigMap page says a ConfigMap gives no secrecy or encryption (K21).
- The reader sets `<container>` to `-` for every line in this section.
- A Secret manifest in the repository is the evidence for K7. The reader needs no value to see it.
- Sealed or external secret kinds (for example, objects of an operator that fetches secrets) are other custom kinds. They are not read (see "Not checked in version 1"). Whether the kinds that exist in a given cluster hold only references is not read (verify).
- Secret names and ConfigMap names are DNS subdomain names on the page for ConfigMap (K21). The Secret page read does not state the name rule (verify), and `dns-subdomain` is used for both.

## Fields of Argo CD objects

An `Application` has `spec.source` (one source) or `spec.sources` (a list). When `sources` is set, Argo CD ignores `source` (G2). The reader numbers sources from 1 in file order and prints both forms as `source.<n>`. For an `ApplicationSet`, the same fields come from `spec.template.spec`, and the generator list comes from `spec.generators[]`.

| Field | Kinds | Path | Shape | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `app-project` | Application, ApplicationSet | `spec.project` | `dns-subdomain` | G1 | 15 Nov 2026 | checked |
| `destination-namespace` | Application, ApplicationSet | `spec.destination.namespace` | `dns-label` | G1, G3 | 15 Nov 2026 | checked |
| `source.<n>.repo` | Application, ApplicationSet | `repoURL`, compared and never printed | `repo-word` | G1 | 15 Nov 2026 | checked |
| `source.<n>.url-has-user-part` | Application, ApplicationSet | `repoURL` holds a user or a password before `@` | `bool` | G1 | 15 Nov 2026 | checked |
| `source.<n>.path` | Application, ApplicationSet | `path` | `rel-path` | G1, G3 | 15 Nov 2026 | checked |
| `source.<n>.chart` | Application, ApplicationSet | `chart` (a chart name) | the word `present` | G1, G2 | 15 Nov 2026 | checked |
| `source.<n>.ref` | Application, ApplicationSet | `ref`, the name another source uses as `$ref` (G2) | `element-key` | G2 | 15 Nov 2026 | checked |
| `source.<n>.value-file.<m>` | Application, ApplicationSet | `helm.valueFiles[<m>]`, which may start with `$ref/` (G2) | `rel-path` | G1, G2 | 15 Nov 2026 | checked |
| `source.<n>.helm-values` | Application, ApplicationSet | `helm.values` (a YAML text) | the word `present`, and its block lines are read as a nested values file. The word `other` when those lines hold a layout the reader does not read | G1, G5 | 15 Nov 2026 | checked |
| `source.<n>.helm-values-object` | Application, ApplicationSet | `helm.valuesObject` | the word `present` | G1, G5 | 15 Nov 2026 | checked |
| `source.<n>.helm-parameter-count` | Application, ApplicationSet | `helm.parameters[]` | `int` | G1, G5 | 15 Nov 2026 | checked |
| `source.<n>.kustomize` | Application, ApplicationSet | `kustomize` | the word `present` | G1 | 15 Nov 2026 | checked |
| `go-template` | ApplicationSet | `spec.goTemplate` | `bool` | G3 | 15 Nov 2026 | checked |
| `generator.<i>` | ApplicationSet | the key of `spec.generators[<i>]` | `generator-word` | G3, G4 | 15 Nov 2026 | checked |
| `list-element.<i>.<j>.<key>` | ApplicationSet | `spec.generators[<i>].list.elements[<j>]`, the key and value | `<key>` fits `element-key`. The value fits `short-name` and prints only when the key is one the template uses in `path`, `destination.namespace`, `project`, or `valueFiles`. Every other key prints `present`. A credential-like key prints `present` too | G3 | 15 Nov 2026 | checked |

Notes:

- Values written inside an `Application` (`helm.values`, `valuesObject`, `parameters`) are read like a values file: key names, and the sizing and security values that pass a shape. The next section gives the rule, and the lines use the same field names with the kind `Application`.
- Argo CD gives these values this order, from lowest to highest: the chart's own `values.yaml`, `valueFiles`, `values`, `valuesObject`, `parameters` (G5). When both `valuesObject` and `values` are set, `valuesObject` wins and `values` is ignored (G5).
- Argo CD uses `helm template` to inflate charts, and it handles the lifecycle itself (G5). Argo CD's own sync policy is not read.
- A path in an `ApplicationSet` template can hold a parameter such as `{{.cluster}}` (G3). The `rel-path` shape lets `{`, `}`, `.`, and a space through for that reason. The agent fills the parameter in from the `list-element` lines. A key counts as used by the template when one of those four fields holds `{{`, optional spaces, an optional `.`, the key, optional spaces, and `}}`.
- The List generator makes parameters from a list of key and value pairs written in the file (G3). A generator that is not `list` is `other`. The generator types Argo CD names are List, Cluster, Git, Matrix, Merge, SCM Provider, Pull Request, Cluster Decision Resource, and Plugin (G4). The YAML key for each one other than `list` is not on the pages read (verify).
- A `Matrix` generator can feed a list generator through `elementsYaml` (G3). That is a generator the files cannot resolve, so it is `other`.
- The destination `server` or `name` is not read, because an environment is named by its namespace.
- `ref` sources and `$ref/path` value files are read as written. A source with `ref` cannot also set `chart` (G2).

## The values-file rule

A values file is a Helm chart's `values.yaml` or any other file the Application or the team passes with `-f`. The same rule covers `helm.values`, `helm.valuesObject`, and `helm.parameters` inside an Argo CD object.

**A `helm.values` block.** The text of `helm.values` is nearly always a block scalar (`|`). The reader reads its lines as a nested values file: it takes the lines after the key, removes the indent of the first one from each line, and applies this section to them as if they were a file. The keys print as `values-key.<dotted path>` lines with the kind, namespace, and name of the outer object (`Application` or `ApplicationSet`) and the line numbers of the outer file. The sizing and security values pass the same shapes, and a key with a credential-like name, or under one, never prints a value. Every other block scalar is never read. A `helm.values` that is quoted on one line, or is a template, is not read.

**Key names always.** For every key at every depth, the reader prints one line:

```text
<file>:<line>:Values/-/-:-:values-key.<dotted path>=<state-word>
```

The dotted path joins the keys with `.` and fits `values-path`, with at most 8 keys. The value is only a `state-word`. A key that does not fit `values-path` is counted in `values-key-unreadable-count` (shape `int`). The kind `Values` is the reader's name for a values file. Inside an Argo CD object, the kind, the namespace, and the name are those of the object, `Application` or `ApplicationSet`, as for `helm.values` above. An entry of `helm.parameters` has the form `name` and `value`, and its `name` is the dotted path. A key inside a list item has no dotted path, so it is counted in `values-key-unreadable-count`, and so is a key below the eighth. The count prints at the line of the first such key.

**A value only when the key allows it.** The reader prints `values.<dotted path>=<value>` for a key only when two things hold: the last part of its path is in the table below, and the value passes the shape in the table. A key never prints a value when any key on its path is credential-like (`passwordPolicy.minReplicas`, `auth.replicas`), even when its last part is in the table. A key in the table whose value fails the shape prints `other`.

| Last part of the path | Value shape | What it is | Source | Read | Status |
| --- | --- | --- | --- | --- | --- |
| `cpu` under `requests` or `limits` | `qty-cpu` | A CPU request or limit | K2 | 15 Nov 2026 | checked |
| `memory` under `requests` or `limits` | `qty-mem` | A memory request or limit | K2 | 15 Nov 2026 | checked |
| `privileged`, `allowPrivilegeEscalation`, `readOnlyRootFilesystem`, `runAsNonRoot` | `bool` | A security context flag | K1, K3 | 15 Nov 2026 | checked |
| `runAsUser`, `runAsGroup` | `int` | A security context user or group number | K1, K3 | 15 Nov 2026 | checked |
| list items under `drop` or `add` that sit under `capabilities` | `cap-name` | A capability name | K1, K3 | 15 Nov 2026 | checked |
| `replicaCount` | `int` | A replica count. The key is the name Helm's own example output shows | H6 | 15 Nov 2026 | checked |
| `replicas`, `minReplicas`, `maxReplicas` | `int` | A replica count under another common name. These names are chart conventions, and Helm's pages read do not define them | H6, H7 | 15 Nov 2026 | verify |
| `tag` under a key named `image` | the pin word only: `latest` when the value is `latest`, `tag` for any other value that fits `image-tag`. The text is never printed | An image tag. The `image.tag` key is a chart convention, and the Helm page read does not show it | H6 | 15 Nov 2026 | verify |
| `digest` under a key named `image` | the pin word only: `digest` when the value fits `image-digest`. The text is never printed | An image digest | K26 | 15 Nov 2026 | checked |

The value of a key outside this table never prints. A chart can name its keys as it likes. Helm asks for keys that start with a lower case letter and use camel case (H7), and it leaves the names to the chart. The shapes `image-tag` and `image-digest` only test that a value looks like a tag or a digest. They are never printed, because a token fits the tag shape. A secret placed under `image.tag` is shown as the word `tag`.

A value in a values file with a credential-like key and a `scalar` state counts for K7.

## Fields for each check

For each of the eighteen checks and each column of the reach map, the fields that let a later task judge it. Where a check has no field, or only part of it has one, the last column says so plainly. A check with no field for a part of it can say "ask the team" at best for that part.

| Check | Fields that judge it | Where there is no field |
| --- | --- | --- |
| R1 Every container sets a CPU request and a memory request | `container-kind`, `cpu-request`, `memory-request` on every container, init containers and sidecars included. Context: `limit-default-request.cpu`, `limit-default-request.memory` | A request set by a LimitRange in another repository, or by an admission controller, has no field. R1 covers every entry of `containers` and `initContainers`. The reader has no field for a container's `restartPolicy`, so it treats every entry alike, and whether the pages call an init container with its own restart policy a sidecar was not read (verify). A pod-level request (`cpu-request` with `<container>` `-`) is printed, and it is not a container's own |
| R2 Every container sets a memory limit | `memory-limit`. Context: `limit-default.memory`, `limit-max.memory` | A limit set at admission from elsewhere has no field |
| R3 Each memory limit sits close to its request | `memory-request`, `memory-limit`. Context: `limit-max-ratio.memory` | The reader does no arithmetic. The agent compares the two printed values. A value the reader did not print is "not found" |
| R4 Every autoscaler has what it needs to work | HorizontalPodAutoscaler: `scale-target-api-version`, `scale-target-kind`, `scale-target-name`, `min-replicas`, `max-replicas`, `metric-type`, `metric-resource`, `metric-target-type`, `metric-average-utilization`. VerticalPodAutoscaler: `scale-target-*`, `update-mode`. The targets: `object`, `replicas`, `workload-ref-*`, and `cpu-request`, `memory-request` | Whether a metrics source runs in the cluster has no field. Custom and external metrics are named by `metric-type` and not judged. KEDA is not read |
| R5 Every namespace in the repository sets defaults or ceilings | The namespaces: the `<namespace>` of each object, `destination-namespace`, and Namespace objects. Defaults and ceilings: every `limit-*` field and `quota-hard.*` field | A namespace set only in the cluster has no field. A manifest with no `metadata.namespace` has the namespace `-`, which `destination-namespace` or a Kustomize `namespace` field may fill in. A Kustomize `namespace` field has no field in version 1, but a rendered overlay carries the namespace on each object |
| R6 Scratch space has a ceiling | `volume-name`, `volume-type`, `emptydir-size-limit`, `emptydir-medium`. Context: `ephemeral-storage-limit`, `quota-hard.*ephemeral-storage` | What happens when a `sizeLimit` is exceeded is not on the page read (verify). Container logs and image layers count against ephemeral storage and have no field |
| R7 Batch work has an end | Job and CronJob: `active-deadline-seconds`, `backoff-limit`, `ttl-seconds-after-finished`, `concurrency-policy`, `starting-deadline-seconds`, `history-limit-successful`, `history-limit-failed`. Pod-level: `pod-active-deadline-seconds` (on a bare Pod, or in the template of any kind) | A workload that is a Deployment doing batch work has no field to say so. The application's own timeouts are in code, not in a file the reader reads |
| R8 Requests match measured use | None in the repository. The requests (`cpu-request`, `memory-request`) are the repository's side of the comparison | The measured use is not in any file. The cluster pass is the only answer, and it follows "Command section 3" |
| K1 No container runs as root or privileged | `privileged`, `run-as-non-root`, `run-as-user`, `run-as-group` at both levels, `container-kind` | The user in the image has no field, so an unset `run-as-user` is not a pass |
| K2 Containers drop capabilities and block privilege escalation | `cap-drop`, `cap-add`, `allow-privilege-escalation`, `privileged` | A runtime default capability set (K1) has no field. The seccomp and AppArmor profiles have no field |
| K3 The root filesystem is read-only | `read-only-root-fs`. Context: `mount.<volume-name>`, `volume-type`, `emptydir-size-limit` | Which paths a program writes has no field, so a read-only root with no writable volume is not proof that the program runs |
| K4 No pod shares the host | `host-network`, `host-pid`, `host-ipc`, `volume-type` with `host-path`, `mount.<volume-name>` (the page says path restrictions on a hostPath hold only for read-only mounts, K15), `host-port` | A `hostUsers` setting and a `procMount` setting have no field |
| K5 Each workload has its own ServiceAccount, and mounts a token only when it calls the API | `service-account` and `automount-sa-token` on the pod, `automount-sa-token` on each ServiceAccount, and the bindings that name the account (`subject.<n>.*`, `role-ref-*`) | Whether the workload calls the Kubernetes API has no field. The question for the team covers it |
| K6 RBAC rules name their verbs and their resources | `rule.<n>.verb`, `rule.<n>.resource`, `rule.<n>.api-group`, `rule.<n>.resource-names-count`, `rule.<n>.non-resource-urls-count`, `aggregation-rule`, `role-ref-*`, `subject.<n>.*` | The rules of an aggregated ClusterRole are filled in by a controller in the cluster (K16) and have no field. A role set only in the cluster has no field |
| K7 Secrets stay out of manifests and values files | `object` of kind Secret, `secret-type`, `secret-key.*`, `env.<NAME>` with `literal`, `env-other-count`, `args-credential-like-count`, `annotation-credential-like-count`, `configmap-data.<key>` with `scalar`, `values-key.*` with `scalar`, `source.<n>.url-has-user-part`, `list-element` lines | The value itself is never printed, so the report names a file, a line, and a type, and cannot say how strong a secret is. A sealed or external secret kind is not read. A secret inside a Helm template that is not rendered is "not found" |
| K8 A NetworkPolicy covers every workload | `np-pod-selector`, `np-pod-label.<key>`, `np-policy-type`, and the workload's `pod-label.<key>` and `<namespace>` | A label with a key outside the list has no value, and a selector that uses one cannot be matched. The network plugin has no field |
| K9 Images are pinned and come from a named registry | `image-registry`, `image-repository`, `image-pin`, `image-pull-policy`. In values files: the `values.<dotted path>` lines whose path ends in `image.tag` or `image.digest` | What a tag points to at the registry has no field. Image scanning is not in scope |
| K10 Namespaces enforce a Pod Security level | `psa-enforce`, `psa-enforce-version`, `psa-warn`, `psa-warn-version`, on Namespace objects | A level set in the API server's own configuration instead of a label has no field. Whether that route exists was not read (verify) |
| Reach map: ServiceAccount | `service-account`, `automount-sa-token` | A default ServiceAccount has no object in the repository |
| Reach map: roles bound and what they allow | `subject.<n>.*`, `role-ref-*`, `rule.<n>.*` | A binding in another repository has no field |
| Reach map: Secrets and ConfigMaps it names | `env-ref.<NAME>`, `env-from-secret`, `env-from-configmap`, `secret-volume-name`, `configmap-volume-name` | Projected volume sources have no field in version 1 |
| Reach map: peers its NetworkPolicies allow in and out | `np-*` fields and `pod-label.<key>` | The same gaps as K8 |
| Reach map: access to the host | `host-network`, `host-pid`, `host-ipc`, `host-path`, `host-port`, `privileged`, `cap-add` | The same gaps as K4 |

## Command section 1: render commands

The reader renders only after a yes, and it pipes the output of the render tool straight into its own extractor. The rendered text never reaches the agent. The reader passes only the arguments below.

**Helm.** The form is `helm template NAME CHART [flags]` (H1). The reader runs:

```text
helm template <release name> <chart directory> --skip-schema-validation --values <values file> [--values <values file>] --namespace <namespace>
```

`--skip-schema-validation` is in the fixed command because a render with only the other flags can fetch a remote JSON-schema `$ref` from `values.schema.json`, in the chart or in a vendored subchart (checked, T1, helm v4.3.2, `unshare -n helm template r s1`: DNS connect attempts and `HTTP request failed` with the flag missing, and exit 0 with no connect call with the flag set). A `file://` `$ref` is loaded and applied. The release name and the namespace have to fit `dns-label`. The release name is the chart directory's name when it fits `dns-label` and has at most 53 characters, and `release` otherwise. The namespace is `default` unless the agent passes `--namespace NAME` to the reader. The reader runs the tool from the repository root with a cleared environment (`env -i` with `PATH`, `HOME=/nonexistent`, and `LC_ALL=C`), so no Helm or kubectl setting of the user reaches it. A render takes values files only, so the `helm.values` block of an `Application` is not in the rendered output. The agent reads it from the `values-key` and `values` lines of `--fields` on the `Application`. The chart is a directory in this repository that holds `Chart.yaml`, and each values file is an existing file in this repository. `--values` and `-f` are the same flag, and the page says the value may be a YAML file or a URL (H1), so the reader passes only a path that exists on disk.

What the page says `helm template` does with no cluster (checked, H1):

- It renders chart templates locally. Values that the chart would look up in a cluster are faked locally. The page does not say that a render makes no request at all, and it can: see the schema `$ref` run above, which is why the fixed command carries `--skip-schema-validation`.
- It does no server-side chart validity check, such as API support.
- Its `--dry-run` flag takes `client` or `server`. The default is `client`, which avoids cluster connections. `server` needs cluster connectivity (H1, H2).

What the page says about dependencies (H1, H3, H4, H5):

- `--dependency-update` updates dependencies that are missing before the chart is installed (H1, H2). It is the flag that fetches them.
- Dependencies sit in the chart's `charts/` directory, as `.tgz` archives or unpacked directories (H3). `helm dependency update` downloads them. `helm dependency build` rebuilds `charts/` from `Chart.lock`, and acts as an update when there is no lock file (H5).
- A `file://` repository entry is a local path, and version matching still applies (H4).
- When `charts/` lacks a declared dependency, `helm template` fails and renders nothing (checked, T1, helm v4.3.2, 15 Nov 2026, `helm template r chart1` on a chart that declares `redis` and has no `charts/` directory). Exit status 1, nothing on standard output, and one `Error:` line on standard error that says the dependency is found in `Chart.yaml` but missing in the `charts/` directory. The run made no network request, because Helm stops before it fetches. The reader still refuses first (section 2), so it does not depend on this.
- `lookup` in a template, with no cluster and no kubeconfig, returns an empty map and the render succeeds (checked, T1, helm v4.3.2, 15 Nov 2026, `helm template r chart2` where the template calls `lookup "v1" "Namespace" "" "kube-system"`). Exit status 0, the output holds `{}`, `empty` is true, and standard error is empty. This matches the page's statement that looked-up values are faked locally (H1).
- Helm v4.3.2 accepts a `--validate` flag that its help does not list. It prints `Flag --validate has been deprecated, use '--dry-run=server' instead`, then tries to reach a cluster at `http://localhost:8080/version`, and exits 1 with nothing rendered (checked, T1, helm v4.3.2, 15 Nov 2026, `helm template r chart2 --validate`). `--dry-run=server` fails the same way (`helm template r chart2 --dry-run=server`).

Flags the reader must never pass. Each one can reach a cluster, a registry, a chart repository, a URL, or a file write. This table is not exhaustive. The command written above governs: the reader passes the arguments in it and no other, whether or not a flag is listed here.

| Flag | Why it is never passed | Source | Read | Status |
| --- | --- | --- | --- | --- |
| `--dry-run=server` (and `--dry-run` with any value other than `client`) | Needs cluster connectivity | H1, H2 | 15 Nov 2026 | checked |
| `--dependency-update` | Updates missing dependencies, which fetches them | H1 | 15 Nov 2026 | checked |
| `--repo` | A chart repository address, so the chart is fetched | H1 | 15 Nov 2026 | checked |
| `--version`, `--devel` | Choose a chart version, which only means something for a fetched chart | H1 | 15 Nov 2026 | checked |
| `--username`, `--password`, `--pass-credentials` | Credentials for a chart repository | H1 | 15 Nov 2026 | checked |
| `--plain-http`, `--insecure-skip-tls-verify`, `--ca-file`, `--cert-file`, `--key-file` | Options of a chart download | H1, H5 | 15 Nov 2026 | checked |
| `--verify`, `--keyring` | Verify a downloaded package against signatures | H1 | 15 Nov 2026 | checked |
| `--kubeconfig`, `--kube-context` | Choose the cluster to use | H1 | 15 Nov 2026 | checked |
| `--kube-apiserver`, `--kube-token`, `--kube-ca-file`, `--kube-as-user`, `--kube-as-group` | Cluster connection flags of Helm itself | H5 | 15 Nov 2026 | checked |
| `--enable-dns` | Enables DNS lookups while rendering templates | H1 | 15 Nov 2026 | checked |
| `--output-dir` | Writes the rendered files. The reader writes nothing | H1 | 15 Nov 2026 | checked |
| `--set-file` | Sets values from files named on the command line, and the reader has not checked those paths | H1 | 15 Nov 2026 | checked |
| `--validate` | Hidden and deprecated in helm v4.3.2, it acts as `--dry-run=server` and tries to reach a cluster | T1 (`helm template r chart2 --validate`, helm v4.3.2) | 15 Nov 2026 | checked |
| `--post-renderer`, `--post-renderer-args` | New in the helm v4.3.2 help: runs a post-render plugin, which is code | T1 (`helm template --help`, helm v4.3.2) | 15 Nov 2026 | checked |
| `--kube-insecure-skip-tls-verify`, `--kube-tls-server-name` | Cluster connection flags of Helm itself, in the v4.3.2 global flags | T1 (`helm template --help`, helm v4.3.2) | 15 Nov 2026 | checked |
| `--registry-config`, `--repository-config`, `--repository-cache`, `--content-cache` | Point Helm at registry, repository, and cache files or folders that the reader has not checked | T1 (`helm template --help`, helm v4.3.2) | 15 Nov 2026 | checked |
| `--set`, `--set-string`, `--set-json`, `--set-literal` | Values typed on the command line. The reader passes values files only | T1 (`helm template --help`, helm v4.3.2) | 15 Nov 2026 | checked |

The reader also never passes a chart name, a `oci://` address, or a `https://` address as the chart.

**Kustomize.** The two forms are `kustomize build DIR` and `kubectl kustomize DIR [flags]` (K34). The reader runs `kustomize build <directory>` when `kustomize` is installed, and `kubectl kustomize <directory>` otherwise. It passes the directory and nothing else.

What the pages say (checked):

- The `DIR` argument of `kubectl kustomize` is a directory that holds `kustomization.yaml`, or a Git repository URL with a path suffix (K34). So a URL is a valid argument, and the reader passes a local directory only.
- A `resources` entry can be a file, a local directory, or a remote address: a Git clone URL over HTTPS or SSH, with an optional `//` directory and query parameters such as `ref` and `timeout`. A legacy form, a modified go-getter address, is no longer recommended (Z3, Z5). A `file:///` address clones a local repository (Z3).
- A directory that holds a `kustomization.yaml` can be local or in a remote Git repository (Z4).
- `kustomize build` has no documented flag that switches remote loading off (Z1, Z2, K34, Z3). The reader therefore checks the files before it builds. See section 2.
- Every kustomize plugin currently needs `--enable-alpha-plugins`. Without it, kustomize does not load plugins and fails with a warning (Z2). Exec plugins also need `--enable-exec`, and `kubectl kustomize` marks them as disabled (Z2). The guide says plugins do not run in any sandbox that kustomize provides (Z2).
- The Helm chart inflator (`helmCharts`) needs `--enable-helm` (Z7, K34).
- `--load-restrictor` defaults to `LoadRestrictionsRootOnly`. Setting it to `LoadRestrictionsNone` lets a local kustomization load files from outside its root (K34).

Flags the reader must never pass:

| Flag | Why it is never passed | Source | Read | Status |
| --- | --- | --- | --- | --- |
| `--enable-alpha-plugins` | Enables plugins, which run code | Z2, K34 | 15 Nov 2026 | checked |
| `--enable-exec` | Enables exec plugins. `kubectl kustomize` v1.37.2 does not accept it (`error: unknown flag: --enable-exec`), and an exec plugin fails without it. See the note under the table | Z2, T2 (`kubectl kustomize ov3 --enable-exec`, kubectl v1.37.2) | 15 Nov 2026 | checked |
| `--enable-helm` | Enables the Helm chart inflator, which can fetch a chart | Z7, K34 | 15 Nov 2026 | checked |
| `--helm-command`, `--helm-api-versions`, `--helm-debug`, `--helm-kube-version` | Options of the Helm inflator | K34 | 15 Nov 2026 | checked |
| `--load-restrictor` | `LoadRestrictionsNone` lets a build read outside its root | K34 | 15 Nov 2026 | checked |
| `--network`, `--network-name` | Network access for containerised functions | K34, Z2 | 15 Nov 2026 | checked |
| `--mount`, `-e`, `--env`, `--as-current-user` | Options of containerised functions | K34 | 15 Nov 2026 | checked |
| `-o`, `--output` | Writes the build to a path. The reader writes nothing | K34 | 15 Nov 2026 | checked |
| `--reorder` | Not a flag of `kubectl kustomize` in kubectl v1.37.2 (Kustomize v5.8.1), and the reader has no use for it. The standalone binary was not installed, so its flags are not read | T2 (`kubectl kustomize --help`, kubectl v1.37.2) | 15 Nov 2026 | checked |

A standalone `kustomize build` page was read as well (Z1). It lists no flag, so the flag names above come from `kubectl kustomize` (K34) and the plugin guide (Z2). Whether the standalone binary takes exactly the same flags is not shown (verify): no standalone `kustomize` binary is installed in this workspace, so only the one built into kubectl v1.37.2 (Kustomize v5.8.1) was read.

What the local tools showed (checked, T2, kubectl v1.37.2 with Kustomize v5.8.1, 15 Nov 2026, run on small overlays under /tmp, none in the repository):

- `kubectl kustomize --help` lists these flags: `--as-current-user`, `--enable-alpha-plugins`, `--enable-helm`, `-e` and `--env`, `--helm-api-versions`, `--helm-command`, `--helm-debug`, `--helm-kube-version`, `--load-restrictor`, `--mount`, `--network`, `--network-name`, and `-o` and `--output`. It does not list `--enable-exec`.
- An overlay with a `helmCharts` entry and no flag fails with exit status 1, nothing on standard output, and `must specify --enable-helm` on standard error (`kubectl kustomize ov2`).
- An overlay with a generator that carries an exec function annotation and no flag fails with exit status 1 and `external plugins disabled; unable to load external plugin` on standard error (`kubectl kustomize ov3`). The plugin did not run.
- An overlay whose `resources` entry is `file:///` plus the path of a local Git repository builds with exit status 0 and no flag, so a remote-form base is cloned and read without any switch (`kubectl kustomize ov1`). That is the reason the reader refuses on the file text. The run used a local repository, so it made no network request. A real remote base was not run.
- An overlay whose `resources` entry is a symbolic link to a directory outside the overlay builds that directory with exit status 0 (`unshare -n kubectl kustomize repo2/ov`, T2, kubectl v1.37.2). `helm template` on a chart whose `templates/cm.yaml` is a link to an outside file logs `found symbolic link in path. Contents of linked file included and used` and renders it (T1, helm v4.3.2). Both are the reason for the `symbolic link inside` refusal. `find <directory> -type l` listed each link and listed nothing for a clean chart.

## Command section 2: when the reader refuses to render

The reader refuses before it runs a render tool. Each refusal prints a line `<path>:<kind>:<state>` with one of these states, and the agent reports it as "not rendered". Every refusal state other than `not read` exits with code 3; `not read` exits with code 4. Each reason has a trigger that the reader tests on the files, not on the tool's behaviour.

| State | Trigger | Why | Source | Read | Status |
| --- | --- | --- | --- | --- | --- |
| `tool not installed` | `helm`, `kustomize`, and `kubectl` are not on the path | There is nothing to run | not applicable | 15 Nov 2026 | checked |
| `not a local file` | The chart, the overlay, or a values file is missing, has a symbolic link or a `..` in any part of its path, or is not inside the repository. Also when any file or directory in the chart tree, or in a directory the overlay reaches, has a line break in its name. "Inside" is tested on the resolved path (`cd -P` and `pwd -P`) against the resolved top of the Git repository the reader runs in | A symbolic link is refused in every mode. A path outside the repository is not read | not applicable | 15 Nov 2026 | checked |
| `symbolic link inside` | `find <chart directory> -type l` prints anything. The same test for every directory an overlay reaches through `resources`, `bases`, or `components`. Also when any of those directories resolves, after links are followed, to a place outside the repository | A link inside a chart or overlay tree is followed by the render tool, so a template, a `.Files.Get` read, a vendored dependency or a resource can be an outside file | T1 (`helm template r c1`, helm v4.3.2), T2 | 15 Nov 2026 | checked |
| `remote schema ref` | A file named `values.schema.json` anywhere in the chart directory holds the text `$ref` or `$id`, whatever follows it | A remote `$ref` is fetched while the schema is validated, and a `file://` one reads any file. An `$id` changes the base that a relative `$ref` resolves against. Testing for the text and not for the scheme leaves no form to miss. Only a second guard: the fixed command passes `--skip-schema-validation`. A `.tgz` dependency cannot be read line by line, so it relies on the flag | T1 (`helm template r s1` inside `unshare -n`, helm v4.3.2) | 15 Nov 2026 | checked |
| `dependencies not vendored` | `Chart.yaml` has a `dependencies` list, and for any `name` in it, `charts/` holds neither a directory named `<name>` nor an archive that starts `<name>-` and ends `.tgz` | The charts would have to be fetched. `--dependency-update` is the flag that fetches, and the reader never passes it | H3, H4 | 15 Nov 2026 | checked |
| `remote base` | A `resources`, `bases`, `components`, `crds`, `configurations`, or `patchesStrategicMerge` entry, or a path of `patches`, `patchesJson6902`, `replacements`, `openapi`, or a generator's `files`, `envs`, or `env`, in the overlay or in any kustomization it reaches through a local path, is not a plain scalar (a block scalar, a folded scalar, or a value the reader cannot read), or is a form kustomize can take for a repository even when a local path of that name exists (a value with `://`, `//`, `?`, `@`, `:`, a backslash, `git::`, `gh:`, `_git`, or `.git`, an absolute path, or a first part with a dot, such as `github.com/org/repo`, on a path with more parts or on a directory), or is not an existing local file or directory in the repository. Also when an item directly under `patches`, `patchesJson6902`, `replacements`, `configMapGenerator`, or `secretGenerator` is not a map | A remote entry makes kustomize clone or download. The entries include an address with `://`, a `git@` or `ssh://` address, a `file:///` address, a legacy address with no scheme, and a raw file address | Z3, Z5 | 15 Nov 2026 | checked |
| `remote base` (other fields) | The same test for the other kustomization fields that name a path | Whether URLs work in every such field is not on the pages read, so the test is wider than the pages (verify) | Z4, Z5 | 15 Nov 2026 | verify |
| `plugin or inflator needed` | The overlay, or a kustomization it reaches, has a `helmCharts`, `helmGlobals`, `helmChartInflationGenerator`, `generators`, `transformers`, or `validators` key. The reader does not tell a built-in configuration from a plugin, so any entry under the last three refuses | Each needs `--enable-helm` or `--enable-alpha-plugins`, which the reader never passes | Z2, Z7 | 15 Nov 2026 | checked |
| `render failed` | The render tool exits with a status other than 0 | The reader prints the state on standard output and the exit status on standard error, and nothing the tool wrote. Standard error of the tool is dropped | not applicable | 15 Nov 2026 | checked |
| `not read` | The reader cannot place the file, for example a binary file or a file that is not text, a kustomization it cannot read, or a rendered output with a layout it does not read. Exit code 4 | A file the reader cannot place is not read | not applicable | 15 Nov 2026 | checked |

The plugin test reads files by line and does not parse. When it cannot tell whether an entry is a built-in generator or a plugin, it refuses. The cost of a wrong refusal is "not rendered", and the cost of a wrong render is code that runs.

A refusal never stops the first pass. The agent reads the files as they are and says so in the report.

## Command section 3: the cluster commands

The cluster script runs these commands and no others. It takes only namespace names, and it builds every command itself from the fixed list below. It never passes an argument it did not write.

**The front door.** Every argument is tested before any other work, and before `kubectl` is looked for. A namespace name must be a DNS label in the namespace sense: lower case letters, digits, and `-`, at most 63 characters, starting and ending with a letter or a digit (K22). Any other argument, including an empty one, one that starts with `-`, one with a space, a `;`, a `/`, a `.`, a capital letter, or a control character, and one that ends in a line break, stops the run with exit code 2, and no command runs. The message names no argument. `--context` and `--help` must each be the only argument. The test for a namespace is the script's own shell test, and not the `dns-label` shape, because a namespace may start with a digit.

The script puts `--namespace=<name>` after the verb, as one argument, so that a name cannot be read as a flag.

| Step | Command | Columns it needs | Source | Read | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | `kubectl config current-context` | The context name, so the offer can name it | K29, K33, T2 (`KUBECONFIG=/tmp/lc2/kc kubectl config current-context`, kubectl v1.37.2) | 15 Nov 2026 | checked |
| 2 | `kubectl top pod`, line 2 of the fixed list below | The pod, the container, the CPU, and the memory in use. The column order is not on the page read, so the script and the stand-in must be written against a real run (verify) | K28 | 15 Nov 2026 | verify |
| 3 | `kubectl get pods`, line 3 of the fixed list below | See below | K30, K31, K1, K32 | 15 Nov 2026 | verify |
| 4 | `kubectl get verticalpodautoscalers.autoscaling.k8s.io`, line 4 of the fixed list below | See below | K30, K31, V1 | 15 Nov 2026 | verify |
| 5 | `kubectl get horizontalpodautoscalers.autoscaling`, line 5 of the fixed list below | See below | K30, K31, K9 | 15 Nov 2026 | verify |

The fixed command list of the cluster script, one command on each line. The script holds the same lines, between `# BEGIN the fixed command list` and `# END the fixed command list`, and replaces `<name>` with each namespace it was given and `<context>` with the context name it read in step 1 of the same run. The test of the script checks that the two are the same, and the stand-in `kubectl` answers only these lines.

```text
kubectl config current-context --kubeconfig= --context= --server= --cluster=
kubectl top pod --containers --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --no-headers --all-namespaces=false --selector= --field-selector= --show-swap=false --sum=false --request-timeout=20s
kubectl get pods --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --no-headers --all-namespaces=false --watch=false --watch-only=false --selector= --field-selector= --ignore-not-found=false --output-watch-events=false --show-kind=false --show-labels=false --show-managed-fields=false --label-columns= --subresource= --allow-missing-template-keys=true --template= --filename= --kustomize= --raw= --request-timeout=20s -o custom-columns=POD:.metadata.name,CONTAINERS:.spec.containers[*].name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory,STATUS_NAMES:.status.containerStatuses[*].name,RESTARTS:.status.containerStatuses[*].restartCount,LAST_END:.status.containerStatuses[*].lastState.terminated.reason
kubectl get verticalpodautoscalers.autoscaling.k8s.io --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --no-headers --all-namespaces=false --watch=false --watch-only=false --selector= --field-selector= --ignore-not-found=false --output-watch-events=false --show-kind=false --show-labels=false --show-managed-fields=false --label-columns= --subresource= --allow-missing-template-keys=true --template= --filename= --kustomize= --raw= --request-timeout=20s -o custom-columns=VPA:.metadata.name,TARGET_KIND:.spec.targetRef.kind,TARGET:.spec.targetRef.name,MODE:.spec.updatePolicy.updateMode,RECO_CONTAINER:.status.recommendation.containerRecommendations[*].containerName,CPU_TARGET:.status.recommendation.containerRecommendations[*].target.cpu,MEM_TARGET:.status.recommendation.containerRecommendations[*].target.memory,CPU_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.cpu,MEM_LOWER:.status.recommendation.containerRecommendations[*].lowerBound.memory,CPU_UPPER:.status.recommendation.containerRecommendations[*].upperBound.cpu,MEM_UPPER:.status.recommendation.containerRecommendations[*].upperBound.memory
kubectl get horizontalpodautoscalers.autoscaling --namespace=<name> --context=<context> --kubeconfig= --server= --cluster= --no-headers --all-namespaces=false --watch=false --watch-only=false --selector= --field-selector= --ignore-not-found=false --output-watch-events=false --show-kind=false --show-labels=false --show-managed-fields=false --label-columns= --subresource= --allow-missing-template-keys=true --template= --filename= --kustomize= --raw= --request-timeout=20s -o custom-columns=HPA:.metadata.name,TARGET_KIND:.spec.scaleTargetRef.kind,TARGET:.spec.scaleTargetRef.name,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,CURRENT:.status.currentReplicas,DESIRED:.status.desiredReplicas,METRIC_TYPE:.spec.metrics[*].type,METRIC:.spec.metrics[*].resource.name,UTILIZATION:.spec.metrics[*].resource.target.averageUtilization
```

The order of the runs: step 1 once, then steps 2 to 5 for each namespace in the order given. With `--context`, step 1 only.

**How `kubectl` runs.** Every command runs as `kubectl ... </dev/null 2>/dev/null`, in the environment of the user who runs the script, as it is, with `LC_ALL=C` set on top for the whole script. The environment is the user's own, not the scanned repository's, and the credential plugins that cloud clusters name in a kubeconfig `exec` entry (EKS, GKE, and AKS) and a proxy need the user's variables. Standard input is closed, so an interactive credential plugin cannot wait for an answer. Standard error is dropped, and the script prints its own plain message instead. The script does not set `KUBERC` and does not touch the user's preferences file (`~/.kube/kuberc`). That file holds aliases, default flags, and a `credentialplugin` section whose `--policy` is `AllowAll`, `DenyAll`, or `Allowlist`, and `KUBERC=off` switches the whole file off, the policy included (`kubectl kuberc set --help`, checked, T2). A user who keeps a policy against untrusted `exec` entries keeps it when this script runs.

What the kept environment and the kubeconfig can still change: the kubeconfig's `exec` entries (which program runs to fetch a credential), its `as` entries (impersonation), and its `proxy-url`; the `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY` variables; and `KUBECACHEDIR`, where the discovery cache lives (verify, not read in the documentation on the build date). A kuberc file can add default flags to `top` and `get`.

**The context is pinned.** In the namespace mode the script reads the context name first, with step 1. When the answer does not fit `context-name`, it stops with exit code 5 and runs nothing else. Otherwise it passes that name as `--context=<context>`, one argument, on every `top` and `get`, and the `# context` line prints the same name. So the tables come from the context the header names, whatever a kuberc default or the kubeconfig says. Step 1 itself carries `--kubeconfig= --context= --server= --cluster=`, so a kuberc default cannot point it at another kubeconfig file.

**What bounds the output.** The fixed argument list, which no variable changes; `--namespace=<name>`, which overrides the namespace of the kubeconfig context (verify); built-in verbs, which a kuberc alias does not shadow (checked, T2: an alias named `config` left `kubectl config current-context` as it was) and a `kubectl-*` plugin on `PATH` does not either (verify); and the explicit values of the class "set by the fixed command" in the table below, because an explicit flag wins over a kuberc default. Every flag of the four help outputs is in that table, in one of three classes, and the test fails on a flag that is not.

How this was checked (T2, kubectl v1.37.2, 16 Nov 2026, under `unshare -n` with `HOME`, `KUBECONFIG`, and `KUBERC` pointed at files under /tmp):

- The merged command. With `-v=6`, kubectl logs the merged command ("original command") before it connects, with every kuberc default it appended. A kuberc set a default for every flag of `get` and `top pod`, and for `--context`, `--kubeconfig`, `--server`, and `--cluster` on `config current-context`. With the fixed list, the merged `config current-context` carried nothing, the merged `top pod` only `--sort-by` and `--use-protocol-buffers`, and the merged `get` only `--recursive`, `--chunk-size`, `--server-print`, and `--sort-by`.
- A stand-in API. A small HTTP server on the loopback address of the network namespace answered discovery, the pod list, and the pod metrics. The kubeconfig had two contexts, one at that server and one at a port where nothing listens; a second kubeconfig named the other context as current, and a third defined the first context's name with the other cluster. With the kuberc defaults pointing at the other context, the second or third kubeconfig, the other server, and the other cluster, the fixed `get` and `top` asked the kubeconfig's server for `/api/v1/namespaces/<name>/pods` and `/apis/metrics.k8s.io/v1beta1/namespaces/<name>/pods`, as without kuberc, and printed the same rows. Leaving out any one of `--kubeconfig=`, `--server=`, `--cluster=`, and `--context=<context>` sent the request to the port where nothing listens (exit 1). Leaving out `--template=` gave "unable to match a printer suitable for the output format" (exit 1), `--filename=` "the path ... does not exist", `--kustomize=` "the -k flag can't be used with -f or -R", and `--raw=` "arguments may not be passed when --raw is specified".
- `config current-context` followed a kuberc `kubeconfig` default and printed the current context of the other file; with `--kubeconfig=` it printed the context of `KUBECONFIG`. It ignored a kuberc `context` default.
- With kuberc defaults for `--chunk-size` (1), `--server-print` (false), and `--recursive` (true), `get` printed the same rows. The stand-in API ignored `limit` and sent the whole list at once, so paging over several chunks was not exercised (verify).

**The output shapes are the last control.** Explicit `-o custom-columns` and `--no-headers` win over a default. A row that does not fit its column count, and a cell that does not fit its shape, prints `other`, `not-read`, or a count. A value that fits its shape in the right column prints as it came, so the control is the explicit flags and not the shapes.

**Every flag of the four commands.** The flags of `kubectl get --help`, `kubectl top pod --help`, `kubectl config current-context --help` (which lists none of its own), and `kubectl options` for kubectl v1.37.2, each in one class (checked, T2). "Set by the fixed command" means the fixed list passes the value shown on every command that has the flag. "Left to the user" means a kuberc default or a value the user set may apply, with the effect shown, and it cannot remove, add, or misattribute a row, or its failure leaves a trace. "Identity and transport" means it changes who asks or how, not where the answer comes from, and it is left to the user and named in the cluster offer. The test of the script reads the help of the installed kubectl and fails on a flag that this table does not classify.

| Flag | Commands | Class | Value or effect |
| --- | --- | --- | --- |
| `--all-namespaces` | get, top pod | set by the fixed command | `--all-namespaces=false` |
| `--allow-missing-template-keys` | get | set by the fixed command | `--allow-missing-template-keys=true` |
| `--containers` | top pod | set by the fixed command | `--containers` |
| `--field-selector` | get, top pod | set by the fixed command | `--field-selector=` (empty, filters nothing) |
| `--filename` | get | set by the fixed command | `--filename=` |
| `--ignore-not-found` | get | set by the fixed command | `--ignore-not-found=false` |
| `--kustomize` | get | set by the fixed command | `--kustomize=` |
| `--label-columns` | get | set by the fixed command | `--label-columns=` |
| `--no-headers` | get, top pod | set by the fixed command | `--no-headers` |
| `--output` | get | set by the fixed command | `-o custom-columns=...` |
| `--output-watch-events` | get | set by the fixed command | `--output-watch-events=false` |
| `--raw` | get | set by the fixed command | `--raw=` |
| `--selector` | get, top pod | set by the fixed command | `--selector=` (empty, filters nothing) |
| `--show-kind` | get | set by the fixed command | `--show-kind=false` |
| `--show-labels` | get | set by the fixed command | `--show-labels=false` |
| `--show-managed-fields` | get | set by the fixed command | `--show-managed-fields=false` |
| `--show-swap` | top pod | set by the fixed command | `--show-swap=false` |
| `--subresource` | get | set by the fixed command | `--subresource=` |
| `--sum` | top pod | set by the fixed command | `--sum=false` |
| `--template` | get | set by the fixed command | `--template=` |
| `--watch` | get | set by the fixed command | `--watch=false` |
| `--watch-only` | get | set by the fixed command | `--watch-only=false` |
| `--cluster` | all four | set by the fixed command | `--cluster=` |
| `--context` | all four | set by the fixed command | `--context=<context>` on `top` and `get`, the name the script read; `--context=` on `config current-context` |
| `--kubeconfig` | all four | set by the fixed command | `--kubeconfig=`, so `KUBECONFIG` or `~/.kube/config` is read |
| `--namespace` | get, top pod | set by the fixed command | `--namespace=<name>` |
| `--request-timeout` | get, top pod | set by the fixed command | `--request-timeout=20s` |
| `--server` | all four | set by the fixed command | `--server=` |
| `--chunk-size` | get | left to the user | pages the list from the server; same rows against the stand-in API, which sent one page (paging verify) |
| `--recursive` | get | left to the user | applies only with `--filename`, which is empty; same rows against the stand-in API |
| `--server-print` | get | left to the user | asks the server for its table output, which `custom-columns` does not use; same rows against the stand-in API |
| `--sort-by` | get, top pod | left to the user | changes only the order of the rows (help text) |
| `--use-protocol-buffers` | top pod | left to the user | changes only how `top` talks to the Metrics API (help text) |
| `--cache-dir` | all four | left to the user | where the discovery cache lives; a stale cache can make a query fail, which leaves a trace (verify) |
| `--kuberc` | all four | left to the user | the user's preferences file; its defaults for the flags set above do not apply, and its credential plugin policy stays in force |
| `--log-flush-frequency` | all four | left to the user | log timing on standard error, which the script drops |
| `--profile` | all four | left to the user | kubectl writes a profile file when it is set (the script itself writes nothing); no effect on the output |
| `--profile-output` | all four | left to the user | the name of that profile file |
| `--v` | all four | left to the user | log detail on standard error, which the script drops |
| `--vmodule` | all four | left to the user | log detail on standard error, which the script drops |
| `--warnings-as-errors` | all four | left to the user | a server warning makes the command fail, which leaves a trace |
| `--as` | all four | identity and transport | impersonate a user |
| `--as-group` | all four | identity and transport | impersonate a group |
| `--as-uid` | all four | identity and transport | impersonate a UID |
| `--as-user-extra` | all four | identity and transport | impersonation extras |
| `--certificate-authority` | all four | identity and transport | the CA used to check the server |
| `--client-certificate` | all four | identity and transport | the client certificate |
| `--client-key` | all four | identity and transport | the client key |
| `--disable-compression` | all four | identity and transport | response compression |
| `--insecure-skip-tls-verify` | all four | identity and transport | skips the server certificate check |
| `--match-server-version` | all four | identity and transport | requires a matching server version, or the command fails (a trace) |
| `--password` | all four | identity and transport | basic authentication |
| `--proxy-url` | all four | identity and transport | a proxy to reach the server |
| `--tls-server-name` | all four | identity and transport | the server name for the certificate check |
| `--token` | all four | identity and transport | a bearer token |
| `--user` | all four | identity and transport | the kubeconfig user |
| `--username` | all four | identity and transport | basic authentication |

The "identity and transport" class gets no empty value, on purpose: the user's own credentials and transport decide who asks, and the cluster offer names them as the user's.

**A NUL in the output.** A shell's command substitution drops a NUL byte, so `app`, a NUL, and `x` would read as `appx`. The script turns every NUL in kubectl's output into the control character 1 before it reads a line, so the row is counted and not printed (see "What the script prints"). The exit status of `kubectl` is kept through that step.

What was read for each step:

- **Step 1.** The documentation page gives the command a one-line description, and it does not say whether the command contacts the cluster (K29). The command's own source file reads the starting configuration through `ConfigAccess`, and writes `config.CurrentContext`. It builds no REST client and sends no request (K33, read from the project's source on the build date). That makes the context name a local read. The status is "checked" on the strength of the source file, and the documentation page is silent. The local run agrees (T2, kubectl v1.37.2, 15 Nov 2026): with a kubeconfig file that sets a context whose server address is not reachable, the command printed the context name and exited 0, and a trace of the process (`strace -f -e trace=connect,socket`) showed no socket or connect call. With an empty file or a missing file it exits 1 and prints `error: current-context is not set`, with nothing else. The script prints the name when it fits `context-name`, and `other` when it does not. A failure is exit code 5, with a message that the command failed and no guess at the cause. An empty answer, or one of only spaces or tabs, is exit code 5 too. In the namespace mode an answer that does not fit `context-name` is exit code 5 as well, because the name is passed on as `--context` (see "The context is pinned"). The `--context` mode prints `other` for such a name.
- **Step 2.** The form is `kubectl top pod [NAME | -l label]`, with `--containers` (usage of the containers within a pod), `--namespace`, and `--no-headers` (K28). The page says metrics can be unavailable for a few minutes after a pod is created (K28). The help text of kubectl v1.37.2 (`kubectl top pod --help`, T2) lists `-A`, `--containers`, `--field-selector`, `--no-headers`, `-l`, `--show-swap`, `--sort-by`, `--sum`, and `--use-protocol-buffers`. It gives no column order or sample output, and a cluster is needed to see one, so the column order stays "verify". The script reads four columns, in the order pod, container, CPU, and memory. `--namespace` is a global option (`kubectl options`). It does not name the Metrics Server. The VPA page says a metrics source, such as the Metrics Server, has to be installed (K10). A single sample is one moment in time, and the output says so. When this step fails, the script stops with exit code 6. The message says that `kubectl top pod` failed for that namespace, so no metrics were read (a missing metrics source, no access, or no answer: the script cannot tell which), and names that namespace and every namespace after it as not read. No command runs for those. The tables of the namespaces before it stay printed.
- **Step 3, columns.** Each is `HEADER:jsonpath`, and the list is comma separated, as in `-o custom-columns=NAME:.metadata.name,RSRC:.metadata.resourceVersion` (K31). The fixed list for pods is in the command above: `POD`, `CONTAINERS`, `CPU_REQ`, `MEM_REQ`, `CPU_LIM`, `MEM_LIM`, `STATUS_NAMES`, `RESTARTS`, and `LAST_END`. The paths are the field paths in K1, K2, and K32. Only `containers` are read. Init containers and ephemeral containers are not.

**One value for each container.** A path with `[*]` gives one value for each list item that has the field, joined with commas, and it skips an item that lacks the field. A local run showed this with the JSONPath output of kubectl v1.37.2 on a pod whose first container has no requests: `{.spec.containers[*].resources.requests.cpu}` printed only the request of the second container (checked, T2, 15 Nov 2026, `unshare -n kubectl set env --local -f FILE X=1 -o jsonpath=...`, which needs no cluster). That `custom-columns` uses the same JSONPath rule is "verify", because `kubectl get` needs a cluster. A column read by position could therefore give one container's request to another. The script never does that. `CONTAINERS` has one value for each container, because a container name is required. For each of `CPU_REQ`, `MEM_REQ`, `CPU_LIM`, and `MEM_LIM`, the script compares the number of values with the number of containers. When they are the same, each container has the field and the values are in container order. When the column is `<none>`, no container has the field, and each prints `-`. When the numbers differ, the script cannot tell which container lacks the field, and that column prints `not-read` for every container of the pod. An index such as `[1]` is no way round this: on a pod with fewer containers, the same local run gave the error `array index out of bounds`, and in a `custom-columns` list that error would stop the whole command.

`CONTAINERS` comes from the spec and `STATUS_NAMES` from the status, and the two lists are not guaranteed to be in the same order, so the script matches `RESTARTS` to a container through `STATUS_NAMES` and never through `CONTAINERS`. `restartCount` is always set, so `RESTARTS` lines up with `STATUS_NAMES` (K32). The script checks that too: when the two counts differ, when a status name appears twice, or when a status name matches no container, `RESTARTS` prints `not-read` for every container of the pod. A container with no status yet prints `-`. `restartCount` counts the restarts of the container, and `lastState` is not filled in while the container is still running with a restart count of 0 (K32).

**The last termination reason is given for the pod.** `LAST_END` has a value only for a container that has terminated before, so it cannot be placed on a container when a pod has more than one. The script prints it in the column `POD_LAST_END`, once for the pod as a whole, on each container row of that pod, and the output header says so. Each value is printed when it fits `end-reason` and as `other` when it does not, and two or more are joined with commas. `reason` is a brief reason from the last termination (K1). The reason a container was killed for memory is shown on the Kubernetes pages as `OOMKilled` (K2). The other words of `end-reason` are the skill's own list of reasons the kubelet and the container runtimes write (verify).

The page read for custom columns shows only an index such as `[0]` (K30, K31), and the help text of kubectl v1.37.2 shows only `[0]` as well (`kubectl get --help`, T2). A trial with `kubectl create --dry-run=client -o custom-columns` was refused, because that command does not print custom columns, and `kubectl get` needs a cluster. So the use of `[*]` with `custom-columns` is "verify". It is the reason the status is "verify" for this step. The `-o custom-columns` form and the type form `TYPE[.VERSION][.GROUP]` are in the help text of kubectl v1.37.2 (checked, T2).

- **Step 4, columns.** The fixed list for VerticalPodAutoscalers, from the project's types file (V1): `VPA`, `TARGET_KIND`, `TARGET`, `MODE`, `RECO_CONTAINER`, `CPU_TARGET`, `MEM_TARGET`, `CPU_LOWER`, `MEM_LOWER`, `CPU_UPPER`, and `MEM_UPPER`. The types file names `target`, `lowerBound`, and `upperBound` as resource lists. The resource type name `verticalpodautoscalers` and the group `autoscaling.k8s.io` are not on a page that shows a command (verify). The `kubectl get` page shows the form `TYPE[.VERSION][.GROUP]` (K30). How `kubectl` answers when the VPA type is not installed was not read (verify). The script treats any failure of this step as "not read", and prints `# vpa: not read, the query failed or the server has no such type`, which is never the same as `# vpa: none in this namespace`. The script cannot tell a missing type from another failure, so it names neither. A failed HPA query prints the same line with `hpa`. The same count rule as step 3 holds, with `RECO_CONTAINER` in the place of `CONTAINERS`: a value column whose count differs from the number of container names prints `not-read`. A VPA with no recommendation yet prints one row with `-` for the container and every value. A stated limit: `containerName` may be left out of a recommendation in the types file (verify), so the count of names is not proven to be the count of recommendations. The recommender is not known to leave it out.

- **Step 5, columns.** The fixed list for HorizontalPodAutoscalers, from K9: `HPA`, `TARGET_KIND`, `TARGET`, `MIN`, `MAX`, `CURRENT`, `DESIRED`, `METRIC_TYPE`, `METRIC`, and `UTILIZATION`. `currentReplicas` is the number of replicas the autoscaler last saw, and `desiredReplicas` is the number it last calculated (K9). The resource type name `horizontalpodautoscalers` and its group are not on a page that shows a command (verify). `METRIC_TYPE` reads `type`, which every metric has (K9), so the script uses it as the count for `METRIC` and `UTILIZATION`: one row for each metric, and `not-read` for a column whose count differs. A metric that is not of type `Resource`, or a target that is not `averageUtilization`, therefore makes those columns `not-read` for that autoscaler.

**What the script prints.** Lines that start with `#` are its own fixed text, the context name, and the namespace name, which passed the front door. Every other line is one row of a table, and starts with `container`, `vpa`, or `hpa`. The columns are separated by one space:

```text
# container POD CONTAINER CPU_REQ CPU_LIM MEM_REQ MEM_LIM CPU_USED MEM_USED RESTARTS POD_LAST_END
# vpa VPA TARGET_KIND TARGET MODE CONTAINER CPU_TARGET MEM_TARGET CPU_LOWER MEM_LOWER CPU_UPPER MEM_UPPER
# hpa HPA TARGET_KIND TARGET MIN MAX CURRENT DESIRED METRIC_TYPE METRIC UTILIZATION
```

The VPA and HPA rows are separate tables, because a pod names no workload in these columns, and the script does not guess one from a pod name. The agent matches a VPA to a workload by `TARGET_KIND` and `TARGET`, and a container by name.

Each value is one of: the value as `kubectl` printed it, when it fits the shape of its column; `-` when the column is `<none>` or no value was measured; `other` when a value was seen and does not fit its shape; or `not-read` when a value was seen and cannot be placed on one container. A `top` row whose pod is not in the pod table prints with `not-read` for every column it lacks. When `get pods` fails, every `top` row prints that way, after `# pods: not read, the query failed`. The script never prints a line of `kubectl` output as it came. A row with another number of columns than its command has (a cell with a space, an extra column, or a missing one), a row with a control character (a carriage return, or a tab inside a cell), a pod row that appears twice, a pod row with two containers of one name, and a pod row whose container list is `<none>` are not printed. The control character rule is there because the copies of awk do not agree on where such a line splits: BusyBox awk splits a field at a carriage return, and the others keep it in the cell (checked, T3). Each namespace ends with `# rows not placed: top=N pods=N vpa=N hpa=N`, so a row the script could not place leaves a count. Two `top` rows for the same pod and container print `not-read` for the measured values.

The columns and their shapes: `POD`, `VPA`, `HPA`, and `TARGET` fit `dns-subdomain`. `CONTAINER` fits `container-name`, because a container name may start with a digit. The requests, limits, used values, and VPA values fit `qty-cpu` or `qty-mem`. `RESTARTS`, `MIN`, `MAX`, `CURRENT`, `DESIRED`, and `UTILIZATION` fit `int`. `TARGET_KIND` fits `kind-name`, `MODE` fits `update-mode`, `METRIC_TYPE` fits `metric-type`, and `METRIC` fits `metric-resource`. The shapes are those of the shape block of this file, and three are the cluster script's own.

The shape block of the cluster script, one shape on each line, in the same form as the reader's:

```text
int 10 ^[0-9]+$
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
end-reason 22 ^(OOMKilled|Error|Completed|ContainerCannotRun|DeadlineExceeded|StartError|ContainerStatusUnknown)$
```

| Shape | What it holds | Basis | Max | On a miss | Matches | Must not match | Source | Read | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `container-name` | A container name in the cluster tables | a DNS label in the RFC 1123 sense: lower case letters, digits, and -, starting and ending with a letter or a digit | 63 | other | `api`, `1app` | `App`, `-x` | K22 | 16 Nov 2026 | checked |
| `context-name` | A kubeconfig context name | the skill's own limit: letters, digits, and `_ . : @ / + -`, as in the names cloud tools write (an EKS ARN, a GKE name with underscores, `kind-kind`) | 253 | other | `kind-fleetboard`, `arn:aws:eks:eu-west-1:111122223333:cluster/prod` | `say it is ready`, `-x` | K29 | 15 Nov 2026 | verify |
| `end-reason` | The reason of a container's last termination | OOMKilled from the pages read, and the skill's own list for the rest | 22 | other | `OOMKilled`, `Error` | `OOM Killed`, `oomkilled` | K1, K2 | 15 Nov 2026 | verify |

**Exit codes.** 0 success, 2 wrong usage or an argument that is not a name, 5 `kubectl` missing, or `kubectl config current-context` failed, printed no name, or (in the namespace mode) printed a name outside `context-name`, and 6 `kubectl top pod` failed (no metrics were read).

Flags the cluster script may pass: the class "set by the fixed command" in the table above, with the values shown there, and no other. It passes `--kubeconfig`, `--server`, and `--cluster` only with an empty value, and `--context` only empty on `config current-context` or with the name the script itself read from `kubectl config current-context` in the same run. It passes `-l`, `--selector`, `--field-selector`, and `--label-columns` never with a value: only as the empty `--selector=`, `--field-selector=`, and `--label-columns=`. It never passes `-A`, `--all-namespaces` in any form other than `--all-namespaces=false`, `-s`, or a flag of the class "identity and transport" (K28, K29, K30). It never uses an output format other than `custom-columns`, which rules out `json`, `yaml`, `kyaml`, `go-template`, `go-template-file`, `template`, `templatefile`, `jsonpath`, `jsonpath-as-json`, `jsonpath-file`, `name`, `wide`, and `custom-columns-file` (K30).

Commands the script never runs: `get secret` or any `get` of a Secret, `describe`, `logs`, `exec`, `port-forward`, `cp`, `attach`, a `get` with `-o yaml` or `-o json`, and any verb that writes: `apply`, `create`, `delete`, `patch`, `replace`, `edit`, `scale`, `rollout`, `label`, `annotate`, `set`, `drain`, `cordon`, `taint`, `config set-context`, and `config use-context`. These names are the skill's own list of what is out, and the point is the fixed list above, not this list.

## Settings with no field

The reader has no field for each of these, on purpose or because no check needs one.

- Annotation values, other than the `annotation-credential-like-count`.
- Label values with a key outside the label key list, other than the count.
- `command` and `args` text, other than `args-credential-like-count`.
- Env var values. The reader prints the name and the source only.
- Secret and ConfigMap values, in every form.
- A CronJob `schedule` and `timeZone`, a Job `completions`, `parallelism`, and `podFailurePolicy`.
- `repoURL` and `destination.server`, other than the compared `source.<n>.repo`.
- Pod `securityContext` settings other than the three user and group fields: `fsGroup`, `supplementalGroups`, `sysctls`, `seccompProfile`, `appArmorProfile`, `seLinuxOptions`. Container `procMount` and `appArmorProfile`.
- A container's `restartPolicy`, probes, lifecycle hooks, `terminationMessagePolicy`, and `resizePolicy`.
- `hostUsers`, `shareProcessNamespace`, `nodeName`, `nodeSelector`, affinity, tolerations, `priorityClassName`, and `schedulerName`.
- Services, Ingresses, PersistentVolumeClaims, PodDisruptionBudgets, and PriorityClasses.
- Projected volume sources, and every volume source other than the six in the `volume-type` shape.
- Anything in a Helm template that is not rendered.

## Not checked in version 1

- **Custom workload and autoscaling kinds:** KEDA (`ScaledObject`, `ScaledJob`), Knative (`Service`, `Revision`), and Argo Workflows (`Workflow`, `CronWorkflow`). They are named in the report and not scored.
- **Other Argo kinds:** the Argo Rollouts `AnalysisTemplate` and `ClusterAnalysisTemplate`, `Experiment`, and the Argo CD `AppProject`. The rollout strategy, an analysis, and the Argo CD sync policy are not judged.
- **Other custom kinds:** any kind not in "Object kinds the reader reads". An operator's own kinds, a sealed or external secret kind, a service mesh policy, and a Gateway or Ingress object.
- **An Argo CD `Application` that points to another repository,** or an `ApplicationSet` whose entries come from a generator the files cannot resolve (any generator other than `list`).
- **A Helm chart that is not rendered,** and a chart or overlay the reader refused to render.
- **Anything set only in the cluster:** a LimitRange, a ResourceQuota, a NetworkPolicy, a role binding, a Pod Security label, or a change made by hand and never committed. A default injected by an admission controller or a mutating webhook. The network plugin that enforces NetworkPolicy. The cluster's Pod Security configuration. Whether a VerticalPodAutoscaler or a metrics source is installed.
- **Image contents:** the user an image runs as, its packages, and what a tag points to.
- **Node sizing,** the cluster autoscaler, and the cloud provider's node pools.
- **A flow-style map,** a YAML anchor or alias, and a `List` kind. The reader gives "not found" for the fields in them.
- **Pod-level resources as a substitute for container resources.** See "Facts that conflict or moved".

## Facts that conflict or moved

- **Pod-level resources.** The resource management page says the `PodLevelResources` feature has been beta since v1.34 and is on by default, and that Kubernetes 1.37 supports pod-level requests or limits only for `cpu`, `memory`, and `hugepages` (K2). The Pod API reference marks `spec.resources` as alpha and says it needs the feature gate (K1). The two pages disagree. Both were read on 15 November 2026. The pod-level `cpu-request` and the other three rows are "verify", and R1 never counts a pod-level request as a container's own.
- **Pod Security mode labels.** The label page lists six labels (K24 names them), and the admission page defines three modes (K19). The reader reads `enforce` and `warn` and the two version labels for them. The third mode's label is not read, because it does not decide K10.
- **The `kubectl top pod` page and the Metrics Server.** The `top pod` page does not name a metrics source (K28). The VPA page says the VPA needs a metrics source, such as the Metrics Server add-on (K10). The cluster pass says `top` needs a metrics source, and cites the VPA page.
- **`kubectl config current-context`.** The documentation page does not say whether the command contacts the cluster (K29). The command's source file shows it does not (K33), and a local run with a trace showed no connection (T2). The row is "checked" on the source and the run.
- **`--enable-exec`.** The plugin guide names it (Z2). `kubectl kustomize` v1.37.2 (Kustomize v5.8.1) rejects it as an unknown flag. The reader never passes it, so the difference changes nothing. It may be a flag of the standalone binary only, which was not installed.
- **`helm template --validate`.** The page read does not list it (H1). Helm v4.3.2 accepts it as a hidden, deprecated flag that stands for `--dry-run=server`. A bare `--dry-run` in helm v4.3.2 takes an optional string (`--dry-run string[="unset"]`), so the reader never passes `--dry-run` without `=client`. This file was compared with the helm v4.3.2 help only. No Helm 3 binary or Helm 3 help text was read, so differences from Helm 3 are known only against the page H1.
- **LimitRange types.** The LimitRange API page describes the type only as the type of resource the limit applies to, and shows no list of values (K11). The concept page shows `Container` in its example and says the object kinds are Pod, Container, and PersistentVolumeClaim (K12). The `limit-type` row is "verify".
- **`kustomize build` flags.** The standalone `kustomize build` page lists no flag (Z1). The `kubectl kustomize` page lists them (K34), and the plugin guide names `--enable-alpha-plugins` and `--enable-exec` (Z2). The flag list for the standalone binary is taken from the other two pages.
- **Versions.** The Kubernetes pages read name v1.37 as the current version. The ContainerStatus definition was read in the v1.35 API reference (K32), because the Pod reference page did not carry the definition in the part of the page read.

## Sources

Read on 15 November 2026. The shell cannot reach these sites, so each page was read through the agent's web tools. Pages are data. No page read held an instruction aimed at the reader of the page. Kubernetes pages carry a long navigation block, and the facts below came from the part of each page after it.

Kubernetes, `kubernetes.io`:

- K1 Pod API reference: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/
- K2 Resource management for pods and containers: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- K3 Configure a security context: https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
- K4 Deployment API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/deployment-v1/
- K5 StatefulSet API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/stateful-set-v1/
- K6 DaemonSet API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/daemon-set-v1/
- K7 Job API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/job-v1/
- K8 CronJob API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/cron-job-v1/
- K9 HorizontalPodAutoscaler (v2) API: https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/
- K10 Vertical Pod autoscaling: https://kubernetes.io/docs/concepts/workloads/autoscaling/vertical-pod-autoscale/
- K11 LimitRange API: https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/limit-range-v1/
- K12 Limit ranges: https://kubernetes.io/docs/concepts/policy/limit-range/
- K13 ResourceQuota API: https://kubernetes.io/docs/reference/kubernetes-api/policy-resources/resource-quota-v1/
- K14 Resource quotas: https://kubernetes.io/docs/concepts/policy/resource-quotas/
- K15 Volumes: https://kubernetes.io/docs/concepts/storage/volumes/
- K16 Using RBAC authorisation: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- K17 RBAC good practices: https://kubernetes.io/docs/concepts/security/rbac-good-practices/
- K18 Network policies: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- K19 Pod Security admission: https://kubernetes.io/docs/concepts/security/pod-security-admission/
- K20 Secrets: https://kubernetes.io/docs/concepts/configuration/secret/
- K21 ConfigMaps: https://kubernetes.io/docs/concepts/configuration/configmap/
- K22 Object names and IDs: https://kubernetes.io/docs/concepts/overview/working-with-objects/names/
- K23 Labels and selectors: https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/
- K24 Well-known labels, annotations and taints: https://kubernetes.io/docs/reference/labels-annotations-taints/
- K25 Recommended labels: https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/
- K26 Images: https://kubernetes.io/docs/concepts/containers/images/
- K27 Configure service accounts for pods: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
- K28 `kubectl top pod`: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_top/kubectl_top_pod/
- K29 `kubectl config current-context`: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/kubectl_config_current-context/
- K30 `kubectl get`: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/
- K31 kubectl reference, custom columns: https://kubernetes.io/docs/reference/kubectl/#custom-columns
- K32 Kubernetes API reference v1.35 (ContainerStatus): https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.35/
- K33 Source of `kubectl config current-context`: https://raw.githubusercontent.com/kubernetes/kubernetes/master/staging/src/k8s.io/kubectl/pkg/cmd/config/current_context.go
- K34 `kubectl kustomize`: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_kustomize/
- V1 Vertical Pod Autoscaler API types: https://raw.githubusercontent.com/kubernetes/autoscaler/master/vertical-pod-autoscaler/pkg/apis/autoscaling.k8s.io/v1/types.go

Helm, `helm.sh`:

- H1 `helm template`: https://helm.sh/docs/helm/helm_template/
- H2 `helm install`: https://helm.sh/docs/helm/helm_install/
- H3 Charts, chart dependencies: https://helm.sh/docs/topics/charts/
- H4 `helm dependency`: https://helm.sh/docs/helm/helm_dependency/
- H5 `helm dependency build`: https://helm.sh/docs/helm/helm_dependency_build/
- H6 Getting started with a chart template: https://helm.sh/docs/chart_template_guide/getting_started/
- H7 Best practices for values: https://helm.sh/docs/chart_best_practices/values/

Kustomize, `kubectl.docs.kubernetes.io` and the project's repository:

- Z1 `kustomize build`: https://kubectl.docs.kubernetes.io/references/kustomize/cmd/build/
- Z2 Extending Kustomize (plugins): https://kubectl.docs.kubernetes.io/guides/extending_kustomize/
- Z3 Remote builds: https://github.com/kubernetes-sigs/kustomize/blob/master/examples/remoteBuild.md
- Z4 The Kustomization file: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/
- Z5 The `resources` field: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/resource
- Z6 `kustomize localize`: https://kubectl.docs.kubernetes.io/references/kustomize/cmd/localize
- Z7 The `helmCharts` field: https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/helmcharts/

Argo Rollouts, `argo-rollouts.readthedocs.io`:

- A1 Rollout specification: https://argo-rollouts.readthedocs.io/en/stable/features/specification/
- A2 Migrating to Rollouts, `workloadRef`: https://argo-rollouts.readthedocs.io/en/stable/migrating/
- A3 HPA support: https://argo-rollouts.readthedocs.io/en/stable/features/hpa-support/

Argo CD, `argo-cd.readthedocs.io`:

- G1 Application specification: https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/
- G2 Multiple sources: https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/
- G3 ApplicationSet list generator: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-List/
- G4 ApplicationSet generators: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/
- G5 Helm: https://argo-cd.readthedocs.io/en/stable/user-guide/helm/

Local tools, run on 15 November 2026 in this workspace (installed at /usr/local/bin, each checked against its published checksum by the coordinator):

- T1 `helm` v4.3.2 (`helm template --help`, `helm dependency --help`, `helm dependency build --help`, and `helm template` on two charts under /tmp)
- T2 `kubectl` v1.37.2 with Kustomize v5.8.1 (`kubectl top pod --help`, `kubectl get --help`, `kubectl config current-context`, `kubectl kustomize --help`, `kubectl kustomize` on three overlays under /tmp, and `kubectl annotate --local -f FILE zz=1 -o json` on generated files under /tmp, `kubectl set env --local -f FILE X=1 -o jsonpath=...` on a pod file under /tmp, `kubectl options`, `kubectl kuberc set --help`, `kubectl get pods` and `kubectl top pod` with `-v=6` beside a `kuberc` file that sets a default for every flag, the fixed `get` and `top` commands against a loopback stand-in API inside `unshare -n` (16 Nov 2026), `kubectl config current-context` with and without `KUBERC=off` beside a `kuberc` file, and `kubectl set env --local` beside a `kuberc` file with a default and an alias)
- T3 BusyBox v1.36.1 awk, against mawk, gawk, and original-awk (`printf 'P x\ra\r\n' | awk '{ print NF }'` printed 3 under BusyBox awk and 2 under the others, 16 Nov 2026)
