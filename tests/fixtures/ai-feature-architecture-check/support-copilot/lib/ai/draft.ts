// Test fixture. The first of two places that call a model.
import Anthropic from "@anthropic-ai/sdk";
import { issueRefund, refundTool } from "./tools";
import { logUsage, writeTrace } from "./trace";
import { PROMPT_VERSION } from "./prompt";

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const MODEL = "claude-sonnet-5-5";

export async function draftReply(requestId: string, prompt: string, sources: string[]) {
  console.log("draft-reply prompt", prompt);
  const message = await client.messages.create({
    model: MODEL,
    max_tokens: 1024,
    tools: [refundTool],
    messages: [{ role: "user", content: prompt }],
  });
  console.log("draft-reply response", JSON.stringify(message.content));

  // The refund runs as soon as the model asks for it.
  for (const block of message.content) {
    if (block.type === "tool_use" && block.name === "issue_refund") {
      await issueRefund(block.input as { customerId: string; amountCents: number });
    }
  }

  await writeTrace({ requestId, model: MODEL, promptVersion: PROMPT_VERSION, sources, approver: null });
  await logUsage(MODEL, message.usage.input_tokens + message.usage.output_tokens);
  return message.content.filter((block) => block.type === "text").map((block) => block.text).join("\n");
}
