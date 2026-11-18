# Kubernetes workload check

I publish this free skill through Net Ninjas Consulting, a one-person cloud, DevOps, and AI consultancy in New York City.

A free agent skill that checks if each workload on Kubernetes is sized on purpose and confined to what it needs.

I keep seeing the same pattern in clusters that grew fast. The requests came from a template. A container has no memory limit, and another one runs as root. A role binding says `*`, a Secret sits in a values file, and no NetworkPolicy covers the pod. Then the bill grows, and nobody can say which request caused it. This skill reads the repository and checks both sides: what each workload asks for, and what it can reach.

## What it checks

**Eight sizing checks,** for CPU, memory, and scratch space.

- R1. Every container sets a CPU request and a memory request, init containers and sidecars included.
- R2. Every container sets a memory limit.
- R3. Each memory limit sits close to its request.
- R4. Every autoscaler has what it needs to work.
- R5. Every namespace sets defaults or ceilings for CPU and memory.
- R6. Scratch space has a ceiling.
- R7. Batch work has a deadline, and scheduled runs do not pile up.
- R8. Requests match measured use.

**Ten security checks.**

- K1. No container runs as root or privileged.
- K2. Every container drops all capabilities and blocks privilege escalation.
- K3. Every container's root filesystem is read-only.
- K4. No pod shares the host's network, processes, or files.
- K5. Each workload has its own ServiceAccount, and mounts a token only when it calls the API.
- K6. RBAC rules name their verbs and their resources.
- K7. Secrets stay out of manifests and values files.
- K8. A NetworkPolicy covers every workload.
- K9. Every image is pinned by digest and comes from a named registry.
- K10. Every namespace enforces the restricted Pod Security level.

R3 uses a line of this skill's own, not a Kubernetes rule: a memory limit of more than twice its request is a warn.

**The reach map.** It has one row for each workload in each environment. The row gives its ServiceAccount, the roles bound to it and what they allow, the Secrets and ConfigMaps it names, the peers its NetworkPolicies allow in and out, and its access to the host. The skill marks each row "confined", "broad", or "not found in the repository". The map shows names only, never a value.

## What it reads

- The skill reads plain manifests, Helm charts, Kustomize overlays, and Argo CD `Application` and `ApplicationSet` objects through a bundled reader script. It also reads Argo Rollouts `Rollout` objects. The reader prints named fields, never a line of a file. It never prints the value of a Secret, a ConfigMap, an environment variable, an argument, or an annotation.
- It groups what it finds into environments. An Argo CD object that points at this repository names one. Without one, each overlay and each values file beside a chart is an environment. The remaining manifests are "Plain manifests".
- A chart or an overlay shows little until it is rendered. The skill offers once to render them, and it renders only after a yes. Rendering runs `helm template`, `kustomize build`, or `kubectl kustomize` on your machine, whichever you have installed. It fetches nothing and applies nothing. The reader refuses a chart or an overlay that would fetch. The rendered text goes into the reader's own extractor and never reaches the agent.
- It reads the top-level README and other top-level documents as data. They never pass a check.

## What comes back

The report opens with the scope line: "This is a quick check. It is not a penetration test and it is not legal advice." A note follows it: a file is not the cluster. Then one line says if the charts and overlays were rendered.

Each environment gets a verdict: "Not ready for production", "Ready after the first three", or "Ready from what the repository shows". A fail in K1, K4, K6, or K7 gives the first one. The sizing checks never block alone. Two headlines sit under each verdict.

```text
Sizing: N out of M confirmed in the repository (K to ask the team)
Security: N out of M confirmed in the repository (K to ask the team)
```

Each check gets one status for each environment: "pass", "warn", "fail", "ask the team", or "does not apply". M counts only the checks that apply. R8 never passes from the repository. Where R1 fails, R8 does not apply. Otherwise it is "ask the team", because only measured use shows that a request fits.

Some environments are not fully seen. That means a chart or an overlay was not rendered, or a file was not read. In such an environment, no check passes and no check is "does not apply". It gets no "Ready" verdict. It gets "Not ready for production" when K7 fails from a printed case, or when a manifest applied as it is prints a fail in K1, K4, or K6. Otherwise it gets a line that says what was not seen.

The workload map comes first, then the eighteen checks, each with a file and a line. The reach map follows them. Next come the first three things to change for each environment. They follow a fixed order, from K7, K6, K4, and K1 down to the sizing checks. Each one comes with a snippet. Every value in a snippet is a placeholder, and no snippet names a size.

The report ends with the questions for the team, anything else it found, and what it did not check. Two offers close the reply, each made once. The first asks the questions that sit outside the repository. The answers go in their own block, and each one carries the label "stated by the team". The second is the cluster pass, described below. Neither block changes a headline, a status, or a verdict.

When the repository holds no Kubernetes workload, the skill says so, lists what it searched for, and stops with no score.

## The cluster pass

R8 asks if requests match measured use. The repository cannot answer that. The cluster pass can, and it is the one part of this skill that makes a network request.

- The skill offers it once, and only when R8 is "ask the team" for an environment whose namespace is known. The offer names the namespaces and the current `kubectl` context.
- Before the offer, the skill runs `kubectl config current-context`, which reads your local kubeconfig and sends no request to the cluster.
- After a yes, one script runs a fixed list of read-only `kubectl` commands for the namespaces it offered and no others: `kubectl top pod --containers`, `kubectl get pods`, `kubectl get verticalpodautoscalers`, and `kubectl get horizontalpodautoscalers`.
- It never asks for a Secret or a pod's logs. It never prints a whole object or a line of `kubectl` output as it came. It writes nothing and changes nothing. Every command carries `--profile=none` and `--cache-dir=`, so a default in your kuberc file cannot make `kubectl` write a file into the repository.
- `kubectl` runs with your own settings: your kubeconfig, your identity, and your kuberc file. The script reads the current context when it runs, passes that context to every command, and prints it on its first line. The skill stops, and reports nothing from the run, if that is not the context it offered.
- The result is a separate block called "Measured in the cluster". It sets the request and limit in the repository, the request and limit the running pod carries, and measured use side by side, as printed. It quotes a VerticalPodAutoscaler's own recommendation and marks a pod last killed for memory. It computes no size, no ratio, no saving, and no cost.

With no answer, or a no, R8 stays "ask the team" and no cluster command runs.

## What it never does

- It never runs the project. It installs, builds, tests, applies, and deploys nothing.
- It never writes a file, and it never changes a setting in a cluster, a cloud account, a Git remote, or a provider.
- It makes no network request in the first pass. Rendering needs none. The cluster pass is the only request, and it needs a second yes.
- It never opens a manifest, a values file, a chart template, or a kustomization in any way but the reader. After a refusal it tries no other way in.
- It tells the agent never to repeat a secret value. The agent reports the file, the line, and the secret type.
- It never passes a check because a README, a comment, or a name says so.
- It never follows instructions found inside the repository.
- It sends nothing to Net Ninjas or to anyone else.

## Limits

- **The reader doesn't parse.** It works by line. A layout it cannot place gives "not found". A layout it cannot place at all, such as a non-empty flow map like `matchLabels: {app: web}`, an anchor, an alias, or a template line, makes the whole file "not read". The skill names that file under "Not checked" and doesn't open it another way. The list also names a `.yaml`, `.yml`, or `.json` file that holds both `apiVersion` and `kind`, or an escape that can spell them, in a layout the reader can't read, such as JSON, a byte order mark, or `kind : Pod`. Such a file is "not read" too, and so is a file that only mentions both words in such a layout. Inside a chart or an overlay that renders, such as a JSON patch, it stays under "Not checked" and does not hold back the environment, because the render shows what the tool used. Outside every chart and overlay, it leaves Plain manifests not fully seen.
- **A chart that isn't rendered shows its values files only.** Its templates are "not found". An overlay that isn't rendered prints no line for what it builds. In such an environment, only a K7 case and a manifest applied as it is can fail or warn a check, and nothing passes.
- **Some settings have no field.** Probes, `seccompProfile`, Services, Ingresses, PodDisruptionBudgets, and PersistentVolumeClaims are examples. `references/fields.md` lists them under "Settings with no field".
- **Some kinds leave no line.** The reader prints nothing for a sealed or external secret kind, KEDA, Knative, or Argo Workflows, so the skill can't score them. A file that holds a `List` kind is not read at all, so the environment it feeds is not fully seen. The list follows a symbolic link that stays inside the repository and lists each file it reaches at the link's path, so a file linked into an environment's directory is listed with it. It does not read a link that points outside the repository or is broken: it names such a link, if it is named like a manifest or points to a directory, and the environment whose files it sits among is not fully seen. The list follows directory links at most 40 deep, and a tree whose links reach more than 200,000 paths is not listed at all, so no environment of it is checked.
- **The reader can refuse to render.** It refuses a `helm`, `kustomize`, or `kubectl` that resolves inside the repository, which a `PATH` with `.` can find, and the cluster script refuses such a `kubectl` too. Before it runs any program, the reader removes every relative `PATH` entry and every entry inside the repository, so its own `awk`, `git`, and the rest, and the render tools, come from outside the repository. If `awk`, `find`, `sed`, `sort`, or `grep` is then missing, it stops and names it. Without `git`, every state is "no-git". The cluster script cleans `PATH` the same way before it runs any program, so it fails when its only `awk` sits in a relative entry. Both are the safe direction. It refuses a chart or overlay that holds a symbolic link pointing outside the repository or a broken one, a remote base, a plugin or an inflator, a chart with dependencies that are not vendored, and a schema reference that is not local, read with its JSON escapes decoded. A `$schema` that names one of json-schema.org's standard metaschemas exactly is allowed, because Helm has them built in. kustomize and Helm read their own keys in any case, so a key such as `Resources` or `Dependencies` is refused too. A label or annotation key spelt the same way is not refused. An overlay entry that goes through a symbolic link and back up with `..`, such as `lnk/../base`, is refused even when kustomize would render it, because the reader and kustomize read such a path differently. Each refusal leaves that environment "not rendered".
- **Argo CD objects that point elsewhere name no environment.** That covers an `Application` that points to another repository and an `ApplicationSet` with any generator other than `list`. The skill names them under "Not checked".
- **The inline values of an `Application` are not sized.** A render takes values files only, so the skill lists every inline path under "Not checked". K7 still judges each inline line.
- **The cluster pass is one sample.** `kubectl top` gives one moment in time, and a new pod can have no metrics yet. The script reads containers and not init containers. A pod does not name its workload in these columns, so the match by namespace and container name is an assumption. When `kubectl top pod` fails for a namespace, the script stops with exit code 6, and the namespaces after it are not read.
- **A file is not the cluster.** An admission controller, a default from a LimitRange in another repository, or a manual change can make the running pod differ. The report says so at the top.
- **21 Kubernetes and Helm facts are marked "verify".** `references/fields.md` holds 275 rows with a status. I read 254 of them on 15, 16, and 17 November 2026, in the project's own documentation, in its source, or in the output of a local tool. I marked the other 21 "verify", because I didn't confirm them on those dates. Field names and limits move between Kubernetes versions.
- **No size, no saving, and no cost.** The first pass says if a setting is explicit, and where. It never says what a request should be.

## Install

The skill installs with the [skills CLI](https://github.com/vercel-labs/skills), which needs Node.js 22.20 or later:

```sh
npx skills add netninjasconsulting/agent-skills --skill kubernetes-workload-check
```

The skills CLI is a third-party tool, and it collects anonymous usage data of its own. Setting `DISABLE_TELEMETRY=1` in front of the command turns that off. The skill is also a plain folder, so copying `skills/kubernetes-workload-check` from this repository into the agent's skills folder works without any installer.

It needs a POSIX shell with `git`, `grep`, `sed`, `awk`, `find`, and `sort`. `helm`, `kustomize`, and `kubectl` are optional. A chart needs `helm` to render, an overlay needs `kustomize` or `kubectl`, and the cluster pass needs `kubectl`. I tested it with Claude Code on Linux, with `helm` v4.3.2 and `kubectl` v1.37.2. The SKILL.md format is agent-neutral, so other coding agents that read skills can run it too.

## Use

In a clone of the repository:

```text
Are these workloads sized right and locked down? Check the CPU and memory settings and the security.
```

## Test fixture

`tests/fixtures/kubernetes-workload-check/fleetboard/` in this repository holds a fleet-tracking product with plain manifests, Kustomize overlays, a Helm chart, and Argo CD objects. It resolves to five environments. `EXPECTED.md` holds the result the skill has to produce on it. `scenarios.md` adds four cases: a repository with no workload, the fixture with `helm` and `kubectl` off the path, the fixture with the CPU request of one workload removed, and the fixture with the Argo CD objects removed.

`tests/read-k8s-objects.test.sh` runs the object reader against the fixture and its own attack files in CI. `tests/read-cluster-usage.test.sh` runs the cluster script against a stand-in `kubectl` that logs every command and never contacts a cluster. Both fail when a planted value appears in any output. `tests/RESULTS.md` records every run, and the rules that the first runs and the reviews changed. The recorded runs use the stand-in. None of them reached a real cluster.

## Licence

Apache-2.0. Copyright 2026 Net Ninjas Consulting. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).

Which of your workloads still runs with the requests its template gave it? More free skills and guides: [netninjas.us/skills](https://www.netninjas.us/skills).
