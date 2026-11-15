export async function POST(req: Request) {
  if (Number(req.headers.get("content-length") ?? "0") > 65536) {
    return new Response("too large", { status: 413 });
  }
  const body = await req.text();
  const event = JSON.parse(body);
  await fetch(process.env.SUPABASE_URL + "/rest/v1/shipments", {
    method: "PATCH",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ status: event.status }),
  });
  return new Response("ok");
}
