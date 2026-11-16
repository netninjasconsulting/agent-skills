# Snippets

Fixes to paste, one section for each check. The field paths come from [fields.md](fields.md). Each snippet is one YAML block and at most one line under it that starts with "Note:". A first-three item copies the block and its note as they stand, with names, files, and placeholders adapted to the repository, and takes nothing else from this file. In a report, each "verify" is written as "not confirmed against the documentation".

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

Note: Every container needs both requests, init containers included.

```yaml
# values-<environment>.yaml, for a chart whose template reads resources from its values (the key names are the chart's own, verify)
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

Note: In a chart, the values form is the R1 values block with `limits` in place of `requests` (verify).

## R3. Limit close to the request

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

Note: Twice is this skill's own line, not a Kubernetes rule, and a limit below the request is a warn too.

## R4. Autoscalers

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

Note: Every container of the target needs a request for the resource a `Utilization` metric reads (R1); a VerticalPodAutoscaler names its target in `spec.targetRef` with the same three keys.

## R5. Namespace defaults and ceilings

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

Note: Put it in the same environment as the namespace's workloads, so that the check can see it.

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

Note: With a ResourceQuota on CPU or memory, every new pod in the namespace must set a request or a limit for it, or it may be rejected.

## R6. Scratch space

```yaml
# <P>
volumes:
  - name: <volume>
    emptyDir:
      sizeLimit: <size>
```

Note: Every `emptyDir` volume needs a size limit, one with `medium: Memory` included.

## R7. Batch deadlines

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

Note: `concurrencyPolicy` keeps a slow run and the next one from running at once.

## R8. Measured use

No snippet: R8 is answered by measured use, not by a file.

## K1. Not root, not privileged

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

Note: A container-level setting overrides the pod-level one.

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

Note: Remove `capabilities.add` and `privileged: true` too: a privileged container can always escalate, whatever `allowPrivilegeEscalation` says.

## K3. Read-only root filesystem

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

Note: Delete `hostPort` from each entry of `ports`, and replace a `hostPath` volume with a volume that does not share the node's files.

## K5. ServiceAccount and token

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

Note: When the pod and the account both set `automountServiceAccountToken`, the pod's setting wins.

## K6. RBAC rules

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

Note: Name every verb and resource with no `*`, bind this Role in place of `cluster-admin`, `admin`, or `edit`, and leave out `escalate`, `bind`, and `impersonate`.

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

Note: `get`, `list`, and `watch` on `secrets` reveal their contents, so the rule names the Secrets it reads (verify: which verbs `resourceNames` narrows is not in `fields.md`).

## K7. Secrets out of the repository

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

Note: The value leaves the manifest, the values file, the ConfigMap, or the `Application`, and the env var reads a Secret made outside the repository by name.

```yaml
# values-<environment>.yaml, for a chart that takes the name of an existing Secret in a values key (the key name is the chart's own, verify)
database:   # the section of the chart that takes the Secret: adapt it (verify)
  existingSecret: <secret made outside the repository>
```

## K8. NetworkPolicy

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

Note: Select the pods with a label key the reader reads: `app`, `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of`, `component`, `tier`, `role`, or `environment`.

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

Note: This policy covers every workload of the namespace and lets no traffic in until a policy like the one above allows it (verify: how a policy with no ingress rule is read is not in `fields.md`).

## K9. Images pinned by digest

```yaml
# <P>
containers:
  - name: <container>
    image: <registry host>/<repository>@sha256:<digest>
```

```yaml
# values-<environment>.yaml, for a chart whose template builds the image from image.digest (a chart convention, verify)
image:
  repository: <registry host>/<repository>
  digest: sha256:<digest>
```

## K10. Pod Security level

```yaml
apiVersion: v1   # verify: the pages read show no apiVersion for Namespace
kind: Namespace
metadata:
  name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: <latest, or a minor version such as v1.NN>
```

Note: Put the Namespace object in the same environment as its workloads, so that the check can see it.
