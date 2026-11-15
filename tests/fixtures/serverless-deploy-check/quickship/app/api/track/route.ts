import { createClient } from "@supabase/supabase-js";

export async function POST(req: Request) {
  if (Number(req.headers.get("content-length") ?? "0") > 4096) {
    return new Response("too large", { status: 413 });
  }
  const { code } = await req.json();
  const db = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
  const { data } = await db.from("shipments").select("*").eq("code", code);
  return Response.json(data);
}
