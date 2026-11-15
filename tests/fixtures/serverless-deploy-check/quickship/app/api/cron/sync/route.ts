export async function GET() {
  const res = await fetch("https://carrier.example.com/sync");
  return Response.json({ synced: res.ok });
}
