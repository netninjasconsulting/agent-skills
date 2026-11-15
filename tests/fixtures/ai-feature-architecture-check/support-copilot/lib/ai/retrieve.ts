// Test fixture.
import { db } from "../db";
import { SOURCE_NAMES } from "./sources";

// tenantId is whatever the caller passes in.
export async function retrieve(embedding: number[], tenantId: string) {
  const { rows } = await db.query(
    `select id, source, body from documents
     where tenant_id = $1 and source = any($2)
     order by embedding <=> $3 limit 5`,
    [tenantId, SOURCE_NAMES, JSON.stringify(embedding)],
  );
  return rows as { id: string; source: string; body: string }[];
}
