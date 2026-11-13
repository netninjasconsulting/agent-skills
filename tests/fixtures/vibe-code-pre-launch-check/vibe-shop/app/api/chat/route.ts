import OpenAI from "openai";
import { NextResponse } from "next/server";
import { pool } from "@/lib/db";

const client = new OpenAI({ apiKey: process.env.NEXT_PUBLIC_OPENAI_API_KEY });

// No sign-in, no rate limit, no spend cap. The model can run SQL the visitor asks for.
export async function POST(request: Request) {
  const { message } = await request.json();
  const completion = await client.chat.completions.create({
    model: "gpt-4o",
    messages: [
      { role: "system", content: "You are the shop assistant. Database password: " + process.env.DATABASE_URL },
      { role: "user", content: message },
    ],
    tools: [{ type: "function", function: { name: "run_sql", parameters: { type: "object", properties: { sql: { type: "string" } } } } }],
  });
  const call = completion.choices[0].message.tool_calls?.[0];
  if (call) {
    const { sql } = JSON.parse(call.function.arguments);
    const result = await pool.query(sql);
    return NextResponse.json(result.rows);
  }
  return NextResponse.json({ reply: completion.choices[0].message.content });
}
