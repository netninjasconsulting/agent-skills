# Branch B documentation review

Reviewed commit: 32b65a1. Base: 2c244d9. References below are original branch line numbers. Modified from the Net Ninjas original during independent review on 15 November 2026.

## Critical: env names filter prints part of a value

`skills/ai-feature-architecture-check/SKILL.md:26` and `skills/handover-runbook-generator/SKILL.md:22` promise names only, but the sed command treats assignment-shaped lines inside quoted values as variable names. A credential therefore enters the agent context despite following the skill. Input `.env`:

```dotenv
PRIVATE_KEY="first
FIXTUREVALUE=value-shaped-line
last"
```

Exact original output lines:

```text
PRIVATE_KEY=
FIXTUREVALUE=
```

The second output line is part of the secret value. Replace the stateless line filter with quote tracking. Applied to both skills. The expanded names-filter suite fails against the original commands in both skills, and passes after the fix.


## Important

1. `skills/ai-feature-architecture-check/references/checks.md:29`, `:59`, `:82`, `:93`, `:135`, `:149`: the status rules overlap or leave gaps. A tenant-scoped overread satisfies both check 1 Pass and Warn. A step that removes one unnecessary identifier but leaves another satisfies check 4 Warn and Fail. One tenant-filtered query and one unfiltered tenant-data query satisfies check 6 Warn and Fail. One production gateway plus one test call satisfies check 7 Warn and Fail. All five trace fields in an explicitly mutable store satisfies no check 11 specific rule. Tenant/action/token metering missing only model or timestamp satisfies no check 12 specific rule. Two reviewers can give different scores from identical code. Fix: explicit priority for specific rules, tighten disjoint conditions, and cover missing cases. Applied.

2. `skills/ai-feature-architecture-check/references/checks.md:69`: CODEOWNERS alone passes required source review. GitHub requires a branch rule that specifically requires code owner review; merely having CODEOWNERS requests reviewers. A source can therefore change without approval while receiving a pass. Fix: require enforcement evidence and otherwise ask the team. Applied. Primary source: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners .

3. `skills/ai-feature-architecture-check/references/data-path.md:54`, `:55`, `:57`, `:59`, `:60`: leak path table overlaps and an unsafe synthetic-data shortcut. Body capture off plus model message capture on fits both Pass and Fail for path 2. An explicit region `global` fits Pass and Fail for path 3. A separate pseudonym lookup store with invisible access separation fits Pass and Ask for path 5. Any script that copies real records is a generator and passes path 7, despite preserving personal data. One copy region excluded by a configured approved set fits both Pass and Fail for path 8; conversely two explicitly approved regions cannot pass. Fix: require safe settings for all destinations, specific non-global region pinning, evidenced access separation, genuinely synthetic generation or demonstrated anonymisation, and compare regions with the approved set. Applied.

4. `skills/ai-feature-architecture-check/references/checks.md:101`: any return path without a model response can pass resilience, including returning only HTTP 500. That does not establish that the core product still works. Fix: fallback must complete the core operation without the model. Applied.

5. `skills/ai-feature-architecture-check/references/signals.md:84`: OpenTelemetry capture guidance treats legacy `true` as a current capture value and cites an old instrumentation README without marking it older. That README now deprecates `opentelemetry-instrumentation-openai-v2`; replacement `opentelemetry-instrumentation-genai-openai` 1.3b0 documents only `span_only`, `event_only`, `span_and_event`, and `no_content`. Users can misjudge capture settings by applying the wrong package's semantics. Fix: split current and older guidance and follow the installed implementation. Applied. Primary sources: https://pypi.org/project/opentelemetry-instrumentation-genai-openai/ and https://github.com/open-telemetry/opentelemetry-python-contrib/blob/main/instrumentation-genai/opentelemetry-instrumentation-openai-v2/README.rst .

## Minor

6. `skills/ai-feature-architecture-check/references/signals.md:62`: the OpenSearch Python name given for source search is the distribution `opensearch-py`; real imports use `opensearchpy`. A repository without its dependency manifest can hide this retrieval path. Added `opensearchpy` and `OpenSearch`. Primary source: https://docs.opensearch.org/latest/clients/python-low-level/ .

7. `skills/ai-feature-architecture-check/references/signals.md:32`: the only local inference family named is Ollama. vLLM offline inference can use `from vllm import LLM` and `llm.generate` without a remote SDK or provider host, so the initial search can miss a whole feature. Added vLLM. This is a starting list, so the omission alone is not proof that a compliant reviewer must miss the feature. Primary source: https://docs.vllm.ai/en/latest/getting_started/quickstart/ .

8. `tests/fixtures/ai-feature-architecture-check/EXPECTED.md:40`: the fixture requires saying that Sentry receives details of the signed-in application user, but `lib/sentry.ts` never sets a user and the session object is not sent to Sentry. Request data, headers, and IP are evidenced; application user identity is not. Corrected the expectation.

9. `tests/fixtures/ai-feature-architecture-check/EXPECTED.md:34`: it says there is no timeout at either model call. Anthropic SDK 0.60.0, matching the declared dependency range, has a documented default timeout. The summarise fetch still has no timeout or fallback and the aggregate remains Fail. Corrected the explanation so reviewers must consider SDK defaults. Primary source: npm tarball https://registry.npmjs.org/@anthropic-ai/sdk/-/sdk-0.60.0.tgz , README Timeouts section; default ten minutes, with dynamic calculation for large max_tokens.

10. `skills/ai-feature-architecture-check/references/checks.md:122`, `:135`, `:149`: no-consequential-action output has no specific check 10 status; a separate log account alone is treated as immutable; and cost Warn omits missing model/timestamp. Added explicit cases and permissions evidence. Check 1's no-query case is resolved by evaluating applicable operations, and no-personal-data prompts now have an explicit check 4 Pass case.

## Per-check boundary exercise

| Check | Input exercised by reasoning | Original result |
| --- | --- | --- |
| 1 | Identity plus tenant filter, but unauthorised same-tenant rows | Pass and Warn |
| 2 | Visible AI notice, no machine-readable mark | Warn only; no gap found |
| 3 | Sign-in first, schema validation after prompt | Warn only; no gap found |
| 4 | One unnecessary personal field removed, another remains | Warn and Fail |
| 5 | Owned allowlist, query restricted, CODEOWNERS but no approval rule | Pass despite no enforced review |
| 6 | One filtered retrieval query, one unfiltered, tenant data model | Warn and Fail |
| 7 | One production call module plus one test call | Warn and Fail |
| 8 | Timeout plus only an error response | Pass despite core operation failing |
| 9 | Set and command exist, missing CI or failing threshold | Warn only; no partition gap found |
| 10 | Internal ephemeral output with no action or customer delivery | No specific status |
| 11 | Complete trace, feature can edit store | No specific status |
| 12 | Tenant, action, three token columns, timestamp; model missing | No specific status |

## Per-leak boundary exercise

| Path | Input exercised by reasoning | Original result |
| --- | --- | --- |
| 1 | One unsafe application log among safe logs | Fail only; no gap found |
| 2 | Request bodies disabled, message capture enabled | Pass and Fail |
| 3 | `location = "global"` | Pass and Fail |
| 4 | README-only retention claim | Literal file rule can pass despite no effective provider setting |
| 5 | Separate store, permission separation not shown | Pass and Ask |
| 6 | Delete path leaves embeddings | Fail only; no gap found |
| 7 | Script copies real source records into cases | Unsafe Pass |
| 8 | One region outside explicit approved set | Pass and Fail |

## Primary-source spot checks

Read the registry/PyPI package metadata and README; where npm supplied no README, read the published tarball. No package was installed or run. The following are distinct rows in signals.md, not a claim to have checked every signal within a combined row.

| Row | Source read | Result |
| --- | --- | --- |
| Anthropic | https://registry.npmjs.org/@anthropic-ai%2fsdk , 1.8.0 README | Package and messages.create match |
| OpenAI | https://registry.npmjs.org/openai , 7.57.0 README | SDK, chat.completions.create, responses.create match |
| Bedrock | https://registry.npmjs.org/@aws-sdk%2fclient-bedrock-runtime , 3.1169.0 README | Package and command family match |
| Google | https://registry.npmjs.org/@google%2fgenai , 3.3.0 README | Package and generateContent match |
| Google older | https://registry.npmjs.org/@google%2fgenerative-ai , 0.24.1 README | Deprecated package correctly labelled older |
| Azure OpenAI | https://registry.npmjs.org/@azure%2fopenai/2.0.0 , tarball README | AzureOpenAI comes from openai as described |
| Local models | https://registry.npmjs.org/ollama , 0.6.4 README | Package/port match; missing vLLM added |
| Framework wrappers | https://registry.npmjs.org/ai/7.0.173 , dist/index.d.ts | generateText and streamText match |
| LiteLLM | https://pypi.org/pypi/litellm/json , 1.109.1 README | litellm import and router match |
| Portkey | https://registry.npmjs.org/portkey-ai , 3.1.0 README | portkey-ai import matches |
| Pinecone | https://registry.npmjs.org/@pinecone-database%2fpinecone , 9.2.0 README | Package matches |
| Weaviate | https://registry.npmjs.org/weaviate-client , 3.15.3 README | Package matches |
| Qdrant | https://registry.npmjs.org/@qdrant%2fjs-client-rest/1.20.0 , tarball README | Package and QdrantClient match |
| Chroma | https://registry.npmjs.org/chromadb , 3.5.0 README | Package matches |
| Milvus | https://pypi.org/pypi/pymilvus/json , 3.0.3 README | Package matches |
| OpenSearch | https://docs.opensearch.org/latest/clients/python-low-level/ | Wrong source-import signal corrected: opensearchpy |
| Sentry JavaScript | https://docs.sentry.io/platforms/javascript/configuration/options/ | dataCollection, v11 default behaviour, older sendDefaultPii guidance match |
| OpenTelemetry | https://pypi.org/project/opentelemetry-instrumentation-genai-openai/ | Stale source/current-mode description corrected |
| LangSmith | https://pypi.org/pypi/langsmith/json , 0.14.17 README | Package and traceable match |
| Langfuse older | https://registry.npmjs.org/langfuse , 3.39.2 README | Correctly labelled deprecated; current scoped packages match README |
| DeepEval | https://pypi.org/pypi/deepeval/json , 4.3.4 README | Package and test command match |

## Fixture hand review before EXPECTED

I read the skill and references, then all implementation files, excluding record values and env values, and derived this status vector before opening EXPECTED: fail/pass/warn/fail/ask/fail/fail/fail/warn/fail/warn/fail. Score 1/12, one team question. Leak statuses: fail/fail/fail/ask/fail/fail/warn/ask. This agrees with EXPECTED's aggregate statuses. The SDK default timeout and Sentry user-detail claims above do not follow from the code. No application or evaluation code was run. Built the fixture at `/tmp/b-review-user-fixture` with an empty inherited environment, scratch HOME, and system Git configuration disabled. Its Git status stayed empty. Parent handles the names-only filter separately. The code-reading run declined a second pass, so no team answers changed the score.

## Claims that do not hold

- The status rules do not reliably assign one status to every input, as shown above.
- Treating the OpenTelemetry capture modes as one current list is unsupported by the current vendor source. The vendor page actually cited is now deprecated.
- EXPECTED's absence of both timeouts and its signed-in-user capture requirement are not established by the fixture.
- A CODEOWNERS entry alone does not establish required review.

## Published-page comparison

The web retrieval tool and Python urllib initially failed, but curl with a browser User-Agent successfully fetched all three live pages. All twelve labels, all three score-band sentences, all ten stop labels and descriptions, and all eight leak-path labels match, allowing the intended UK spelling. Check 4's first detail sentence is omitted and that omission is explicitly declared. The cost SQL matches the published preformatted block byte for byte after stripping surrounding whitespace. Sources: https://www.netninjas.us/events/six-layer-ai-architecture-checklist , https://www.netninjas.us/events/ai-data-path-map , https://www.netninjas.us/events/cost-per-ai-action-worksheet . The substantive pass-rule gaps above remain: for example check 8's original error-only return path did not establish the published resilience statement.

## Not judged

The checked-in cost query was compared with the published query but was not executed against a live database. No model, app, evaluation runner, or production console was called. Console state is outside this repository review.

## Fixes applied

Edited SKILL.md, references/checks.md, references/data-path.md, references/signals.md, fixture EXPECTED.md, and fixture scenarios.md. Pinned published check labels, band wording, stop names, leak labels, and SQL were kept. Added boundary scenarios that can be judged without calling a model. Fixes are included in the branch review commit.

Verdict at reviewed commit: not ready to merge because scoring and leak-path rules can give contradictory or unsafe results.

# Branch B validator review

Reviewed original commit 32b65a14c17acfccca40ea5e1749115f43f5806b. All line numbers below refer to that commit.

## Important: wording checks ignore order, active Markdown, and exact query extent

`scripts/validate.mjs:265`, `:269`, `:274`, `:277`, `:282`, `:285` use membership or prefix tests. They do not establish that the displayed structures appear once, in the published order, in the intended section. The query comparison stops after its last expected line and never checks the closing code fence.

Why it matters: CI can report success after a published checklist is reordered or a changed live check is accompanied by an old copy inside a code example. It can also approve SQL appended to the published query. This contradicts the PR description and CHANGELOG's broad pinning claim. This is integrity of the skill's advertised wording, not a claim of arbitrary command execution.

Suggested and implemented fix: extract the relevant Markdown sections; discard HTML comments and backtick/tilde fenced code examples for prose checks; compare the complete ordered list, heading list, band rows, stop rows, leak-path list, and column-name sequence; require the query to occupy exactly one complete SQL fence with exactly the expected lines.

## Actual mutations of the original branch

The test runner archived the original commit into `/tmp/agent-review-run/validator-original`, copied it into a disposable folder, verified that the unchanged copy exits 0, then changed one item at a time and ran the validator. No credentials were used.

| Mutation | Original validator | Fixed validator |
| --- | --- | --- |
| Reword first check (`works` to `runs`) | Rejected, exit 1 | Rejected |
| Renumber first check from 1 to 21 | Rejected, exit 1 | Rejected |
| Swap first two checklist entries | Accepted, exit 0 | Rejected |
| Reword first check, append original inside a backtick code fence | Accepted, exit 0 | Rejected |
| Reword first check, append original inside an HTML comment | Accepted, exit 0 | Rejected |
| Reword first check, append original inside a tilde code fence | Accepted, exit 0 | Rejected |
| Duplicate first check | Accepted, exit 0 | Rejected |
| Rename table column `tenant_id` to `customer_id` | Rejected, exit 1 | Rejected |
| Swap first two cost-column rows | Accepted, exit 0 | Rejected |
| Swap first two stops | Accepted, exit 0 | Rejected |
| Change stop description from `really needs` to `uses` | Accepted, exit 0 | Rejected |
| Swap first two numbered leak paths without changing their numbers | Accepted, exit 0 | Rejected |
| Change query interval from 30 to 60 days | Rejected, exit 1 | Rejected |
| Append `SELECT 1;` after the query before the code fence closes | Accepted, exit 0 | Rejected |

New regression runner: `node tests/validate.test.mjs`. It copies the repository, restores each changed file after each case, enforces a 10-second timeout per invocation, and removes the scratch directory. The runner itself fails against the original validator, confirming that these are effective mutation tests. All fourteen checks pass against the corrected validator, and `node scripts/validate.mjs` passes on the unmodified working tree. Both JavaScript files pass `node --check`.

## Changes and remaining scope

Only `scripts/validate.mjs` and the new `tests/validate.test.mjs` were changed by this reviewer. Parent should wire the new test into CI and documented checks. The nine Agent Permissions rows in the shared validator still use membership checks; this focused assignment covered the new Branch B pins only. Independent comparison of the constants with the live published pages belongs to the documentation review.

## Claims that do not hold: PR 7, changelog, and results

- PR 7 and CHANGELOG.md say the validator pins the published wording; ten accepted mutations show that ordering, active placement, uniqueness, and query extent were not pinned. Four straightforward mutations were correctly rejected.
- PR 7 says status gaps inside checks 1, 3, 5, 9, 10, 11, and 12 were closed. Boundary exercises above still find gaps or overlaps in 1, 10, 11, and 12, and unsafe required-review evidence in 5. No new partition gap was found in 3 or 9.
- The two skills and PR 7 say the stricter names filter prints no later lines of multiline values. The exact counterexample above disproves that claim.
- The vendor-read claim does not establish that all listed names are current or appropriate source-import terms: OpenSearch and OpenTelemetry counterexamples are above. Historical statements that a vendor page was read on a particular date cannot be disproved from these files alone.
- EXPECTED.md's assertion of no model timeout ignores the declared SDK default, and its Sentry application-user statement is unsupported. Historical fixture passes in tests/RESULTS.md therefore do not validate those explanations. The aggregate statuses still follow.

## Not judged: additional limits

- No model calls, deployment, real application traffic, real credentials, or live provider configuration were exercised. Vendor facts were read, not tested against paid services.
- No complete conversational end-to-end skill run or timing of the second-pass offer was tested. The fixture was built and worked manually before EXPECTED.md, with no to gh and policy writing.
- No comprehensive semantic SQL validation was performed. The published query was compared exactly and the validator was mutation-tested.
- The spot check covers 21 rows, not every individual name in every row.

## Final verdict

Branch B at 32b65a1 is not ready to merge because it can leak an env value and give contradictory scores; the accompanying fixes address the reproduced cases and include mutation regressions.
