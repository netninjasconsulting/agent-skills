# The twelve checks: evidence rules

The labels are the published ones, as on netninjas.us, in UK spelling. The line under each label is the detail from the published checklist. The detail of check 4 leaves out its first published sentence.

## Statuses

| Status | When |
| --- | --- |
| pass | Every part of the check is met in code, for every AI feature in the repository. |
| warn | Part of the check is met, and the missing part would be in code. |
| fail | The check is not met, or nothing for it is found in the repository. |
| ask the team | The part that code can show is met, and the rest sits outside the code. |

Rules that hold for every check:

- With several features, judge each one. The check gets the weakest status, in this order: fail, warn, ask the team, pass. The evidence names the feature that earned it. One feature that fails a check and one that meets it give a fail.
- A Warn rule describes one feature. "Some" in a Warn rule means some parts of that feature.
- A README, a comment, a document, or a name never passes a check. Only code that runs does.
- "ask the team" is never a softer fail. When the code part is missing, the status is fail or warn, and the question is not asked.
- Only checks 5, 10, 11, and 12 can end in "ask the team". Each has one question, given below, for the second pass.

## Layer 1: product interface

### 1. The AI feature works inside the signed-in user's permissions.

It calls the same APIs as the rest of the product, so it can't read or change more than the person using it.

- **Look at:** every tool the model can call, and every read the feature makes on the way to the prompt.
- **Pass:** each one goes through the product's own API or data layer with the signed-in user's identity, and each query carries the user's or the tenant's condition.
- **Fail:** a tool or a query uses a service key, an admin client, or a database role that ignores the user, or reads a record by ID with no owner or tenant condition.
- **Warn:** every write carries the user's identity, and a read on the way to the prompt is wider than the user's own.

### 2. The interface says it's AI and marks what it generated.

A notice where people talk to the system, and a machine-readable mark on generated content.

- **Look at:** the components that show model output, and the responses that carry it.
- **Pass:** a visible notice or label where the output appears, and a mark a program can read: a response header, a metadata field, an attribute on the element, or provenance metadata in the content.
- **Warn:** one of the two.
- **Fail:** neither.

## Layer 2: access and policy

### 3. Every request passes authentication and validation before a prompt exists.

Size limits, schema checks, and rate limits run in ordinary code, ahead of the model.

- **Look at:** every entry point, in the order its code runs, up to the line that builds the prompt.
- **Pass:** sign-in, a schema check, a size limit, and a rate limit all run before the prompt is built.
- **Warn:** sign-in runs first on every entry point, and a schema check, a size limit, or a rate limit is missing or runs after the prompt is built. For a missing rate limit, add: "A platform rule may exist outside the repository."
- **Fail:** an entry point reaches the prompt builder with no sign-in check.

### 4. A policy step removes or pseudonymises the personal data a task doesn't need.

The model sees a token, and our own system swaps the real value back in.

- **Look at:** what the prompt builder receives, field by field, and anything between the request and the prompt builder that drops or replaces fields.
- **Pass:** a step passes on only the fields the task needs, or replaces identifiers with tokens that the system swaps back afterwards.
- **Warn:** the step drops or replaces some of the personal fields, and others still reach the prompt.
- **Fail:** a whole record, or personal fields the task does not need, go into a prompt. Name the fields. Do not quote a value.

## Layer 3: context retrieval

### 5. Retrieval reads only the sources we approved.

A named list of data sources, each with an owner. A new source goes through review like a code change.

- **Look at:** where the list of sources lives, and whether the retrieval query is limited to it.
- **Pass:** a named list with an owner for each source, a query limited to that list, and a CODEOWNERS entry or another required review that covers the file that holds the list.
- **Ask the team:** the list, the owners, and the limit are in code, and nothing in the repository shows that a change to the list is reviewed.
- **Warn:** a list with no owners, or a query that is not limited to the list.
- **Fail:** retrieval reads whatever the store holds.
- **Question:** "Does a new retrieval source go through review before it is added?"
- A feature with no retrieval passes this check and check 6, with the evidence "no retrieval found in the repository".

### 6. The retrieval service applies the tenant filter in code.

The tenant ID comes from the authenticated session. A prompt that says "only this customer's data" isn't a control.

- **Look at:** every retrieval query, and where its tenant value comes from. Follow the value back to the entry point.
- **Pass:** every query filters by tenant, and the value comes from the session on the server.
- **Fail:** the value comes from the request body, the query string, a header the client sets, or the prompt. Or there is no tenant filter and the data model has tenants.
- **Warn:** within one feature, some queries take the tenant from the session and others have no filter.

## Layer 4: model gateway

### 7. Every model call goes through one gateway.

Our code talks to one interface. The gateway holds the regional endpoints, the quotas, the retries, and the model routing.

- **Look at:** every place that builds a provider client or calls a provider's host. Count them.
- **Pass:** one module talks to a provider, and every feature calls that module.
- **Fail:** two or more places talk to a provider. A plain HTTP request to a provider's host counts.
- **Warn:** one module in the product code, and a second call site in a script or a test.

### 8. The feature still works when the model is slow or down.

A queue, a timeout, and a rules-based fallback. A failed model call delays a suggestion and never blocks the core product.

- **Look at:** each call site: a timeout or an abort signal, what the caller does when the call fails, and whether the surrounding request can finish without it.
- **Pass:** a timeout on every call, and a path that returns without the model.
- **Warn:** one of the two.
- **Fail:** neither.

## Layer 5: quality checks

### 9. An evaluation set from real cases scores every change.

It runs in CI on each prompt or model change, and a lower score blocks the merge.

- **Look at:** the evaluation set, the command that scores it, and the workflows.
- **Pass:** a set, a command, a workflow that runs the command on pull requests, and a threshold that fails the run.
- **Warn:** a set and a command exist, and no workflow runs them, or the run cannot fail.
- **Fail:** no evaluation set is found.
- Whether the cases look real belongs to leak path 7.

### 10. A named person approves the outputs that matter.

Anything that moves money, changes a record, or reaches a customer waits for a human or a deterministic rule.

- **Look at:** every action that follows model output: tools that move money, write a record, or send something to a customer.
- **Pass:** each such action waits in a pending state for an approval that code records, with a role check on who may approve, or it passes a deterministic rule in code, such as a limit or an allow-list. A feature whose only output is a draft that a signed-in person reads and sends passes, with that as the evidence.
- **Ask the team:** the approval step is in code and records the approver, and who may approve is decided outside the code.
- **Fail:** an action runs on the model's output alone.
- **Question:** "Is there a named person, by role, who approves these outputs?"

## Layer 6: operate safely

### 11. Every request leaves a trace we can query.

The request ID, the model and prompt version, the retrieved sources, and the approver, in a log the feature can't edit.

- **Look at:** what each call site writes after the call, and where it writes it.
- **Pass:** every call writes the five fields, to a store that infrastructure code shows the feature cannot change: an append-only table, a write-only role, object lock, or a separate log account.
- **Ask the team:** every call writes the five fields, and nothing in the repository shows whether the feature can change the store.
- **Warn:** some of the five fields. A field that every call writes as empty counts as missing.
- **Fail:** no trace is written.
- **Question:** "Is the trace store protected from edits by the feature itself?"

### 12. We know what one AI action costs, per customer.

Tokens, model, and cache hits per request, joined to the tenant. Pricing and plan limits rest on that number.

- **Look at:** what is recorded after each call. [cost.md](cost.md) has the seven columns.
- **Ask the team:** all seven columns are recorded for every call. Code can show that the number can be computed, and it cannot show that anyone reads it.
- **Warn:** usage is recorded per tenant, and the action or the split into input, cached input, and output tokens is missing.
- **Fail:** usage is not recorded per tenant, or not recorded at all.
- **Question:** "Does someone look at the cost per action for each customer, at least once a month?"

## The first three to change

Take the first three whose status is fail or warn, in this order:

1. Check 6, check 4, check 3.
2. Leak path 1, leak path 2.
3. Check 10.
4. Checks 7, 8, 9, 11, 12, 5, 1, and 2.

This follows the published advice for the lowest band: layers 2 and 3 first. For each of the three, give one sentence on why it comes first and a short code sketch of the fix in the repository's own language, with placeholders where a name is not known.
