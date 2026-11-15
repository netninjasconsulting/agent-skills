Deno.serve(async (req: Request) => {
  const { email, code } = await req.json();
  await fetch("https://mail.example.com/send", {
    method: "POST",
    body: JSON.stringify({ to: email, text: `Your parcel ${code} moved.` }),
  });
  return new Response("sent");
});
