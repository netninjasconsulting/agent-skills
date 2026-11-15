// Test fixture.
import { cookies } from "next/headers";
import { db } from "./db";

export type Session = { userId: string; tenantId: string; role: "agent" | "admin" };

export async function getSession(): Promise<Session | null> {
  const token = (await cookies()).get("session")?.value;
  if (!token) return null;
  const { rows } = await db.query("select user_id, tenant_id, role from sessions where token = $1", [token]);
  return rows[0] ? { userId: rows[0].user_id, tenantId: rows[0].tenant_id, role: rows[0].role } : null;
}
