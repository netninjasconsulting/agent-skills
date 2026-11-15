# Cost per action

From the published worksheet, https://www.netninjas.us/events/cost-per-ai-action-worksheet. This section gives no figure. It says whether the code records what a cost per action needs, and it prints the published query with the repository's own names.

## The seven columns

The query needs one row per model call, with these columns.

| Column | What it holds |
| --- | --- |
| `tenant_id` | The customer the call was made for |
| `action_id` | The user-visible action. One action can make several calls |
| `model` | The model that answered |
| `input_tokens` | Tokens billed at the full input price |
| `cached_input_tokens` | Tokens read from a cache |
| `output_tokens` | Tokens in the answer |
| `created_at` | When the call was made |

## What to report

1. Find where usage is recorded after each model call: a table, a collection, a log line with structure, or a metering call to a gateway. `references/signals.md` lists names to search for.
2. For each of the seven columns, write "recorded" with the path and the line, or "not recorded". A total of tokens with no split counts as "not recorded" for the three token columns.
3. When several call sites exist, a column is "recorded" only when every call site records it.
4. Print the query below under the heading "Proposal". Change only the table name and the column names it reads from, to the ones the repository uses. For a column that is not recorded, keep the published name and mark it with a comment: `-- not recorded yet`.
5. Add one line: the retrieval and platform cost per action comes from the cloud bill, so it is "not checked".

Do not estimate a cost, a price, or a volume. Model prices change often, and the worksheet takes them from the provider's price list on the day.

## The published query

```sql
-- cost_per_action.sql (PostgreSQL)
-- From the talk "Your AI feature is an architecture problem" (www.netninjas.us/events).
-- Model cost per customer and per AI action over the last 30 days.
--
-- ai_requests:  one row per model call (tenant_id, action_id, model,
--               input_tokens, cached_input_tokens, output_tokens, created_at).
--               input_tokens counts the tokens billed at the full input price.
-- model_prices: one row per model, in euros per million tokens, copied from
--               the provider's current price list.

WITH calls AS (
  SELECT
    r.tenant_id,
    r.action_id,
    ( r.input_tokens        * p.input_per_million
    + r.cached_input_tokens * p.cached_input_per_million
    + r.output_tokens       * p.output_per_million ) / 1000000.0 AS cost_eur
  FROM ai_requests r
  JOIN model_prices p ON p.model = r.model
  WHERE r.created_at >= now() - interval '30 days'
)
SELECT
  tenant_id,
  count(DISTINCT action_id)                                AS actions,
  count(*)                                                 AS model_calls,
  round(sum(cost_eur), 2)                                  AS model_cost_eur,
  round(sum(cost_eur) / count(DISTINCT action_id), 4)      AS cost_per_action_eur
FROM calls
GROUP BY tenant_id
ORDER BY model_cost_eur DESC;
```

The published query prices in euros. The currency is the one the team's price table uses, and the aliases can follow it.
