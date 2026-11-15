export async function POST(req: Request) {
  const body = await req.text();
  const event = JSON.parse(body);
  await fetch(process.env.SUPABASE_URL + "/rest/v1/shipments", {
    method: "PATCH",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ status: event.status }),
  });
  return new Response("ok");
}
