import { NextResponse } from "next/server";
import { pool } from "@/lib/db";

// Returns any order to any caller: no session check, no ownership check.
export async function GET(_request: Request, { params }: { params: { id: string } }) {
  try {
    const result = await pool.query("SELECT * FROM orders WHERE id = '" + params.id + "'");
    return NextResponse.json(result.rows[0]);
  } catch (error) {
    return NextResponse.json({ error: String(error), stack: (error as Error).stack }, { status: 500 });
  }
}
