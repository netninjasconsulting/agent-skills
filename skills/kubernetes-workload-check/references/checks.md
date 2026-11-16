# The eighteen checks: evidence rules

For each check: the fields that decide it, what earns each status, and when it does not apply. Every field name below is a field of [fields.md](fields.md), spelt as the reader prints it. A Kubernetes fact carries the source mark that `fields.md` gives it (K1, K3, and so on). A fact that `fields.md` does not hold, and that was not read in Kubernetes' own documentation on the build date, is marked "verify", and no rule below treats it as certain.

The status table, the verdict table, and the order of the first three are in [SKILL.md](../SKILL.md). The rules below take precedence over the summary table there.

## Contents

1. [Rules that hold for every check](#rules-that-hold-for-every-check)
2. [Sizing](#sizing)
3. [Security](#security)
4. [Known limits](#known-limits)
5. [The cluster pass and R8](#the-cluster-pass-and-r8)
6. [The first three to change](#the-first-three-to-change)

## Rules that hold for every check

### What the reader shows

A field line reads `<file>:<line>:<object kind>/<namespace>/<name>:<container or ->:<field>=<value>`. For each field of each workload, the reader's output is in one of five states:

- **Printed.** A line with a value. This is evidence.
- **`other`.** The key is present and the reader could not read its value, or the value failed its shape. `other` is never the Kubernetes default and never a value. Kubernetes may still read the setting as set (`hostNetwork: yes` is true to the API server, see `fields.md`).
- **Not read.** The reader could not read the file as a whole (exit code 4, or the state `not read`). Every field of every object in that file is unknown.
- **Not rendered.** A chart that was not rendered, or a chart or overlay the reader refused to render. The fields of its templates are unknown. Its values files are still read with `--values`.
- **Absent.** No line for the field, for an object the reader printed in a file it read whole (exit code 0) or in a render that succeeded. The key is not in the object.

`other`, not read, and not rendered are "not found". A field that is not found can neither pass nor fail a check: the workload's part is "ask the team" at best, it can never pass, and the field goes under "Not checked" with its file and line (or the file alone, when it was not read). A fail found elsewhere in the same check still fails.

### Absent fields: the named exceptions to the "not found" rule

An absent field is "not found" too, with the exceptions in this table. Each exception holds only for an object the reader printed in a file it read whole or in a render that succeeded. For these fields an absent line means that the setting is not made in the repository. The check then states what that earns: a check that needs a setting to be made is not met by an absent key, and a check that needs a setting not to be made is met by one.

| Check | Absent field | Read as | Source |
| --- | --- | --- | --- |
| R1 | `cpu-request`, `memory-request` on a container | No request set | not applicable |
| R2 | `memory-limit` on a container | No limit set | not applicable |
| R4 | `cpu-request`, `memory-request` on a container of an autoscaler's target | No request for the target to measure against | K9 |
| R5 | No `LimitRange` and no `ResourceQuota` object for a namespace in the environment | No default and no ceiling set | not applicable |
| R6 | `emptydir-size-limit` on an `emptyDir` volume | No size limit set | not applicable |
| R7 | `active-deadline-seconds` and `pod-active-deadline-seconds` | No deadline set | K7 |
| R7 | `concurrency-policy` on a CronJob | `Allow`, the default | K8 |
| K1 | `privileged` at the container | Not privileged (defaults to false) | K1 |
| K2 | `allow-privilege-escalation` | Escalation not blocked (defaults to true) | K3 |
| K2 | `cap-drop` | Nothing dropped | K1 |
| K3 | `read-only-root-fs` | Root filesystem writable (defaults to false) | K1 |
| K4 | `host-network`, `host-pid`, `host-ipc`, `host-port`, and a `volume-type=hostPath` | Not requested | not applicable |
| K5 | `service-account` | The `default` ServiceAccount of the namespace | K27 |
| K5 | `automount-sa-token` on the pod and on its ServiceAccount | Token mounting not turned off | not applicable |
| K6 | No Role, ClusterRole, RoleBinding, or ClusterRoleBinding in the environment | Nothing to judge | not applicable |
| K7 | No Secret object, and none of the K7 cases | No secret written in the repository | not applicable |
| K8 | No NetworkPolicy that selects a workload's pods | The workload is not isolated, so all traffic is allowed | K18 |
| K10 | `psa-enforce` on a Namespace object in the environment | No level enforced | K19 |

Every other absent field is "not found". The main one is `run-as-user`: when it is absent at both levels, the user in the image decides, and the reader cannot see the image (K1). An absent field never counts as absent in an object the reader did not print, in a file that was not read, or in a template that was not rendered.

### Facts marked "verify"

A fact marked "verify" here or in `fields.md` never makes a pass and never makes a fail. The part it would decide is a warn at most, or "ask the team", as the rule says, and the evidence says "verify".

### Environments and workloads

- **Statuses are given for each environment.** An environment is what step 1 of the workflow names: an Argo CD `Application` (or an entry an `ApplicationSet` builds from a `list`), else a Kustomize overlay or a values file beside a chart, else the plain manifests. The objects of an environment are those in its files, or in its rendered output.
- **The workloads.** Deployment, StatefulSet, DaemonSet, Job, CronJob, a bare Pod, and a `Rollout`. A `Rollout` is judged as a Deployment, once.
- **A `Rollout` with `workloadRef`.** It prints `workload-ref-kind` and `workload-ref-name` and no pod template. Its pod template is the one of the Deployment it names, so the pair is one workload, judged once on the Deployment's fields, and the evidence names both (A1, A2). The Deployment is not judged a second time on its own. An autoscaler that targets the `Rollout` targets that pod template (A3). When the named Deployment is not in the environment, every pod template field of the pair is "not found".
- **An environment the files cannot resolve.** An `Application` with `source.<n>.repo=other`, and an `ApplicationSet` with a `generator.<i>=other`, name no environment that this check scores. They go under "Not checked". A K7 field on such an object (`source.<n>.url-has-user-part=true`, or a credential-like `values-key` line) goes under "Also found" with its file and line, and does not change a status.
- **The inline values of an `Application`.** A chart render takes values files only, so it leaves out `helm.values`, `helm.valuesObject`, and `helm.parameters` (see `fields.md`, command section 1). The agent reads their key names with `--fields` on the `Application`: `values-key.<path>` and `values.<path>` lines with the kind `Application`. Argo CD applies them after the values files (G5), so they can change what the render shows.
  - Every inline `values-key` path goes under "Not checked" for that environment, as a value the render left out.
  - When an inline path ends in a key of the values table of `fields.md` (`resources.requests.cpu`, `resources.limits.memory`, a `securityContext` flag, `capabilities.drop`, `image.tag`, `image.digest`, `replicaCount`, `minReplicas`, `maxReplicas`), the rendered field it would set is "Not checked" too, and the check that it decides is "ask the team" at best for that environment. This covers every sizing field set there.
  - For K7, an inline `values-key` line is judged like a line of a values file. See K7.
  - `source.<n>.helm-values=other` means the block was not read. Every check is then "ask the team" at best for the fields a values key could set, and K7 is "ask the team" at best.
- **A chart that was not rendered.** Every field of its templates is "not found". The checks that judge its workloads are "ask the team" at best, and the report says that the chart was not rendered. Its values files are still read with `--values`: K7 judges their credential-like keys, and the `values.<path>` lines (requests, limits, flags, the `image.tag` and `image.digest` pin words) are named in the evidence as what the values set, not as what the pod gets.
- **A namespace.** The namespaces of an environment are the `<namespace>` of each of its workloads. An object with the namespace `-` takes `destination-namespace` from its `Application`, or the `--namespace` given to the chart render. A workload whose namespace is still `-` has an unknown namespace, and R5, K8, and K10 are "ask the team" at best for it.

### How the statuses combine

- **Judge each workload, then each check.** Each workload's part of a check gets a status. The check gets the weakest: fail, then warn, then "ask the team", then pass. One workload that fails and one that passes give a fail. The evidence names the workload as `<kind>/<namespace>/<name>`, and the container where the field is a container field, with the field line that decided it.
- **Checks on objects that are not workloads.** R5 and K10 judge each namespace, K6 each role and binding, and R4 each autoscaler. The same weakest rule holds.
- **"Does not apply"** is for an environment that holds nothing the check judges, as each rule says. A part that does not apply leaves the comparison.
- **"Ask the team" is never a softer fail.** It needs the part that the repository can show to be met. When a setting that would be in the repository is missing, the status is warn or fail, and no question is asked.
- **A team's answer never changes a status.** The answers appear in their own block, labelled "stated by the team".
- **The file is not the cluster.** Every status says what the repository shows. A LimitRange, a policy, or a label set only in the cluster is never assumed, in either direction.
- **No size and no figure.** The evidence says whether a setting is explicit and where. It never says what the value should be, and it gives no saving and no cost. R3 compares two printed values and reports only which side of its line the pair falls on.

### The questions for the team

A check marked "ask the team" in an environment carries one yes or no question, however many workloads it covers. Each rule below gives its question. Name in it every workload, namespace, or role that the check's "ask the team" covers. When a check is "ask the team" because a field is "not found", the question names that field at its file and line: "Does the <field> at <file:line> meet <check>?" One answer covers the whole check.

## Sizing

### R1. Every container sets a CPU request and a memory request, init containers and sidecars included.

- **Fields:** `container-kind`, `cpu-request`, `memory-request` on every container of every workload, `main` and `init` alike. Context: `limit-default-request.cpu` and `limit-default-request.memory` on a LimitRange in the same namespace of the environment.
- **Not counted:** a pod-level `cpu-request` or `memory-request` (`<container>` is `-`). Its feature status is unsettled (see "Facts that conflict or moved" in `fields.md`), and it is not a container's own request.
- **Pass:** every container prints both `cpu-request` and `memory-request`.
- **Warn:** a container lacks a request, and a LimitRange in its namespace in the environment prints the matching `limit-default-request`. The request is filled in at admission (K12), and it was not chosen for that container. Name the LimitRange.
- **Fail:** a container lacks a request, and no LimitRange in the environment fills it.
- **Ask the team:** a request is `other`, or the workload is in a file that was not read or a chart that was not rendered.
- **Question:** "Does <container> of <workload> get a CPU request and a memory request from somewhere the repository does not show?"

### R2. Every container sets a memory limit.

- **Fields:** `memory-limit` on every container. Context: `limit-default.memory`, `limit-max.memory`.
- **Pass:** every container prints `memory-limit`.
- **Warn:** a container lacks a memory limit, and a LimitRange in its namespace in the environment prints `limit-default.memory` (K12).
- **Fail:** a container lacks a memory limit, and no LimitRange in the environment fills it.
- **Ask the team:** `memory-limit` is `other`, or the workload is not read or not rendered.
- **Question:** "Does <container> of <workload> get a memory limit from somewhere the repository does not show?"

### R3. Each memory limit sits close to its request.

- **Fields:** `memory-request` and `memory-limit` of the same container. Context: `limit-max-ratio.memory`.
- **The line:** close means at most twice the request. Twice is this skill's own line, not a Kubernetes rule, and the evidence says so. The agent compares the two printed quantities after reading their suffixes: `Ki`, `Mi`, `Gi`, `Ti`, `Pi`, and `Ei` are powers of 1024, `k`, `M`, `G`, `T`, `P`, and `E` are powers of 1000, and a lower case `m` means millibytes (K2). The evidence gives the two values and says which side of the line they fall on. It gives no new value.
- **Which containers:** a container that prints both values. A container that lacks either one is judged by R1 or R2, and its part of R3 does not apply.
- **Pass:** every such container has a limit of at most twice its request.
- **Warn:** a limit is more than twice its request, or below its request. A memory value with the suffix `m` is named in the evidence as millibytes.
- **Fail:** not used. This check's own call: a wide limit is a sizing gap, and the sizing checks do not block alone.
- **Ask the team:** either value is `other`.
- **Does not apply:** no container in the environment prints both values.
- **Question:** "Is the memory limit of <container> of <workload> at most twice its memory request, where the <field> at <file:line> is one of the two?"

### R4. Every autoscaler has what it needs to work.

- **Fields, HorizontalPodAutoscaler:** `scale-target-api-version`, `scale-target-kind`, `scale-target-name`, `min-replicas`, `max-replicas`, `metric-type`, `metric-resource`, `metric-target-type`, `metric-average-utilization`. `min-replicas` defaults to 1 (K9).
- **Fields, VerticalPodAutoscaler:** `scale-target-kind`, `scale-target-name`, `update-mode`.
- **Fields, the target:** the workload with that kind and name in the same namespace of the environment (`object=present`), and the `cpu-request` and `memory-request` of every container in its pod template. A `Rollout` is a valid target, and with `workloadRef` its pod template is the Deployment's (A1, A3).
- **Pass:** every autoscaler names a target that is in the environment; every HorizontalPodAutoscaler has `min-replicas` below `max-replicas`; and for every metric with `metric-type=Resource` and `metric-target-type=Utilization`, every container of the target prints a request for that `metric-resource`. A `Utilization` target is a percentage of the request (K9).
- **Warn:** `min-replicas` is equal to or above `max-replicas`, so the autoscaler cannot scale out; or a `Utilization` target on `cpu` or `memory` meets a container of the target with no request for it, and a LimitRange in its namespace in the environment prints the matching `limit-default-request`. The request is filled in at admission (K12), as in R1.
- **Fail:** an autoscaler names a target that is not in the environment; or a `Utilization` target on `cpu` or `memory` meets a container of the target with no request for it, and no LimitRange in the environment fills it.
- **Ask the team:** a metric of a type other than `Resource` (its source sits outside the repository); a deciding field is `other`; or the target is not read or not rendered.
- **Not checked, always:** whether a metrics source runs in the cluster, and whether the VerticalPodAutoscaler is installed (K10). They are listed under "Not checked" for each environment with an autoscaler, and they do not change the status.
- **Does not apply:** the environment holds no HorizontalPodAutoscaler and no VerticalPodAutoscaler.
- **Question:** "Does the source of the <metric-type> metric of <autoscaler> run in the cluster?"

### R5. Every namespace sets defaults or ceilings for CPU and memory.

- **Fields:** the namespaces of the environment (see "A namespace" above), Namespace objects (`object=present` with the kind `Namespace`), and on LimitRange and ResourceQuota objects in each namespace: `limit-default.*`, `limit-default-request.*`, `limit-max.*`, `limit-min.*`, `limit-max-ratio.*`, `quota-hard.requests.cpu`, `quota-hard.requests.memory`, `quota-hard.limits.cpu`, `quota-hard.limits.memory`, `quota-hard.cpu`, `quota-hard.memory`.
- **Pass:** every namespace has, in the environment, a LimitRange that prints a `limit-default`, `limit-default-request`, or `limit-max` value for `cpu` or `memory`, or a ResourceQuota that prints a `quota-hard` value for `cpu` or `memory`.
- **Warn:** a namespace's LimitRange and ResourceQuota objects set no default and no ceiling for CPU or memory (for example only `limit-min.*` or `quota-hard.pods`).
- **Also found:** two or more LimitRange objects in one namespace. Which default applies is then not deterministic (K12).
- **Fail:** the environment holds the namespace's Namespace object, and no LimitRange or ResourceQuota for that namespace.
- **Ask the team:** the environment holds no Namespace object for the namespace (it is made elsewhere, and its defaults can live with it), or the namespace is unknown, or a deciding field is `other`.
- **Question:** "Do the namespaces <list> get a LimitRange or a ResourceQuota for CPU and memory from somewhere the repository does not show?"

### R6. Scratch space has a ceiling.

- **Fields:** `volume-name`, `volume-type=emptyDir`, `emptydir-medium`, `emptydir-size-limit`, and on each container that mounts the volume, `mount.<volume-name>`. Context: `ephemeral-storage-limit`, and `quota-hard.*ephemeral-storage` in the namespace.
- **Memory against disk.** An `emptyDir` with `emptydir-medium=Memory` keeps its files in memory, and one with no medium keeps them on the node's disk. How a memory-backed volume counts against the container's memory limit, and what happens when a `sizeLimit` is exceeded, were not read (verify). This check's own call: a memory-backed volume with no size limit is a fail, because its files take memory that the request and limit were set for, and a disk-backed one with no size limit is a warn.
- **Pass:** every `emptyDir` volume prints `emptydir-size-limit`, whatever its medium.
- **Warn:** a disk-backed `emptyDir` (no `emptydir-medium` line) prints no `emptydir-size-limit`, and some container that mounts it prints no `ephemeral-storage-limit`.
- **Fail:** a memory-backed `emptyDir` (`emptydir-medium=Memory`) prints no `emptydir-size-limit`.
- **Ask the team:** a disk-backed `emptyDir` with no size limit, where every container that mounts it prints `ephemeral-storage-limit`. Whether that limit bounds the volume was not read (verify). Also when `emptydir-medium`, `emptydir-size-limit`, or `volume-type` of a volume is `other`.
- **Not scratch:** a `hostPath` volume is judged by K4. A `volume-type=other` is a source the reader does not read, and it goes under "Not checked".
- **Does not apply:** the environment holds no `emptyDir` volume.
- **Question:** "Does the ephemeral storage limit of <containers> bound the scratch volume <volume> of <workload>?"

### R7. Batch work has a deadline, and scheduled runs do not pile up.

- **Fields:** on each Job and CronJob: `active-deadline-seconds`, and `pod-active-deadline-seconds` on its pod template. On each CronJob: `concurrency-policy` (defaults to `Allow`, K8). Context: `backoff-limit`, `ttl-seconds-after-finished`, `starting-deadline-seconds`, `history-limit-successful`, `history-limit-failed`.
- **Pass:** every Job and CronJob prints `active-deadline-seconds` or `pod-active-deadline-seconds`, and every CronJob prints `concurrency-policy=Forbid` or `concurrency-policy=Replace`.
- **Warn:** every Job and CronJob has a deadline, and a CronJob leaves `concurrency-policy` absent or at `Allow`, so a slow run and the next one can run at once.
- **Fail:** a Job or CronJob has no deadline at either level. Its retries stop at `backoff-limit` (6 by default, K7). Whether anything else ends a run that hangs was not read (verify).
- **Ask the team:** a deadline field or `concurrency-policy` is `other`.
- **Does not apply:** the environment holds no Job and no CronJob. A Deployment that does batch work has no field to say so (see `fields.md`).
- **Question:** "Does the <field> at <file:line> give <workload> a deadline, and keep its scheduled runs from overlapping?"

### R8. Requests match measured use.

- **Fields:** none in the repository. The requests (`cpu-request`, `memory-request`) are the repository's side of the comparison.
- **Pass, warn, and fail:** never from the repository.
- **Ask the team:** R1 is pass, warn, or "ask the team". The cluster pass is how it is answered. See [The cluster pass and R8](#the-cluster-pass-and-r8).
- **Does not apply:** R1 is a fail. A request that is not set has nothing to match.
- **Question:** none of its own. R8 is answered by the cluster offer, not by the questions for the team.

## Security

### K1. No container runs as root or privileged.

- **Fields:** `privileged` on each container; `run-as-user`, `run-as-non-root`, and `run-as-group` at the container and at the pod (`<container>` is `-`); `container-kind`.
- **The level that applies.** A container-level setting overrides the pod-level setting of the same name (K1, K3). For each container, use the container's `run-as-user` when it prints one, and the pod's otherwise. The same holds for `run-as-non-root` and `run-as-group`.
- **Pass:** every container has `privileged` absent or `false`, and a `run-as-user` above 0 at the level that applies.
- **Warn:** every container passes on the user, and a `run-as-group=0` applies to one, so its files belong to the root group.
- **Fail:** a container prints `privileged=true`, or `run-as-user=0` applies to it.
- **Ask the team:** no `run-as-user` applies to a container (the user in the image decides, K1). This holds with `run-as-non-root=true` as well: how the kubelet checks the image's user was not read (verify). Also when `privileged` or a `run-as-user` that applies is `other`, or the workload is not read or not rendered. Such a part can never pass.
- **Question:** "Do the images of <containers> run as a user other than root?"

### K2. Every container drops all capabilities and blocks privilege escalation.

- **Fields:** `cap-drop`, `cap-add`, `allow-privilege-escalation`, and `privileged`, on each container.
- **Privileged with escalation set to false.** Escalation is always allowed for a container that is privileged or holds `CAP_SYS_ADMIN`, whatever `allowPrivilegeEscalation` says (K1). So a container with `privileged=true` fails K2, even with `allow-privilege-escalation=false` and `cap-drop=ALL`, and the evidence names all three lines. K1 fails for the same container. Whether the API server takes that pair at all was not read (verify), and it does not change the status.
- **Pass:** every container prints `cap-drop=ALL` and `allow-privilege-escalation=false`, prints no `cap-add`, and is not privileged.
- **Warn:** a container leaves `allow-privilege-escalation` absent (it defaults to true, K3), prints no `cap-drop=ALL` (the runtime's default set stays, K1), or adds a capability other than `SYS_ADMIN`.
- **Fail:** a container prints `privileged=true`, `allow-privilege-escalation=true`, or `cap-add=SYS_ADMIN` (or `CAP_SYS_ADMIN`).
- **Ask the team:** a deciding field is `other`, or the workload is not read or not rendered.
- **Question:** "Do <containers> drop all capabilities and block escalation in a setting the repository does not show?"

### K3. Every container's root filesystem is read-only.

- **Fields:** `read-only-root-fs` on each container. Context: `mount.<volume-name>`, `volume-type`, `emptydir-size-limit`, for where the program can still write.
- **Pass:** every container prints `read-only-root-fs=true`.
- **Warn:** a container prints `read-only-root-fs=false`, or leaves it absent (it defaults to false, K1).
- **Fail:** not used. This check's own call: a writable root filesystem is a hardening gap, and K1, K2, and K4 judge the settings that reach the node.
- **Ask the team:** `read-only-root-fs` is `other`, or the workload is not read or not rendered.
- **Question:** "Is the root filesystem of <containers> made read-only in a setting the repository does not show?"

### K4. No pod shares the host's network, processes, or files.

- **Fields:** `host-network`, `host-pid`, `host-ipc` on the pod; `volume-type=hostPath`, `host-path`, and `mount.<volume-name>` for each mount of that volume; `host-port` on each container.
- **Pass:** no workload prints `host-network=true`, `host-pid=true`, `host-ipc=true`, a `volume-type=hostPath`, or a `host-port`.
- **Warn:** a `host-port`.
- **Fail:** a pod prints `host-network=true`, `host-pid=true`, or `host-ipc=true`; or it has a `hostPath` volume, read-only or not. A read-only mount narrows what the pod can change on the node and still shares the node's files (K15). The evidence names each `mount.<volume-name>` line.
- **Ask the team:** `host-network`, `host-pid`, `host-ipc`, or `host-port` is `other`, or the workload is not read or not rendered. A `volume-type=other` is not a `hostPath`, because `hostPath` is one of the source keys the reader reads; it goes under "Not checked".
- **Not checked, always:** `hostUsers` and `procMount` have no field.
- **Question:** "Does <workload> leave the host's network, processes, and files alone in a setting the repository does not show?"

### K5. Each workload has its own ServiceAccount, and mounts a token only when it calls the API.

- **Fields:** `service-account` and `automount-sa-token` on the pod; `automount-sa-token` on the ServiceAccount object of that name in the environment. Context: `subject.<n>.kind`, `subject.<n>.name`, `subject.<n>.namespace`, `role-ref-kind`, `role-ref-name` on the bindings that name the account.
- **The account.** A pod with no `service-account` line, or `service-account=default`, runs as the `default` ServiceAccount of its namespace (K27). Two workloads share an account when they name the same `service-account` in the same namespace. A `Rollout` with `workloadRef` and its Deployment are one workload.
- **The token.** When both the pod and the ServiceAccount set `automountServiceAccountToken`, the pod wins (K27). The token is off when the setting that applies prints `false`. When neither sets it, the token is mounted (verify: the page implies it and does not state it).
- **Pass:** every workload has an account of its own, not `default`, and its token is off.
- **Warn:** a workload runs as `default` with its token off or not set; or two workloads share an account.
- **Fail:** a workload runs as `default` and `automount-sa-token=true` applies to it.
- **Ask the team:** every workload has an account of its own, and a workload's token is on (`true` applies) or not set. Whether it calls the Kubernetes API has no field (see `fields.md`). Also when `service-account` or an `automount-sa-token` that applies is `other`.
- **Question:** "Do <workloads> call the Kubernetes API?"

### K6. RBAC rules name their verbs and their resources.

- **Fields:** on each Role and ClusterRole in the environment: `rule.<n>.verb`, `rule.<n>.resource`, `rule.<n>.api-group`, `rule.<n>.resource-names-count`, `rule.<n>.non-resource-urls-count`, `aggregation-rule`. On each RoleBinding and ClusterRoleBinding: `role-ref-kind`, `role-ref-name`, `subject.<n>.kind`, `subject.<n>.name`, `subject.<n>.namespace`, `subject.<n>.user-form`.
- **Pass:** every rule names its verbs and its resources with no `*`, and no rule carries a warn below.
- **Warn:** a binding prints `role-ref-kind=ClusterRole` with `role-ref-name=admin` or `role-ref-name=edit`; a rule names `*` in `rule.<n>.api-group` with named verbs and resources; grants `get`, `list`, or `watch` on `secrets` with no `resource-names-count` (each of the three reveals Secret contents, K17); grants `create` on `pods` or a workload resource (it grants the access of every ServiceAccount in the namespace, K17); or prints `rule.<n>.non-resource-urls-count`.
- **Fail:** a rule prints `rule.<n>.verb=*` or `rule.<n>.resource=*` (a wildcard also covers kinds created later, K17), or the verb `escalate`, `bind`, or `impersonate` (each lets a holder reach rights it was not given, K17); or a RoleBinding or ClusterRoleBinding prints `role-ref-kind=ClusterRole` with `role-ref-name=cluster-admin`.
- **The `cluster-admin` binding.** A binding to `cluster-admin` fails K6 when any subject reaches a workload: a ServiceAccount (`subject.<n>.kind=ServiceAccount`, the `default` account included), a `User` in the service-account form (`subject.<n>.user-form=service-account`), or a group (`subject.<n>.kind=Group`). Kubernetes authenticates a ServiceAccount as the user `system:serviceaccount:<namespace>:<name>`, and RBAC matches a `User` subject by that name (verify). The reader prints no group name, so every group counts.
- **The subject rule.** Wherever K6 or the reach map looks at the subjects of a binding, a subject that reaches a workload is one of the three above. A `User` with `user-form=plain` is a person or a system user, not a workload, and is not a K6 case. A `User` with `user-form=other` is "ask the team". The rule holds for the `cluster-admin` fail, for the `admin` and `edit` warn, and for a binding to a role in the repository. A Role or ClusterRole defined in the repository is judged on its own rules, whatever binds it.
- **Built-in roles.** A binding may name a ClusterRole that the cluster carries and the repository does not. This check judges three of them by name: `cluster-admin` grants every action on every resource, and `admin` and `edit` grant wide write access within a namespace (verify: these built-in roles are not in `fields.md`).
- **Ask the team:** a binding to `cluster-admin`, `admin`, or `edit` whose only subject that could reach a workload is a `User` with `user-form=other`; a ClusterRole prints `aggregation-rule=present` (its rules are filled in by a controller in the cluster, K16); a binding names a `role-ref-name` that is not in the environment and is not one of the three built-in roles above; or a rule field is `other`.
- **Does not apply:** the environment holds no Role, ClusterRole, RoleBinding, or ClusterRoleBinding.
- **Question:** "Do the roles <list>, named by bindings in the repository and defined outside it, name their verbs and resources with no wildcard?"

### K7. Secrets stay out of manifests and values files.

- **Fields:** see each case. The reader never prints a Secret value, a ConfigMap value, an env value, an argument, an annotation value, or a values-file value. K7 is decided from key names, sources, states, marks, and counts.
- **Which files:** the files of the environment and their rendered output, the values files the environment uses (the chart's own `values.yaml` and each `valueFiles` entry), and the inline values of its `Application`.
- **Two lists of names.** Both are this skill's own lines, not a Kubernetes rule.
  - **The words of a name.** Split the name at `_`, `-`, and `.`, and before a capital letter that follows a lower case letter or a digit, then make each word lower case. `MAP_TILES_API_KEY` gives `map tiles api key`, and `automountServiceAccountToken` gives `automount service account token`. For a values path, the name is its last key: `smtp.password` is judged as `password`.
  - **The fail list.** A name whose last word is `password`, `passwd`, `pass`, `pwd`, `pw`, `passphrase`, `secret`, `token`, `apikey`, `privatekey`, `accesskey`, `secretkey`, `credential`, or `credentials`; or whose last two words are `api key`, `private key`, `access key`, or `secret key`; or that is a single word ending in `password` or `passwd` (`PGPASSWORD`). These names are never on it: `existingSecret`, `secretName`, `secretRef`, `secretKeyRef`, `automountServiceAccountToken`, any name whose word before the last is `existing`, and these exact whole names, in any case: `PWD` (a working directory), `OLDPWD`, and `NOPASSWD`. They stay on the ask list where the reader's wide list marks them. So `DB_PASSWORD`, `smtp.password`, `MAP_TILES_API_KEY`, `partner-api-token`, `PGPASSWORD`, `RABBITMQ_DEFAULT_PASS`, `MYSQL_PWD`, `ADMIN_PW`, and `PASSPHRASE` are on the fail list, and `DB_PASSWORD_FILE`, `TOKEN_TTL`, `tls.secretName`, `existingSecret`, and `auth.enabled` are not.
  - **The ask list.** Every other name that the reader's wide list in `fields.md` ("Credential-like names") marks as credential-like, and every values path with a credential-like key above its last one (`database.credentials.user`). That list is wide on purpose, to keep values from printing, and most names on it hold no secret.
- **One status for each case:**

| Case | Fields | Status |
| --- | --- | --- |
| A Secret with values in the repository | A `Secret` object that prints at least one `secret-key.data` or `secret-key.string-data`, and no `sops=present` | fail |
| A Secret with a SOPS block and a value in clear | `sops=present` and `sops-clear-count` above 0 | fail |
| A Secret encrypted by SOPS | `sops=present` and `sops-clear-count=0` | pass for that object |
| A Secret with a SOPS block and no count | `sops=present` with `sops-clear-count=other`, or with no `sops-clear-count` line | ask the team |
| A Secret whose keys are all empty | only `secret-key.data-empty` or `secret-key.string-data-empty` lines | not a K7 case |
| A sealed or external secret kind | A kind the reader does not read, such as `SealedSecret` or `ExternalSecret` | not a K7 case: "Not checked" |
| An env var with a written value and a name on the fail list | `env.<NAME>=literal` | fail |
| An env var with an empty value | `env.<NAME>=literal-empty` | not a K7 case |
| A ConfigMap key or a values key that looks encrypted | `configmap-data.<key>=encrypted` or `values-key.<path>=encrypted` | not a K7 case |
| A key with a value in a values file, named on the fail list | `values-key.<path>=scalar` with the kind `Values` | fail |
| A key with a value in an `Application`'s inline values, named on the fail list | `values-key.<path>=scalar` with the kind `Application` or `ApplicationSet` | fail |
| A key with a value in a ConfigMap, named on the fail list | `configmap-data.<key>=scalar`. A ConfigMap gives no secrecy (K21) | fail |
| A key in an `ApplicationSet` list generator, named on the fail list | `list-element.<i>.<j>.<key>` | fail |
| A name on the ask list, in any of the five cases above | `env.<NAME>=literal`, `values-key.<path>=scalar`, `configmap-data.<key>=scalar`, `list-element.<i>.<j>.<key>` | ask the team |
| A credential-like command or argument item | `args-credential-like-count` above 0 | ask the team |
| A credential-like annotation key with a value | `annotation-credential-like-count` above 0 | ask the team |
| A user part in a repository address | `source.<n>.url-has-user-part=true`. The reader does not tell a user name from a password | ask the team |
| A key or an env entry the reader could not read | `env-other-count` above 0, `values-key-unreadable-count` above 0, `source.<n>.helm-values=other` | ask the team at best; the file and line go under "Not checked" |

- **Empty placeholders are never a case.** An empty string, `null`, or `~` prints `empty` for a `values-key` or `configmap-data` line, `literal-empty` for an env var, and `secret-key.data-empty` or `secret-key.string-data-empty` for a Secret key. A `block` line holds no value of its own: the keys under it print lines of their own.
- **SOPS.** `sops=present` says that the document has a top-level `sops` block map, which SOPS writes when it encrypts a file (verify). It is not proof of encryption: a `sops` block can be written by hand, and SOPS can leave chosen keys in clear (verify). So the reader also tests each value's shape, without printing it: a value looks encrypted when it starts with `ENC[` and ends with `]`. For a Secret it counts the set `data` and `stringData` keys that do not look encrypted (`sops-clear-count`), and a block scalar counts as clear. For a ConfigMap key or a values key it prints `encrypted` in place of `scalar`. The shape counts only in a document or values file with a `sops` block map, so `ENC[` alone earns nothing. The evidence for a pass says "encrypted by SOPS as far as the file shows", with the lines of `sops=present` and `sops-clear-count=0`.
- **Sealed and external secret kinds.** The reader does not read them. The list mode prints such a file as `manifest`, and `--fields` prints no line at all for a document of a kind it does not read, not even `object=present`. So a listed `manifest` for which `--fields` prints nothing, with exit code 0, holds only kinds the reader does not read: it goes under "Not checked" by its path, as "a kind the reader does not read", and never fails K7. The agent cannot see the kind's name. In a file with several documents, a document of such a kind leaves no line, and the report says that the file may hold kinds the reader does not read.
- **Annotations.** The reader prints no annotation key, so an annotation can never show that a `Secret` is sealed or encrypted.
- **Pass:** none of the fail or "ask the team" cases in the environment.
- **Evidence:** each case names the file, the line, the object, and the key name or the count. Never a value. A credential in other source code (not a manifest and not a values file) is reported under "Also found" with its path, its line, and its type, and the report points to the vibe-code pre-launch check for the full secrets pass.
- **Question:** "Do the items at <file:line list> hold only references, file paths, user names, or settings, and no secret values?"

### K8. A NetworkPolicy covers every workload.

- **Fields:** on each NetworkPolicy in the environment: `np-pod-selector`, `np-pod-label.<key>`, `np-pod-label-other-count`, `np-policy-type`, and the `np-ingress.*` lines. On each workload: `pod-label.<key>`, `pod-label-other-count`, and its namespace.
- **Covered.** A workload is covered when a NetworkPolicy in its namespace selects its pods for ingress. A policy selects them when it prints `np-pod-selector=all`, or when every `np-pod-label.<key>=<value>` it prints matches a `pod-label.<key>=<value>` of the workload and it prints no `np-pod-label-other-count`. It isolates for ingress when it prints `np-policy-type=Ingress`, or prints no `np-policy-type` line at all (`Ingress` is then always set, K18). With no policy that selects a pod, all traffic to it is allowed (K18). Egress is not part of the status: the reach map shows it.
- **Pass:** every workload is covered.
- **Warn:** every workload is covered, and a policy that selects one allows ingress from an `ip-block` of `0.0.0.0/0` or `::/0`, or from a peer with `namespace-selector=all` and no `pod-selector`.
- **Fail:** a workload is not covered.
- **Ask the team:** whether a policy selects a workload cannot be decided, because the selector uses a label key outside the reader's list (`np-pod-label-other-count`); a selecting policy prints `np-ingress.<r>.peers=0` (how Kubernetes reads a rule with no `from` was not read, verify); or a deciding field is `other`.
- **Not checked, always:** whether the cluster's network plugin enforces NetworkPolicy (K18).
- **Question:** "Do the NetworkPolicies <list> select the pods of <workloads>?"

### K9. Every image is pinned by digest and comes from a named registry.

- **Fields:** `image-pin`, `image-registry`, and `image-repository` on each container. Context: `image-pull-policy`. The reader never prints a tag.
- **Pass:** every container prints `image-pin=digest` and an `image-registry` other than `default`.
- **Warn:** a container prints `image-pin=tag` (whether a registry lets a tag move to another image is not read, verify; this check's own call is that only a digest pins), or `image-registry=default`. With no registry written, the image comes from the Docker public registry (K26). How the reader tells a host from a path is "verify" (see `fields.md`), and the evidence says so.
- **Fail:** a container prints `image-pin=latest` or `image-pin=none`. An image with no tag and no digest is treated as `latest` (K26).
- **Ask the team:** `image-registry` or `image-repository` is `other` (the image did not fit the image shape), or the workload is not read or not rendered. For a chart that was not rendered, the `values.<path>` lines ending in `image.tag` or `image.digest` are named in the evidence as what the values set.
- **Question:** "Do the images of <containers> come from a registry the team controls, pinned by digest?"

### K10. Every namespace enforces the restricted Pod Security level.

- **Fields:** on each Namespace object in the environment: `psa-enforce`, `psa-enforce-version`, `psa-warn`, `psa-warn-version`. Only `enforce` rejects a pod; `warn` only warns (K19). The third mode label, which writes to the audit log, is not printed by the reader (see `fields.md`), and it never counts as a level here.
- **Pass:** every namespace of the environment has a Namespace object that prints `psa-enforce=restricted`.
- **Warn:** a Namespace object prints `psa-enforce=baseline`, or prints no `psa-enforce` and a `psa-warn` line.
- **Fail:** a Namespace object prints `psa-enforce=privileged`, or prints neither `psa-enforce` nor `psa-warn`.
- **Ask the team:** the environment holds no Namespace object for a namespace, or `psa-enforce` is `other`.
- **Not checked, always:** a level set in the API server's own configuration has no field (verify).
- **Question:** "Do the namespaces <list> enforce the restricted Pod Security level in a label the repository does not show?"

## Known limits

- **A system workload that needs the host fails K4 by design.** A network plugin, a node exporter, or a log shipper mounts a `hostPath` or uses the host network on purpose. K4 fails it all the same, and the evidence line names the workload and the field, so that a team can see the failure is one it chose. The skill does not keep a list of workloads that may use the host.
- **A credential in an argument or an annotation is counted, not seen.** `args-credential-like-count` and `annotation-credential-like-count` count items with a credential-like name. The reader cannot tell a written secret from a reference such as `--token=$(TOKEN)` or a file path, so each count is "ask the team", and it cannot block a verdict on its own.
- **SOPS by shape, not by proof.** The skill sees the shape of a value (`ENC[` at the start and `]` at the end), not whether it was really encrypted. A value written by hand in that shape passes as encrypted (see K7).
- **Names that fail though they usually hold a flag.** `SKIP_PASS`-style names, `MYSQL_ALLOW_EMPTY_PASSWORD`, and `MYSQL_RANDOM_ROOT_PASSWORD` end in a fail-list word and usually hold `yes` or `true`. They fail K7 with the name given, and a team that sees one can tell at once.
- **A quoted empty value with a comment reads as set.** `password: '' # c` is read as a value, not as `empty`, so the check errs towards a fail.
- **Two names that fail though they may hold no secret.** `existingSecretPassword` (its last word is `password`, and the word before it is not `existing`) and a bare `secret` key both stay on the fail list. A team that uses them for a reference will see a fail, with the key named.
- **Kinds the reader does not read leave no line.** A sealed or external secret kind, or any other kind outside `fields.md`, prints nothing (see K7).

## The cluster pass and R8

The cluster pass runs only after a yes, and only when R8 is "ask the team". Its figures appear in their own block, labelled "measured in the cluster", after the report. They never change R8, another status, a headline, or a verdict.

How the block reads the output of `scripts/read-cluster-usage.sh` (the columns and shapes are in `fields.md`, command section 3):

- **A container row** sets the repository's request beside the cluster's `CPU_REQ`, `CPU_LIM`, `MEM_REQ`, `MEM_LIM`, and the measured `CPU_USED` and `MEM_USED`. The agent matches a row to a workload by namespace and container name, and says so as an assumption: a pod names no workload in these columns.
- **Nothing measured** is only a `-` in `CPU_USED` or `MEM_USED`. `not-read`, `other`, and a row counted in `# rows not placed` are never "nothing measured": the block says that the value was seen and not read, and names the namespace and the count.
- **One moment in time.** A `kubectl top` value is a single sample, and the block says so.
- **A VerticalPodAutoscaler's recommendation** is quoted from the `vpa` rows as it is, beside the request. The skill computes no recommendation of its own.
- **Killed for memory.** A `POD_LAST_END` of `OOMKilled` is named for the pod, not for a container, because the script cannot place it on one.
- **A namespace not read.** `# vpa: not read` or `# hpa: not read` is never "none in this namespace". Exit code 6 names the namespaces whose metrics were not read.

## The first three to change

Up to three checks marked fail or warn, taken in this order:

Order: K7, K6, K4, K1, K8, K5, K2, K10, R1, R2, K9, K3, R3, R4, R5, R6, R7.

R8 is never in the list, because it cannot fail from the repository. A check marked "ask the team" is never in the list.
