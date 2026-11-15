// Test fixture.
import { getSession } from "../../../../lib/auth";
import { db } from "../../../../lib/db";

// Erases a customer. The embeddings built from their tickets stay in the documents table.
export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  const session = await getSession();
  if (!session || session.role !== "admin") return new Response("Forbidden", { status: 403 });
  const { id } = await params;
  await db.query("delete from tickets where customer_id = $1 and tenant_id = $2", [id, session.tenantId]);
  await db.query("delete from customers where id = $1 and tenant_id = $2", [id, session.tenantId]);
  return new Response(null, { status: 204 });
}
