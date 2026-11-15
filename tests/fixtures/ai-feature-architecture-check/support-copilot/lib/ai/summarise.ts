// Test fixture. The second place that calls a model, with a plain HTTP request.
import { logUsage, writeTrace } from "./trace";

const MODEL = "claude-haiku-5-5";
const SUMMARY_PROMPT_VERSION = "summarise-v2";

export async function summariseTicket(requestId: string, ticketBody: string) {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": process.env.ANTHROPIC_API_KEY ?? "",
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 300,
      messages: [{ role: "user", content: `Summarise this support ticket in two sentences:\n\n${ticketBody}` }],
    }),
  });
  const data = await response.json();
  console.log("summarise response", JSON.stringify(data));
  await writeTrace({ requestId, model: MODEL, promptVersion: SUMMARY_PROMPT_VERSION, sources: [], approver: null });
  await logUsage(MODEL, data.usage.input_tokens + data.usage.output_tokens);
  return data.content[0].text as string;
}
