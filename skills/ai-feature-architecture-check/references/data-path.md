# The data path

The ten stops and the eight leak paths come from https://www.netninjas.us/events/ai-data-path-map and stay as published there, in UK spelling.

## The ten stops

| Stop | What I check there |
| --- | --- |
| Client and API | What the request carries, and which fields the feature really needs. |
| Policy gateway | Which identifiers get removed or pseudonymised, and where the lookup table lives. |
| Prompt builder | Whether the finished prompt still holds a name, a date of birth, or a record number. |
| Retrieval and vector store | Which sources the embeddings came from, and whether a deleted record leaves the index. |
| Model endpoint | The region of the endpoint, and what the provider keeps and for how long. |
| Response handling | Where re-identification happens, and who approves the draft. |
| Application logs | Whether prompts or responses appear in a log line. |
| Tracing and error tracking | Whether request bodies travel to a tool outside our approved regions. |
| Evaluation sets | Whether test cases hold real records or synthetic ones. |
| Backups and snapshots | Whether copies of the stores above stay in the same region. |

## The eight leak paths

Each one is a statement that should hold. A pass means that the path is closed.

1. Prompts and responses stay out of our application logs.
2. Our tracing and error tools don't capture request bodies.
3. The model endpoint is pinned to one region.
4. We know what the model provider keeps, and for how long.
5. The pseudonymisation table sits apart from the prompts.
6. A deleted record also leaves the vector store.
7. Our evaluation sets hold synthetic or anonymised cases.
8. Backups and snapshots stay in the approved regions.

## How to fill the map

Follow one request for each AI feature, from the entry point to the last place its data rests. For each stop, write which personal data fields reach it, by field name, with the path and the line. Use the schema, the types, and the prompt builder to name the fields: name, email, phone, address, date of birth, record numbers, free text that a person wrote, and anything the schema marks as personal.

- A stop the feature does not have is written as "not present", with the consequence when there is one: no policy gateway means that the request reaches the prompt builder as it arrived.
- Where a stop's region is set in a file, give the region and the line. Where it is not, write "not set in the repository".
- Never quote a value. Read env files with the names-only filter of ground rule 5.
- For an evaluation set, read field names only: `head -c 2000 <file> | grep -oE '"[A-Za-z_]+"[[:space:]]*:' | sort -u`. Never print a record.

## Evidence rules for the leak paths

Each leak path gets one status and no points. The statuses are the four from [checks.md](checks.md), with two differences that hold for the leak paths only:

- "ask the team" also covers what a repository cannot show at all, such as a provider's retention period.
- A leak path whose stop does not exist passes, and the evidence says what was not found: "no vector store found in the repository".

With several features, the weakest status counts: fail, warn, ask the team, pass.

| # | Pass | Fail | Otherwise |
| --- | --- | --- | --- |
| 1 | No log call receives a prompt, a message list, or a completion. Log lines carry identifiers and versions | A log call receives one of them. Give each call site | None |
| 2 | No tracing or error tracking tool is found. Or body capture is off in code, or scrubbing rules in code cover the prompt and the response | An error tracker, a tracer, or a model tracing tool is set in code to capture request bodies, default personal data, or message content | Ask the team when the tool is present and its capture settings are not in the repository |
| 3 | The client or the gateway sets a region, or a regional host, for every call | A host with no region in its name, a global endpoint, or a cross-region profile | Ask the team when the region comes from an environment variable whose value is not in the repository |
| 4 | Only when a file in the repository sets the provider's retention, which is rare | Never from code | Ask the team. This is the usual status |
| 5 | Check 4 passes without tokens, so there is no lookup to keep apart. Or a pseudonymisation step exists, and its lookup lives in a store apart from the prompts and the logs | Check 4 is fail or warn and no pseudonymisation step exists. Or the lookup sits beside the prompts | Ask the team when the step exists and the separation of access is not visible |
| 6 | No retrieval and no vector store are found. Or the path that deletes a person or a record also deletes the embeddings, caches, and summaries built from it | A delete path exists and leaves them | Ask the team when no delete path is found |
| 7 | No evaluation set is found, or its fields hold no personal data. Or the set is marked as synthetic in a field that code reads, or a script in the repository generates it | Never from code | Warn, labelled as an assumption, when the field names are personal data fields and nothing generates the set. Judge by field names. A marker inside a record is a value, and it is not evidence |
| 8 | Infrastructure code keeps every store and every copy in one region | A copy leaves the regions that a file in the repository names as approved | Ask the team when a copy goes to a second region, naming both regions, or when there is no infrastructure code |

Questions that come from the leak paths are listed in the report under "Questions for the team". The second pass does not ask them, and they are not counted in M.
