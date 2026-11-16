# Snippets

Fixes to paste, one section for each check. The field paths come from [fields.md](fields.md). Adapt names and paths to the repository, and say which lines were adapted.

Every value is a placeholder in angle brackets. A snippet shows where a setting goes and leaves the value to the team: the skill never says what a request, a limit, a size, a deadline, a replica count, or a utilisation target should be. Here, "verify" marks a name, a key, or a form that `fields.md` does not hold, or that it marks "verify": it was not read in the Kubernetes, Helm, Kustomize, or Argo documentation on 15 November 2026, so read the current page before pasting it. A secret never goes into a snippet, as a value or as an example.

Each snippet shows only the fields that fix its check, in the place they sit. `<P>` in a comment is the pod spec: `spec` in a Pod, `spec.template.spec` in a Deployment, StatefulSet, DaemonSet, Job, or `Rollout`, and `spec.jobTemplate.spec.template.spec` in a CronJob. Write every map in block style, as below. A flow map such as `matchLabels: {app: web}` makes the reader skip the whole file. In a chart, the fix goes in the template or in the values key the template reads. In an overlay, it goes in the base or in a patch of the overlay.

## Contents

1. [R1. Requests](#r1-requests)
2. [R2. Memory limit](#r2-memory-limit)
3. [R3. Limit close to the request](#r3-limit-close-to-the-request)
4. [R4. Autoscalers](#r4-autoscalers)
5. [R5. Namespace defaults and ceilings](#r5-namespace-defaults-and-ceilings)
6. [R6. Scratch space](#r6-scratch-space)
7. [R7. Batch deadlines](#r7-batch-deadlines)
8. [R8. Measured use](#r8-measured-use)
9. [K1. Not root, not privileged](#k1-not-root-not-privileged)
10. [K2. Capabilities and escalation](#k2-capabilities-and-escalation)
11. [K3. Read-only root filesystem](#k3-read-only-root-filesystem)
12. [K4. Nothing shared with the host](#k4-nothing-shared-with-the-host)
13. [K5. ServiceAccount and token](#k5-serviceaccount-and-token)
14. [K6. RBAC rules](#k6-rbac-rules)
15. [K7. Secrets out of the repository](#k7-secrets-out-of-the-repository)
16. [K8. NetworkPolicy](#k8-networkpolicy)
17. [K9. Images pinned by digest](#k9-images-pinned-by-digest)
18. [K10. Pod Security level](#k10-pod-security-level)

## R1. Requests

Set both requests on every container, init containers included. Choose the values from measured use.

```yaml
# <P>
containers:
  - name: <container>
    resources:
      requests:
        cpu: <CPU request, from measured use>
        memory: <memory request, from measured use>
initContainers:
  - name: <init container>
    resources:
      requests:
        cpu: <CPU request, from measured use>
        memory: <memory request, from measured use>
```

In a chart whose template reads `resources` from its values (the key names are the chart's own, verify):

```yaml
# values-<environment>.yaml
resources:
  requests:
    cpu: <CPU request, from measured use>
    memory: <memory request, from measured use>
```

## R2. Memory limit

```yaml
# <P>
containers:
  - name: <container>
    resources:
      limits:
        memory: <memory limit>
```

The chart form is the R1 values block with `limits` in place of `requests` (verify).

## R3. Limit close to the request

Keep the memory limit at most twice the memory request. Twice is this skill's own line, not a Kubernetes rule. A limit below the request is a warn too.

```yaml
# <P>
containers:
  - name: <container>
    resources:
      requests:
        memory: <memory request>
      limits:
        memory: <memory limit, at most twice the request>
```

## R4. Autoscalers

Name a target that is in the environment, keep the minimum below the maximum, and give every container of the target a request for each resource a `Utilization` metric reads (R1).

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <autoscaler>
  namespace: <namespace>
spec:
  scaleTargetRef:
    apiVersion: <apps/v1, or argoproj.io/v1alpha1 for a Rollout>
    kind: <Deployment, StatefulSet, or Rollout>
    name: <workload in this environment>
  minReplicas: <minimum>
  maxReplicas: <maximum, above the minimum>
  metrics:
    - type: Resource
      resource:
        name: <cpu or memory>
        target:
          type: Utilization
          averageUtilization: <percent of the request>
```

For a VerticalPodAutoscaler, the target is `spec.targetRef` with the same three keys, and the mode is `spec.updatePolicy.updateMode`. Whether the VerticalPodAutoscaler and a metrics source are installed is outside the repository.

## R5. Namespace defaults and ceilings

Give each namespace a LimitRange, a ResourceQuota, or both, in the same environment as its workloads.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: <name>
  namespace: <namespace>
spec:
  limits:
    - type: Container          # verify: the API page shows no list of types
      defaultRequest:
        cpu: <default CPU request>
        memory: <default memory request>
      default:
        cpu: <default CPU limit>
        memory: <default memory limit>
      max:
        cpu: <CPU ceiling>
        memory: <memory ceiling>
```

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: <name>
  namespace: <namespace>
spec:
  hard:
    requests.cpu: <total CPU requests>
    requests.memory: <total memory requests>
    limits.cpu: <total CPU limits>
    limits.memory: <total memory limits>
```

With a ResourceQuota on CPU or memory, every new pod in the namespace must set a request or a limit for it, or it may be rejected.

## R6. Scratch space

Give every `emptyDir` volume a size limit. A volume with `medium: Memory` keeps its files in memory.

```yaml
# <P>
volumes:
  - name: <volume>
    emptyDir:
      sizeLimit: <size>
```

## R7. Batch deadlines

Give every Job a deadline, and keep each CronJob's runs from overlapping.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: <job>
spec:
  activeDeadlineSeconds: <seconds>
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: <cronjob>
spec:
  concurrencyPolicy: <Forbid or Replace>
  jobTemplate:
    spec:
      activeDeadlineSeconds: <seconds>
```

## R8. Measured use

No snippet. R8 is answered by measured use, not by a file: the cluster pass reads it after a yes, and the team chooses the requests from it.

## K1. Not root, not privileged

Run as a user other than root, at the pod or at each container, and leave `privileged` unset or false. A container-level setting overrides the pod-level one.

```yaml
# <P>
securityContext:
  runAsNonRoot: true
  runAsUser: <a user ID above 0>
  runAsGroup: <a group ID above 0>
containers:
  - name: <container>
    securityContext:
      privileged: false
```

## K2. Capabilities and escalation

```yaml
# <P>
containers:
  - name: <container>
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
          - ALL
```

Remove `capabilities.add` and `privileged: true`. A privileged container can always escalate, whatever `allowPrivilegeEscalation` says.

## K3. Read-only root filesystem

Make the root filesystem read-only, and give the program a volume for the paths it writes.

```yaml
# <P>
containers:
  - name: <container>
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
      - name: <volume>
        mountPath: <path the program writes>   # verify
volumes:
  - name: <volume>
    emptyDir:
      sizeLimit: <size>
```

## K4. Nothing shared with the host

Delete `hostNetwork`, `hostPID`, and `hostIPC` from the pod spec, or set each to `false`. Delete `hostPort` from each entry of `ports`. Replace a `hostPath` volume with a volume that does not share the node's files.

```yaml
# <P>
hostNetwork: false
hostPID: false
hostIPC: false
volumes:
  - name: <volume>
    emptyDir:
      sizeLimit: <size>
```

A workload that has to reach the host, such as a node agent, fails K4 by design. Keep it in a namespace of its own, and say so to the team.

## K5. ServiceAccount and token

Give each workload an account of its own, and turn the token off unless the workload calls the Kubernetes API. When the pod and the account both set `automountServiceAccountToken`, the pod's setting wins.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <workload>
  namespace: <namespace>
automountServiceAccountToken: false
```

```yaml
# <P>
serviceAccountName: <workload>
automountServiceAccountToken: false
```

## K6. RBAC rules

Name every verb and every resource, with no `*`. Bind a Role of the workload's own in place of `cluster-admin`, `admin`, or `edit`. Leave out `escalate`, `bind`, and `impersonate`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <role>
  namespace: <namespace>
rules:
  - apiGroups:
      - "<API group>"   # "" for the core group
    resources:
      - <resource>
    verbs:
      - <verb>
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <binding>
  namespace: <namespace>
roleRef:
  apiGroup: rbac.authorization.k8s.io   # verify
  kind: Role
  name: <role>
subjects:
  - kind: ServiceAccount
    name: <workload's account>
    namespace: <namespace>
```

A rule that grants `get`, `list`, or `watch` on `secrets` reveals their contents. Give it `resourceNames` with the Secrets it reads, under the same rule (verify: which verbs `resourceNames` narrows is not in `fields.md`):

```yaml
rules:
  - apiGroups:
      - ""
    resources:
      - secrets
    resourceNames:
      - <secret the workload reads>
    verbs:
      - get
```

## K7. Secrets out of the repository

Take the value out of the manifest, the values file, the ConfigMap, or the `Application`, and keep it in a Secret made outside the repository. A value that was committed stays in the Git history, so change it at its source as well.

An env var reads the Secret by name:

```yaml
# <P>
containers:
  - name: <container>
    env:
      - name: <NAME>
        valueFrom:
          secretKeyRef:
            name: <secret made outside the repository>
            key: <key>   # verify
```

In a chart, many charts take the name of an existing Secret in a values key instead of the value (the key name is the chart's own, verify):

```yaml
# values-<environment>.yaml
<section>:
  existingSecret: <secret made outside the repository>
```

A Secret kept in the repository passes K7 only when SOPS has encrypted every value, as far as the file shows (`sops=present` and `sops-clear-count=0`). How to set SOPS up is in its own documentation (verify).

## K8. NetworkPolicy

Select each workload's pods with a label key the reader reads (`app`, `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `component`, `tier`, `role`, or `environment`), and name the peers allowed in.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <workload>
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app: <the workload's app label>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: <the caller's app label>
      ports:
        - protocol: TCP
          port: <port>
```

A policy that selects every pod of the namespace, and lists `Ingress` with no ingress rule, covers every workload there and lets no traffic in until a policy like the one above allows it (verify: how a policy with no ingress rule is read is not in `fields.md`):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <name>
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

A policy has no effect when the cluster's network plugin does not enforce it.

## K9. Images pinned by digest

Name the registry, and pin the image by its digest.

```yaml
# <P>
containers:
  - name: <container>
    image: <registry host>/<repository>@sha256:<digest>
```

In a chart whose template builds the image from `image.digest` (a chart convention, verify):

```yaml
# values-<environment>.yaml
image:
  repository: <registry host>/<repository>
  digest: sha256:<digest>
```

## K10. Pod Security level

Label each Namespace object to enforce the restricted level.

```yaml
apiVersion: v1   # verify: the pages read show no apiVersion for Namespace
kind: Namespace
metadata:
  name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: <latest, or a minor version such as v1.NN>
```

Put the Namespace object in the same environment as its workloads, so that the check can see it.
