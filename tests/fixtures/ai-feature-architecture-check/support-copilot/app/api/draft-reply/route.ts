// Test fixture.
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { getSession } from "../../../lib/auth";
import { db } from "../../../lib/db";
import { draftReply } from "../../../lib/ai/draft";
import { buildDraftPrompt } from "../../../lib/ai/prompt";
import { retrieve } from "../../../lib/ai/retrieve";

const Body = z.object({ ticketId: z.string(), tenantId: z.string(), embedding: z.array(z.number()) });

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) return new Response("Sign in first", { status: 401 });

  const body = await request.json();
  const ticket = (await db.query("select * from tickets where id = $1", [body.ticketId])).rows[0];
  const customer = (await db.query("select * from customers where id = $1", [ticket.customer_id])).rows[0];
  // The tenant comes from the request body, not from the session.
  const context = await retrieve(body.embedding, body.tenantId);
  const prompt = buildDraftPrompt(customer, ticket.body, context);

  // Validation runs after the prompt is built.
  Body.parse(body);

  const draft = await draftReply(randomUUID(), prompt, context.map((doc) => doc.source));
  return Response.json({ draft }, { headers: { "x-ai-generated": "true" } });
}
