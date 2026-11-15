// Test fixture.
import { randomUUID } from "node:crypto";
import { z } from "zod";
import { getSession } from "../../../lib/auth";
import { db } from "../../../lib/db";
import { summariseTicket } from "../../../lib/ai/summarise";
import { rateLimit } from "../../../lib/rate-limit";

const Body = z.object({ ticketId: z.string().uuid() });
const MAX_TICKET_CHARS = 8000;

export async function POST(request: Request) {
  const session = await getSession();
  if (!session) return new Response("Sign in first", { status: 401 });

  if (!(await rateLimit(session.userId))) return new Response("Too many requests", { status: 429 });

  const body = Body.parse(await request.json());
  const ticket = (
    await db.query("select body from tickets where id = $1 and tenant_id = $2", [body.ticketId, session.tenantId])
  ).rows[0];
  if (!ticket) return new Response("Not found", { status: 404 });
  if (ticket.body.length > MAX_TICKET_CHARS) return new Response("Ticket too long", { status: 413 });

  const summary = await summariseTicket(randomUUID(), ticket.body);
  return Response.json({ summary }, { headers: { "x-ai-generated": "true" } });
}
