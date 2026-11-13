import { NextResponse } from "next/server";
import { pool } from "@/lib/db";

export async function GET() {
  const result = await pool.query("SELECT id, email, password_hash, is_admin FROM users");
  return NextResponse.json(result.rows);
}
