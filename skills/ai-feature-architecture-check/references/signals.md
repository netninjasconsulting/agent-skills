# Signals: what to look for when mapping the feature

This list is a starting point. A call that matches nothing here is still a call, and the map follows the code, in any language.

None of these names was read from a vendor's documentation for this file. The list was written on 15 November 2026 from working knowledge, and names in this field change often. A name that is missing can hide a call site. So the search is a start: after it, read the entry points and follow each one to the place where it reaches a model.

Search from the repository root, and keep env files, variable files, and state files out of the search:

```sh
grep -rnE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
  --exclude='.env*' --exclude='*.env' --exclude='.envrc' --exclude='*.tfvars' --exclude='*.tfstate*' \
  --exclude='*.lock' --exclude='package-lock.json' --exclude='pnpm-lock.yaml' \
  -e '<names, joined with |>' .
```

Then read the files that match. Env files are read only through the names filter of ground rule 5.

## Model calls

| What | Names |
| --- | --- |
| Anthropic | `@anthropic-ai/sdk`, `anthropic`, `messages.create`, `api.anthropic.com` |
| OpenAI and compatible clients | `openai`, `chat.completions.create`, `responses.create`, `api.openai.com`, a `baseURL` or `base_url` that points at another host |
| Amazon Bedrock | `@aws-sdk/client-bedrock-runtime`, `bedrock-runtime`, `InvokeModel`, `Converse` |
| Google | `@google/genai`, `google-genai`, `@google/generative-ai`, `google.generativeai`, `@google-cloud/vertexai`, `aiplatform.googleapis.com`, `generativelanguage.googleapis.com` |
| Azure OpenAI | `@azure/openai`, `AzureOpenAI`, `openai.azure.com` |
| Other hosts | `api.mistral.ai`, `api.groq.com`, `api.together.xyz`, `openrouter.ai`, `api.cohere.com`, `api.x.ai`, `api.deepseek.com`, `api.fireworks.ai` |
| Local models | `ollama`, port `11434` |
| Frameworks that wrap a call | `ai` with `generateText` or `streamText`, `@ai-sdk/`, `langchain`, `@langchain/`, `llama-index`, `llama_index`, `llamaindex` |

A plain HTTP request to one of the hosts is a model call, with or without an SDK.

## Gateways

| What | Names |
| --- | --- |
| A gateway the team wrote | One module that every call site imports. Names such as `gateway`, `llm`, `modelClient`, `aiClient` |
| Hosted or self-run gateways | `litellm`, `portkey`, `helicone`, `gateway.ai.cloudflare.com`, `ai-gateway`, `openrouter` |

The test for check 7 is the number of places that talk to a provider, not the presence of a name.

## Retrieval and vector stores

| What | Names |
| --- | --- |
| pgvector | `vector(` in a schema, the operators `<=>`, `<->`, and `<#>`, `match_documents` |
| Hosted and self-run stores | `@pinecone-database/pinecone`, `pinecone`, `weaviate`, `qdrant`, `chromadb`, `milvus`, `opensearch`, `vectorize`, `@upstash/vector` |
| Embedding calls | `embeddings.create`, `embed`, `embedMany`, `text-embedding` |

## Tools the model can call

| What | Names |
| --- | --- |
| Tool definitions | `tools:`, `tool(`, `function_call`, `tool_use`, `tool_choice`, `input_schema`, MCP client code |

## Logging, tracing, and error tracking

| What | Names, and the setting that captures request bodies |
| --- | --- |
| Application logs | `console.log`, `logger.`, `print(`, `logging.`, with a prompt, a message list, or a completion as an argument |
| Sentry | `@sentry/`, `sentry_sdk`. `sendDefaultPii`, `send_default_pii`, request data integrations |
| OpenTelemetry | `@opentelemetry/`, `opentelemetry`. Content capture switches such as `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` |
| Model tracing tools | `langfuse`, `langsmith`, `LANGSMITH_TRACING`, `LANGCHAIN_TRACING_V2`, `helicone`, `braintrust` |
| Other observability | `dd-trace`, `datadog`, `posthog`, `logtail`, `newrelic` |

## Evaluation sets

| What | Names |
| --- | --- |
| Tools | `promptfoo`, `promptfooconfig`, `braintrust`, `deepeval`, `ragas`, `evals` |
| Files | `evals/`, `eval/`, `*.eval.*`, `golden*`, `cases.json`, `cases.jsonl`, `fixtures/` next to prompts |
| In CI | An evaluation command in a workflow that runs on pull requests and can fail the run |

## Usage and cost

| What | Names |
| --- | --- |
| Token counts on a response | `usage`, `input_tokens`, `output_tokens`, `prompt_tokens`, `completion_tokens`, `cache_read_input_tokens`, `cached_tokens` |
| A request log | A table or a collection that gets one row per model call: `ai_requests`, `llm_requests`, `usage_log`, `model_calls` |

## Regions

| What | Names |
| --- | --- |
| Endpoint region | `region`, `location`, `AWS_REGION`, a regional host name, a `global` or cross-region inference profile |
| Copies | `aws_db_snapshot_copy`, `replication`, `cross_region`, `aws_s3_bucket_replication_configuration`, a second provider block with another region |
