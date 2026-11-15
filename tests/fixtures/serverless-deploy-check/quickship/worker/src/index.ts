export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    console.log("lookup", url.pathname);
    return new Response(JSON.stringify({ ok: true }), {
      headers: {
        "access-control-allow-origin": "https://quickship.example.com",
        "content-type": "application/json",
      },
    });
  },
};
