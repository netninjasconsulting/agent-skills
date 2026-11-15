# The data path

The ten stops and the eight leak paths come from https://www.netninjas.us/events/ai-data-path-map and stay as published.

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
