# The cluster pass

The second pass reads measured CPU and memory from the cluster, read-only, after a yes. It answers R8 for the team to read, and it changes nothing in the report: no status, no headline, no verdict, and not the first three. R8 stays "ask the team". The commands, the columns, and the shapes are those of "Command section 3: the cluster commands" in [fields.md](fields.md). This file says when to offer the pass, what to run, and how to read what the script prints.

## Contents

1. [Before the offer](#before-the-offer)
2. [The offer](#the-offer)
3. [After a yes](#after-a-yes)
4. [What the script prints](#what-the-script-prints)
5. [Matching a row to the repository](#matching-a-row-to-the-repository)
6. [What the block says, and what it never says](#what-the-block-says-and-what-it-never-says)

## Before the offer

The offer is made only when R8 is "ask the team" in at least one environment whose namespace is known. R8 is "ask the team" when R1 is pass, warn, or "ask the team". When R1 fails, R8 does not apply, and that environment gives no reason to offer.

1. **The namespaces.** Take the namespace of each workload in each environment where R8 is "ask the team". Leave out a namespace that is unknown (`-`). Write each name once, in the order the report gives the environments. These are the only namespaces the pass reads.
2. **The context.** Run:

   ```sh
   sh <skill-dir>/scripts/read-cluster-usage.sh --context
   ```

   It runs `kubectl config current-context`, which reads the local kubeconfig and sends no request to the cluster (`fields.md`, step 1). This is the only cluster script command that runs before a yes.

   | Result | What it means | What to do |
   | --- | --- | --- |
   | Exit code 0 and a name | The current context | Make the offer with that name. |
   | Exit code 0 and `other` | A context exists, and its name does not fit the shape the script passes on, so the namespace mode would stop | No offer. Under "Not checked": "R8: no cluster offer, because the current context name does not fit the shape the cluster script passes on." |
   | Exit code 5 | `kubectl` is not installed, or it has no current context. The script says which on standard error: `kubectl is not installed`, `kubectl config current-context failed`, or `kubectl config current-context printed no context name` | No offer. Under "Not checked": "R8: no cluster offer, because" and the reason in plain words. |
   | Exit code 2 | A wrong argument | Fix the command. |

Run nothing else with `kubectl` before a yes, and nothing with `kubectl` outside the script at any time.

## The offer

One offer, made once, as the last lines of the reply, after the closing line of the report and after the offer of the questions when both are made. For several namespaces:

"R8 needs measured use. I can read CPU and memory from the cluster context `<name>` with kubectl, read-only, for the namespaces `<list>` and no others. kubectl runs with your own settings: your kubeconfig, your identity, and your kuberc file, which the script leaves on. It reads no Secret and changes nothing. Shall I? (yes or no)"

For one namespace, "for the namespace `<namespace>` and no other". `<list>` is the names joined with commas, each in backticks. With no answer, or a no, the report is the result, and R8 stays "ask the team".

## After a yes

1. **Run the one command,** with the namespaces of the offer, in the same order, and nothing else:

   ```sh
   sh <skill-dir>/scripts/read-cluster-usage.sh <namespace> [<namespace> ...]
   ```

   Run it once. Do not run it again for a namespace that failed, and run no other `kubectl` command.
2. **Read the first line.** It is `# context <name>`. When that name is not the name in the offer, stop. Print nothing from that run as findings, and say: "The cluster script read the context `<name from the script>`, not `<name from the offer>`, so nothing from that run is reported."
3. **Read the exit code.**

   | Exit code | What it means | What to report |
   | --- | --- | --- |
   | 0 | Every namespace was read | The block "Measured in the cluster". |
   | 2 | An argument is not a namespace name, and no command ran | Fix the command: pass only the namespaces of the offer. |
   | 5 | `kubectl` is missing, or the context could not be read or does not fit its shape. Nothing ran after step 1 of the script | "The cluster pass did not run:" and the reason in plain words. No block. |
   | 6 | `kubectl top pod` failed for one namespace, so no metrics were read there: a missing metrics source, no access, or no answer, and the script cannot tell which. That namespace and every one after it were not read | The block, with the tables of the namespaces before it, and the line "Not read: `<namespaces>`, because `kubectl top pod` failed for `<namespace>` (a missing metrics source, no access, or no answer)." |
   | any other | The script stopped with its own message | "The cluster pass stopped:" and the message in plain words. Print nothing from that run as findings. |

4. **Print the block** "Measured in the cluster" in the shape of [report-format.md](report-format.md), after the report. Read the output with the next two sections.

## What the script prints

The script never prints a line of `kubectl` output as it came. Every line is either its own text, which starts with `#`, or a row of one of three tables, which starts with the word `container`, `vpa`, or `hpa`. Columns are separated by one space.

**The opening lines,** once for the run:

- `# context <name>`: the context every command used (see "After a yes", step 2).
- `# Measured in the cluster: one sample from kubectl top, which is one moment in time.`
- `# Values: ...`: the meaning of `-`, `other`, and `not-read`, below.
- `# POD_LAST_END ...`: the last termination reason is given for the pod, not for a container.

**For each namespace,** in the order given:

- `# namespace <name>`
- The container table: its header `# container POD CONTAINER CPU_REQ CPU_LIM MEM_REQ MEM_LIM CPU_USED MEM_USED RESTARTS POD_LAST_END`, then one row for each container of each pod: the word `container` and the ten columns. When the pod query failed, the line `# pods: not read, the query failed` follows the header, and every `top` row prints `not-read` in each column it could not fill. When the namespace has no pod, the line is `# pods: none in this namespace`.
- The VerticalPodAutoscaler table: its header `# vpa VPA TARGET_KIND TARGET MODE CONTAINER CPU_TARGET MEM_TARGET CPU_LOWER MEM_LOWER CPU_UPPER MEM_UPPER`, then the word `vpa` and the eleven columns, one row for each container the recommendation names. Or one of `# vpa: none in this namespace` and `# vpa: not read, the query failed or the server has no such type`.
- The HorizontalPodAutoscaler table: its header `# hpa HPA TARGET_KIND TARGET MIN MAX CURRENT DESIRED METRIC_TYPE METRIC UTILIZATION`, then the word `hpa` and the ten columns, one row for each metric. Or one of `# hpa: none in this namespace` and `# hpa: not read, the query failed or the server has no such type`.
- `# rows not placed: top=N pods=N vpa=N hpa=N`: rows the script saw and could not place, and so did not print. A count above 0 goes in the block.

**The columns.**

| Column | What it holds | Where it comes from |
| --- | --- | --- |
| `POD` | The pod's name | The pod list |
| `CONTAINER` | The container's name. Only `containers` are read, not init containers | The pod list |
| `CPU_REQ`, `CPU_LIM`, `MEM_REQ`, `MEM_LIM` | The request and limit the running pod carries, which can differ from the repository's | The pod list, from the cluster |
| `CPU_USED`, `MEM_USED` | Measured use at the moment of the sample | `kubectl top pod --containers` |
| `RESTARTS` | How many times the container restarted | The pod's status |
| `POD_LAST_END` | The reason of the last termination of any container of the pod, for the pod as a whole. `OOMKilled` is the reason Kubernetes gives for a container killed for memory | The pod's status |
| `VPA`, `TARGET_KIND`, `TARGET`, `MODE` | A VerticalPodAutoscaler, the kind and name of what it targets, and its update mode | The VPA list |
| `CONTAINER`, `CPU_TARGET`, `MEM_TARGET`, `CPU_LOWER`, `MEM_LOWER`, `CPU_UPPER`, `MEM_UPPER` (in a `vpa` row) | The VerticalPodAutoscaler's own recommendation for one container: its target, lower bound, and upper bound | The VPA's status |
| `HPA`, `TARGET_KIND`, `TARGET`, `MIN`, `MAX`, `CURRENT`, `DESIRED` | A HorizontalPodAutoscaler, its target, its replica range, the replicas it last saw, and the replicas it last calculated | The HPA list |
| `METRIC_TYPE`, `METRIC`, `UTILIZATION` (in an `hpa` row) | One metric: its type, the resource, and the average utilisation it aims at | The HPA list |

**The values.** Each cell is one of four things:

- **The value as `kubectl` printed it,** when it fits the shape of its column. Quote it as it is, with its unit (`100m`, `128Mi`, `262144k`).
- **`-`:** no value is set (in a request, a limit, or a VPA column), or nothing was measured (in `CPU_USED` or `MEM_USED`). Only a `-` in `CPU_USED` or `MEM_USED` means that nothing was measured. A pod created a few minutes before can have no metrics yet (`fields.md`, step 2).
- **`other`:** a value was seen and does not fit its shape. Write "a value was seen and not read". Never "nothing measured".
- **`not-read`:** a value was seen and cannot be placed on one container. Write "a value was seen and could not be placed". Never "nothing measured".

A count above 0 in `# rows not placed` is never "nothing measured" either: name the namespace and the count. A `# vpa: not read` or `# hpa: not read` line is never "none in this namespace".

## Matching a row to the repository

- **A container row.** A pod names no workload in these columns, so match a row to a workload by its namespace and its container name, and label the match as an assumption. When two workloads of one namespace have a container of the same name, say that the row matches either one.
- **A `vpa` row.** Match it by `TARGET_KIND` and `TARGET`, and a container by `CONTAINER`.
- **An `hpa` row.** Match it by `TARGET_KIND` and `TARGET`. A `Rollout` can be its target.
- **The repository's side.** Next to each row, give the `cpu-request` and `memory-request` of the matched container from the environment of that namespace, with the field line, or "not found in the repository".

## What the block says, and what it never says

The block is labelled "measured in the cluster", and it says that one sample from `kubectl top` is one moment in time.

**It says:**

- For each container, the request and the limit in the repository, the request and the limit the running pod carries, and the measured use, side by side, each value as printed.
- A VerticalPodAutoscaler's recommendation, quoted from its `vpa` row as it is, beside the request, as that autoscaler's own figure.
- Each pod with `POD_LAST_END` of `OOMKilled`, as "killed for memory" for the pod, with its `RESTARTS`, and not for one container.
- Each namespace or table that was not read, and each count of rows not placed.

**It never says:**

- What a request or a limit should be, a value of its own, a ratio, a percentage, or a difference worked out from two figures.
- Whether the running pod matches the repository. Comparing the cluster with the repository is not part of this skill, so the two requests stand side by side with no comment.
- That a request is too large or too small, or by how much.
- A saving or a cost.
- That one sample shows a peak, an average, or normal use.
- Anything that changes R8, another status, a headline, a verdict, or the first three.

A gap between a request and measured use is for the team to read, over more than one moment and with their own metrics. The block gives the figures and their source, and leaves the decision to them.
