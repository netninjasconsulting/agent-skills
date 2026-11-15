# Signals: what to look for when mapping the feature

This list is a starting point. A call that matches nothing here is still a call, and the map follows the code, in any language.

Every name below was read on 15 November 2026 from the vendor's own package, source code, or documentation. The last column of each table says where, with the version that was read. Names in this field change often, and a name that is missing can hide a call site. So the search is a start: after it, read the entry points and follow each one to the place where it reaches a model.

Some names are marked "older". The vendor has replaced them, and code that still runs can still hold them. Search for both.

Search from the repository root, and keep env files, variable files, and state files out of the search:

```sh
grep -rnE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build --exclude-dir=.next \
  --exclude='.env*' --exclude='*.env' --exclude='.envrc' --exclude='*.tfvars' --exclude='*.tfstate*' \
  --exclude='*.lock' --exclude='package-lock.json' --exclude='pnpm-lock.yaml' \
  -e '<names, joined with |>' .
```

Then read the files that match. Env files are read only through the names filter of ground rule 5.

## Model calls

| What | Names | Read from |
| --- | --- | --- |
| Anthropic | `@anthropic-ai/sdk`, `anthropic`, `messages.create`, `api.anthropic.com` | npm `@anthropic-ai/sdk` 1.8.0, README. PyPI `anthropic` 2.8.0, README and client source |
| OpenAI and compatible clients | `openai`, `chat.completions.create`, `responses.create`, `api.openai.com`, a `baseURL` or `base_url` that points at another host | npm `openai` 7.57.0, README. PyPI `openai` 3.51.0, README and client source |
| Amazon Bedrock | `@aws-sdk/client-bedrock-runtime`, `bedrock-runtime`, `InvokeModel`, `InvokeModelWithResponseStream`, `Converse`, `ConverseStream`, and in Python `invoke_model` and `converse` | npm `@aws-sdk/client-bedrock-runtime` 3.1169.0, README. PyPI `botocore`, the service model of `bedrock-runtime` |
| Google | `@google/genai`, `google-genai`, `from google import genai`, `generateContent`, `generate_content`, `generativelanguage.googleapis.com`, `aiplatform.googleapis.com` | npm `@google/genai` 3.3.0, README. PyPI `google-genai` 3.3.0, README and source |
| Google, older | `@google/generative-ai`, `google.generativeai`, `@google-cloud/vertexai` with its `VertexAI` class, `vertexai.generative_models` | npm `@google/generative-ai` 0.24.1 and PyPI `google-generativeai` 0.8.6: both READMEs say "Deprecated" and name 31 August 2025 as the end of support. npm `@google-cloud/vertexai` 1.12.0, README: the `VertexAI` class is deprecated as of 24 June 2025 |
| Azure OpenAI | `AzureOpenAI`, `azure_endpoint`, `openai.azure.com`, `@azure/openai` | PyPI `openai` 3.51.0, README. npm `@azure/openai` 2.0.0, README: a companion to the `openai` package. Microsoft Learn, Azure OpenAI REST reference |
| Other hosts | `api.mistral.ai`, `api.groq.com`, `api.together.ai`, `api.cohere.com`, `api.fireworks.ai`, `api.x.ai`, `api.deepseek.com`, `openrouter.ai/api` | Client source of PyPI `mistralai` 3.7.0, `groq` 1.7.0, `together` 3.1.1, `cohere` 7.3.1, and `fireworks-ai` 1.2.33. docs.x.ai, api-docs.deepseek.com, and openrouter.ai/docs |
| Other hosts, older | `api.together.xyz` | PyPI `together` 3.1.1 still names it once. Its default host is `api.together.ai` |
| Local models | `ollama`, port `11434` | npm `ollama` 0.6.4 and PyPI `ollama` 0.6.3, READMEs |
| Frameworks that wrap a call | `ai` with `generateText` or `streamText`, `@ai-sdk/`, `langchain`, `@langchain/`, `llama-index`, `llama_index`, `llamaindex` | npm `ai` 7.0.173, type declarations. npm `@ai-sdk/openai` 4.0.118, `langchain` 1.6.6, `@langchain/core` 1.4.1, and `llamaindex` 0.12.1. PyPI `langchain` 1.5.0 and `llama-index` 0.14.26, READMEs |

A plain HTTP request to one of the hosts is a model call, with or without an SDK.

## Gateways

| What | Names | Read from |
| --- | --- | --- |
| A gateway the team wrote | One module that every call site imports. Names such as `gateway`, `llm`, `modelClient`, `aiClient` | No vendor. These are examples |
| LiteLLM | `litellm`, a `base_url` on port `4000` | PyPI `litellm` 1.109.1, README and the proxy's source |
| Portkey | `portkey-ai`, `portkey_ai`, `api.portkey.ai` | npm `portkey-ai` 3.1.0 and PyPI `portkey-ai` 2.3.4, READMEs |
| Helicone | `oai.helicone.ai`, `ai-gateway.helicone.ai`, and other hosts under `helicone.ai` | The Helicone repository on GitHub: README and the OpenAI proxy page of its documentation |
| Cloudflare AI Gateway | `gateway.ai.cloudflare.com` | developers.cloudflare.com, AI Gateway, "Get started" |
| Vercel AI Gateway | `@ai-sdk/gateway`, `ai-gateway.vercel.sh` | npm `@ai-sdk/gateway` 4.0.146, source |
| OpenRouter | `openrouter.ai/api` | openrouter.ai/docs, "Quickstart" |

The test for check 7 is the number of places that talk to a provider, not the presence of a name.

## Retrieval and vector stores

| What | Names | Read from |
| --- | --- | --- |
| pgvector | `vector(` in a schema, and the operators `<->`, `<#>`, `<=>`, and `<+>` | The pgvector repository on GitHub, README |
| A search function in Postgres | `match_documents`, called through `rpc(` | The Supabase repository on GitHub, the documentation page on vector columns |
| Pinecone | `@pinecone-database/pinecone`, `pinecone` | npm 9.2.0 and PyPI `pinecone` 10.3.0, READMEs |
| Weaviate | `weaviate-client`, `weaviate` | npm `weaviate-client` 3.15.3 and PyPI `weaviate-client` 4.24.1 |
| Qdrant | `@qdrant/js-client-rest`, `qdrant_client`, `QdrantClient` | npm 1.20.0. PyPI `qdrant-client` 1.20.0, README |
| Chroma | `chromadb` | npm `chromadb` 3.5.0 and PyPI `chromadb` 1.5.9, READMEs |
| Milvus | `pymilvus`, `@zilliz/milvus2-sdk-node` | PyPI `pymilvus` 3.0.3 and npm 3.0.6, READMEs |
| OpenSearch | `opensearch-py`, `@opensearch-project/opensearch` | PyPI `opensearch-py` 3.2.0 and npm 3.10.0 |
| Cloudflare Vectorize | A `vectorize` key in the Wrangler configuration, and `.insert(` and `.query(` on the binding | developers.cloudflare.com, Vectorize, "Get started" |
| Upstash Vector | `@upstash/vector`, `upstash_vector` | npm 1.2.4 and PyPI `upstash-vector` 0.8.0, READMEs |
| Embedding calls | `embeddings.create`, `text-embedding`, `embed`, `embedMany`, `embed_content` | PyPI `openai` 3.51.0, source. npm `ai` 7.0.173, type declarations. PyPI `google-genai` 3.3.0, README |

## Tools the model can call

| What | Names | Read from |
| --- | --- | --- |
| Anthropic | `tools`, `tool_use`, `tool_choice`, `input_schema` | PyPI `anthropic` 2.8.0, type definitions |
| OpenAI | `tools`, `function_call`, `tool_choice` | PyPI `openai` 3.51.0, type definitions |
| AI SDK | `tool(` and a `tools:` key | npm `ai` 7.0.173, type declarations |
| MCP | MCP client code | No single vendor. Follow the imports |

## Logging, tracing, and error tracking

| What | Names, and the setting that captures request bodies | Read from |
| --- | --- | --- |
| Application logs | `console.log`, `logger.`, `print(`, `logging.`, with a prompt, a message list, or a completion as an argument | Language built-ins |
| Sentry, JavaScript | `@sentry/`. `dataCollection` controls what the SDK collects, with a category for the inputs and outputs of generative AI | npm `@sentry/core` 11.12.0, type declarations |
| Sentry, JavaScript, older | `sendDefaultPii` | docs.sentry.io, the JavaScript options page: deprecated, with `dataCollection` available since version 10.57.0. The name is not in `@sentry/core` 11.12.0 |
| Sentry, Python | `sentry_sdk`. `send_default_pii`, and `data_collection`, which takes precedence when both are set | PyPI `sentry-sdk` 2.75.0, source |
| OpenTelemetry | `@opentelemetry/`, `opentelemetry`. `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` set to `true`, `span_only`, `event_only`, or `span_and_event` captures message content. It is off by default | npm `@opentelemetry/api` 1.10.0. The opentelemetry-python-contrib repository on GitHub, README of the OpenAI instrumentation |
| LangSmith | `langsmith`, `traceable`, `LANGSMITH_TRACING` | npm `langsmith` 0.12.0 and PyPI `langsmith` 0.14.17, READMEs and source |
| LangSmith, older | `LANGSMITH_TRACING_V2`, `LANGCHAIN_TRACING_V2` | PyPI `langsmith` 0.14.17, source: still read |
| Langfuse | `@langfuse/tracing`, `@langfuse/otel`, `@langfuse/openai`, and in Python `langfuse` with `observe` | The langfuse-js repository on GitHub, README. PyPI `langfuse` 5.2.0, README |
| Langfuse, older | The unscoped npm package `langfuse` | npm `langfuse` 3.39.2, README: a deprecated client |
| Helicone and Braintrust | The hosts under "Gateways", and `braintrust` | As above. npm `braintrust` 3.44.0 and PyPI `braintrust` 0.50.0, READMEs |
| Other observability | `dd-trace`, `ddtrace`, `posthog-node`, `posthog`, `newrelic`, `@logtail/node` | npm `dd-trace` 6.25.0, `posthog-node` 5.74.0, `newrelic` 14.12.0, and `@logtail/node` 0.6.1. PyPI `ddtrace` 4.17.0, `posthog` 7.91.1, and `newrelic` 14.3.0 |

## Evaluation sets

| What | Names | Read from |
| --- | --- | --- |
| promptfoo | `promptfoo`, `promptfooconfig.yaml`, `promptfoo eval` | npm `promptfoo` 0.125.1, README. The promptfoo repository on GitHub, the configuration guide |
| Braintrust | `braintrust`, `Eval(` | PyPI `braintrust` 0.50.0, README |
| DeepEval | `deepeval`, `deepeval test run` | PyPI `deepeval` 4.3.4, README |
| Ragas | `ragas` | PyPI `ragas` 0.4.4, README |
| OpenAI Evals | `evals` as a Python package | The openai/evals repository on GitHub, README |
| Files | `evals/`, `eval/`, `*.eval.*`, `golden*`, `cases.json`, `cases.jsonl`, `fixtures/` next to prompts | No vendor. These are common folder and file names |
| In CI | An evaluation command in a workflow that runs on pull requests and can fail the run | No vendor |

## Usage and cost

| What | Names | Read from |
| --- | --- | --- |
| Token counts, Anthropic | `usage`, `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens` | PyPI `anthropic` 2.8.0, type definitions |
| Token counts, OpenAI | `usage`, `prompt_tokens`, `completion_tokens`, `input_tokens`, `output_tokens`, `cached_tokens` | PyPI `openai` 3.51.0, type definitions |
| A request log | A table or a collection that gets one row per model call: `ai_requests`, `llm_requests`, `usage_log`, `model_calls` | No vendor. These are examples |

## Regions

| What | Names | Read from |
| --- | --- | --- |
| Endpoint region | `region`, `location`, `AWS_REGION`, a regional host name | General. For Google, `location` is the parameter of `google-genai` 3.3.0 |
| Amazon Bedrock inference profiles | A model ID with a geography prefix, such as `us.`, is a geographic profile and stays inside that geography. A Global profile can route to any supported commercial Region | docs.aws.amazon.com, Amazon Bedrock User Guide, the pages on cross-Region inference and on supported inference profiles |
| Copies | `aws_db_snapshot_copy`, `aws_db_instance_automated_backups_replication`, `aws_s3_bucket_replication_configuration`, `replication`, `cross_region`, a second provider block with another region | The terraform-provider-aws repository on GitHub, the documentation page of each resource |
