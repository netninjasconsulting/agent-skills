# The reach map

One row for each workload in each environment: what it can reach, from what the repository shows. The reach map is a record, not a score. It changes no status and no verdict. The field names are those of [fields.md](fields.md), and the rules for "not found", for absent fields, and for a `Rollout` with `workloadRef` are those of [checks.md](checks.md).

## The columns

| Column | What it holds | Fields |
| --- | --- | --- |
| Workload | The environment, `<kind>/<namespace>/<name>`, and the file and line of `object=present`. A `Rollout` with `workloadRef` and its Deployment share one row that names both | `object`, `workload-ref-kind`, `workload-ref-name` |
| ServiceAccount | The account the pod runs as, and whether its token is mounted | `service-account` and `automount-sa-token` on the pod; `automount-sa-token` on the ServiceAccount object of that name |
| Roles and what they allow | Each binding that names the account, the role it binds, and that role's rules as verbs, resources, and API groups | `subject.<n>.kind`, `subject.<n>.name`, `subject.<n>.namespace`, `role-ref-kind`, `role-ref-name`; on the role: `rule.<n>.verb`, `rule.<n>.resource`, `rule.<n>.api-group`, `rule.<n>.resource-names-count`, `rule.<n>.non-resource-urls-count`, `aggregation-rule` |
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
| ServiceAccount | An account of its own, not `default`, with its token off | The `default` account, or an account shared with another workload, with its token on or not set | `service-account` or an `automount-sa-token` that applies is `other`, or the workload is not read or not rendered |
| Roles and what they allow | No binding names the account, or every bound rule names its verbs and resources with no `*` and is not a K6 warn | A bound rule is a K6 fail or a K6 warn | A binding names a role that is not in the environment, a bound ClusterRole prints `aggregation-rule=present`, or a rule field is `other` |
| Peers in | A policy selects the workload for ingress and names its peers | No policy selects the workload for ingress (all sources are allowed, K18), or a peer is an `ip-block` of `0.0.0.0/0` or `::/0`, or `namespace-selector=all` with no `pod-selector` | Whether a policy selects the workload cannot be decided, or a rule prints `peers=0` (verify), or a deciding field is `other` |
| Peers out | A policy selects the workload for egress and names its peers | No policy selects the workload for egress (all destinations are allowed, K18), or a peer is as wide as above | The same as "Peers in", for egress |
| Host | No host field is printed | Any of `host-network=true`, `host-pid=true`, `host-ipc=true`, a `hostPath` volume, a `host-port`, `privileged=true`, or a `cap-add` | A host field is `other`, or the workload is not read or not rendered |

"Secrets and ConfigMaps" carries no mark. The names a workload reads are a fact to show, and a reference by name is how a Secret should be used. A role that can read every Secret is marked under "Roles and what they allow".

A row marked "broad" is not a check result. It points to the checks that judge the same fields: K4 for the host, K5 for the account, K6 for the roles, and K8 for the peers in.

## Not in the map

- A binding, a policy, or a ServiceAccount that lives only in the cluster or in another repository. The row is marked from the repository, and the report says so at the top.
- Projected volume sources, and every volume source other than the six the reader reads (see `fields.md`).
- Services, Ingresses, and a service mesh policy. The reader has no field for them.
- Whether the network plugin enforces NetworkPolicy (K18).
