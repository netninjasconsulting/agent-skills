# The reach map

One row for each workload in each environment: what it can reach, from what the repository shows. The reach map is a record, not a score. It changes no status and no verdict. The field names are those of [fields.md](fields.md), and the rules for "not found", for absent fields, and for a `Rollout` with `workloadRef` are those of [checks.md](checks.md).

## The columns

| Column | What it holds | Fields |
| --- | --- | --- |
| Workload | The environment, `<kind>/<namespace>/<name>`, and the file and line of `object=present`. A `Rollout` with `workloadRef` and its Deployment share one row that names both | `object`, `workload-ref-kind`, `workload-ref-name` |
| ServiceAccount | The account the pod runs as, and whether its token is mounted | `service-account` and `automount-sa-token` on the pod; `automount-sa-token` on the ServiceAccount object of that name |
| Roles and what they allow | Each binding that reaches the account (see "How a binding reaches an account"), the role it binds, and that role's rules as verbs, resources, and API groups | `subject.<n>.kind`, `subject.<n>.name`, `subject.<n>.namespace`, `subject.<n>.user-form`, `role-ref-kind`, `role-ref-name`; on the role: `rule.<n>.verb`, `rule.<n>.resource`, `rule.<n>.api-group`, `rule.<n>.resource-names-count`, `rule.<n>.non-resource-urls-count`, `aggregation-rule` |
| Secrets and ConfigMaps | Every Secret and ConfigMap the workload names, by name, and how: one key, all keys, or a volume | `env-ref.<NAME>` (with `env.<NAME>=secretKeyRef` or `configMapKeyRef`), `env-from-secret`, `env-from-configmap`, `secret-volume-name`, `configmap-volume-name` |
| Peers in | The sources the NetworkPolicies that select the workload allow in, with their ports | `np-pod-selector`, `np-pod-label.<key>`, `np-policy-type`, `np-ingress-rules`, `np-ingress.<r>.peers`, `np-ingress.<r>.peer.<p>.*`, `np-ingress.<r>.port`, `np-ingress.<r>.end-port`, `np-ingress.<r>.protocol`; on the workload: `pod-label.<key>` |
| Peers out | The destinations the same policies allow out, with their ports | the `np-egress.*` lines of the same policies, and `np-policy-type` |
| Host | Every access to the node | `host-network`, `host-pid`, `host-ipc`, `volume-type=hostPath` with `host-path` and `mount.<volume-name>`, `host-port`, `privileged`, `cap-add` |

A policy selects a workload as K8 in `checks.md` says. A ServiceAccount named by a pod, and a Secret or ConfigMap named by a workload, may have no object in the environment. The cell says "made outside the repository" for it, and names it all the same.

The map never shows a value: names, words, counts, and the field lines that carry them.

## The three marks

Each cell other than "Workload" and "Secrets and ConfigMaps" gets one mark, and the row takes the widest of its cells: "broad", then "not found in the repository", then "confined".

| Column | confined | broad | not found in the repository |
| --- | --- | --- | --- |
| ServiceAccount | An account of its own, not `default`, with its token off; or the `default` account, or a shared one, with its token off (no token, so no API access through it) | The `default` account, or an account shared with another workload, with its token on or not set | An account of its own with its token on or not set (whether the workload calls the API is not in the repository); or `service-account` or an `automount-sa-token` that applies is `other`, or the workload is not read or not rendered |
| Roles and what they allow | No binding of the environment has a `User` subject with `subject.<n>.user-form=other`, and either no binding reaches the account, or every rule bound to it names its verbs and resources with no `*` and is not a K6 warn | A binding that reaches the account binds a rule that is a K6 fail or a K6 warn, or binds the built-in `cluster-admin`, `admin`, or `edit` (verify, see K6) | A binding of the environment has a `User` subject with `subject.<n>.user-form=other` (the reason to give: the form of a `User` name was not read); a binding that reaches the account names a role that is not in the environment; a bound ClusterRole prints `aggregation-rule=present`; or a rule field is `other` |
| Peers in | A policy selects the workload for ingress and names its peers | No policy selects the workload for ingress (all sources are allowed, K18), or a peer is an `ip-block` of `0.0.0.0/0` or `::/0`, or `namespace-selector=all` with no `pod-selector` | Whether a policy selects the workload cannot be decided, or a rule prints `peers=0` (verify), or a deciding field is `other` |
| Peers out | A policy selects the workload for egress and names its peers | No policy selects the workload for egress (all destinations are allowed, K18), or a peer is as wide as above | The same as "Peers in", for egress |
| Host | No host field is printed | Any of `host-network=true`, `host-pid=true`, `host-ipc=true`, a `hostPath` volume, a `host-port`, `privileged=true`, or a `cap-add` | A host field is `other`, or the workload is not read or not rendered |

### How a binding reaches an account

A binding reaches a workload's account by one of three subjects, the same three as the subject rule of K6 in `checks.md`:

- A ServiceAccount subject (`subject.<n>.kind=ServiceAccount`) reaches exactly the account that its `subject.<n>.name` and `subject.<n>.namespace` give, whatever kind of binding holds it and wherever the binding lives.
- A `User` in the service-account form (`subject.<n>.user-form=service-account`) reaches the account of every workload of the environment, whatever the binding's kind or namespace. The reader never prints a `User` name, and the name can give an account in any namespace, so the reader cannot tie the subject to one account.
- A group (`subject.<n>.kind=Group`) reaches the account of every workload of the environment, whatever the binding's kind or namespace. The reader prints no group name, so every group counts.

A `User` with `user-form=other` may be a ServiceAccount in the user form, and the reader could not tell. Every workload of the environment, whatever the binding's kind or namespace, gets "not found in the repository" in this cell, with the reason. A `User` with `user-form=plain` is a person or a system user, and reaches no workload.

The kind of the binding decides only where the rights apply: a RoleBinding gives them inside its own namespace, and a ClusterRoleBinding gives them in the whole cluster. The cell says which. The cost of this rule is that workloads other than the one a binding names are marked too, because the reader does not print the name.

Where "broad" and "not found in the repository" both hold for the cell, the cell is "broad", and it still lists the reason for "not found in the repository".

So the cell is "confined" in two cases only, and in both no binding of the environment has a `User` subject with `user-form=other`. In the first, no binding reaches the account. In the second, every rule that such a binding binds names its verbs and resources with no `*` and is not a K6 warn.

"Secrets and ConfigMaps" carries no mark. The names a workload reads are a fact to show, and a reference by name is how a Secret should be used. A role that can read every Secret is marked under "Roles and what they allow".

**In an environment that is not fully seen** (see "The verdict" in SKILL.md), every column follows one more rule: a cell is "broad" only from a decided fact, a line that decides a check under the verdict rules there (a K7 case, or a fail or a warn of a manifest applied as it is). A cell that would be "confined" is "not found in the repository" instead, with the reason (not rendered, or not read), and so is a cell that would be "broad" from a line that decides nothing. No cell there is "confined".

A row marked "broad" is not a check result. It points to the checks that judge the same fields: K4 for the host, K5 for the account, K6 for the roles, and K8 for the peers in.

## Not in the map

- A binding, a policy, or a ServiceAccount that lives only in the cluster or in another repository. The row is marked from the repository, and the report says so at the top.
- Projected volume sources, and every volume source other than the six the reader reads (see `fields.md`).
- Services, Ingresses, and a service mesh policy. The reader has no field for them.
- Whether the network plugin enforces NetworkPolicy (K18).
