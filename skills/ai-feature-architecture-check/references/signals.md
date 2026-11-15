# Signals: what to look for when mapping the feature

This list is a starting point. A call that matches nothing here is still a call, and the map follows the code, in any language.

Every name here is marked "verify". The list was written on 15 November 2026 from working knowledge, and it was not read from each vendor's documentation on that day. Names in this field change often. A name that is out of date costs a search term, and it changes no status.

Search for the names with `grep -rnE` from the repository root, leaving out `node_modules`, build output, and lockfiles. Then read the files that match.

## Model calls

| What | Names | Status |
| --- | --- | --- |
| Anthropic | `@anthropic-ai/sdk`, `anthropic`, `messages.create`, `api.anthropic.com` | verify |
| OpenAI and compatible clients | `openai`, `chat.completions.create`, `responses.create`, `api.openai.com`, a `baseURL` or `base_url` that points at another host | verify |
| Amazon Bedrock | `@aws-sdk/client-bedrock-runtime`, `bedrock-runtime`, `InvokeModel`, `Converse` | verify |
| Google | `@google/genai`, `google-genai`, `@google-cloud/vertexai`, `aiplatform.googleapis.com`, `generativelanguage.googleapis.com` | verify |
| Azure OpenAI | `@azure/openai`, `AzureOpenAI`, `openai.azure.com` | verify |
| Other hosts | `api.mistral.ai`, `api.groq.com`, `api.together.xyz`, `openrouter.ai`, `api.cohere.com` | verify |
| Frameworks that wrap a call | `ai` with `generateText` or `streamText`, `@ai-sdk/`, `langchain`, `@langchain/`, `llama-index`, `llamaindex` | verify |

A plain HTTP request to one of the hosts is a model call, with or without an SDK.

## Gateways

| What | Names | Status |
| --- | --- | --- |
| A gateway the team wrote | One module that every call site imports. Names such as `gateway`, `llm`, `modelClient`, `aiClient` | verify |
| Hosted or self-run gateways | `litellm`, `portkey`, `helicone`, `gateway.ai.cloudflare.com`, `ai-gateway`, `openrouter` | verify |

The test for check 7 is the number of places that talk to a provider, not the presence of a name.

## Retrieval and vector stores

| What | Names | Status |
| --- | --- | --- |
| pgvector | `vector(` in a schema, the operators `<=>`, `<->`, and `<#>`, `match_documents` | verify |
| Hosted and self-run stores | `@pinecone-database/pinecone`, `pinecone`, `weaviate`, `qdrant`, `chromadb`, `milvus`, `opensearch`, `vectorize`, `@upstash/vector` | verify |
| Embedding calls | `embeddings.create`, `embed`, `embedMany`, `text-embedding` | verify |

## Tools the model can call

| What | Names | Status |
| --- | --- | --- |
| Tool definitions | `tools:`, `tool(`, `function_call`, `tool_use`, `tool_choice`, `input_schema`, MCP client code | verify |

## Logging, tracing, and error tracking

| What | Names, and the setting that captures request bodies | Status |
| --- | --- | --- |
| Application logs | `console.log`, `logger.`, `print(`, `logging.`, with a prompt, a message list, or a completion as an argument | verify |
| Sentry | `@sentry/`, `sentry_sdk`. `sendDefaultPii`, `send_default_pii`, request data integrations | verify |
| OpenTelemetry | `@opentelemetry/`, `opentelemetry`. Content capture switches such as `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` | verify |
| Model tracing tools | `langfuse`, `langsmith`, `LANGSMITH_TRACING`, `LANGCHAIN_TRACING_V2`, `helicone`, `braintrust` | verify |
| Other observability | `dd-trace`, `datadog`, `posthog`, `logtail`, `newrelic` | verify |

## Evaluation sets

| What | Names | Status |
| --- | --- | --- |
| Tools | `promptfoo`, `promptfooconfig`, `braintrust`, `deepeval`, `ragas`, `evals` | verify |
| Files | `evals/`, `eval/`, `*.eval.*`, `golden*`, `cases.json`, `cases.jsonl`, `fixtures/` next to prompts | verify |
| In CI | An evaluation command in a workflow that runs on pull requests and can fail the run | verify |

## Usage and cost

| What | Names | Status |
| --- | --- | --- |
| Token counts on a response | `usage`, `input_tokens`, `output_tokens`, `prompt_tokens`, `completion_tokens`, `cache_read_input_tokens`, `cached_tokens` | verify |
| A request log | A table or a collection that gets one row per model call: `ai_requests`, `llm_requests`, `usage_log`, `model_calls` | verify |

## Regions

| What | Names | Status |
| --- | --- | --- |
| Endpoint region | `region`, `location`, `AWS_REGION`, a regional host name, a `global` or cross-region inference profile | verify |
| Copies | `aws_db_snapshot_copy`, `replication`, `cross_region`, `aws_s3_bucket_replication_configuration`, a second provider block with another region | verify |
