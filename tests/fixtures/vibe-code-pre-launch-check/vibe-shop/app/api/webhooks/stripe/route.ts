import { NextResponse } from "next/server";
import { pool } from "@/lib/db";

// Trusts the request body. The Stripe signature header is never checked.
export async function POST(request: Request) {
  const event = await request.json();
  if (event.type === "checkout.session.completed") {
    await pool.query("UPDATE orders SET paid = true WHERE id = $1", [event.data.object.metadata.order_id]);
  }
  return NextResponse.json({ received: true });
}
