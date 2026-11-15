Deno.serve(async (req: Request) => {
  const { url } = await req.json();
  const file = await (await fetch(url)).arrayBuffer();
  return new Response(file, { headers: { "content-type": "application/pdf" } });
});
