// Test fixture.
import { db } from "../db";

export async function writeTrace(trace: {
  requestId: string;
  model: string;
  promptVersion: string;
  sources: string[];
  approver: string | null;
}) {
  await db.query(
    "insert into ai_traces (request_id, model, prompt_version, sources, approver) values ($1, $2, $3, $4, $5)",
    [trace.requestId, trace.model, trace.promptVersion, trace.sources, trace.approver],
  );
}

export async function logUsage(model: string, totalTokens: number) {
  await db.query("insert into usage_log (model, total_tokens) values ($1, $2)", [model, totalTokens]);
}
