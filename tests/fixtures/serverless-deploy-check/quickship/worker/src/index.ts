interface Env {
  LIMITER: { limit(options: { key: string }): Promise<{ success: boolean }> };
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const { success } = await env.LIMITER.limit({ key: url.pathname });
    if (!success) return new Response("slow down", { status: 429 });
    if (Number(request.headers.get("content-length") ?? "0") > 8192) {
      return new Response("too large", { status: 413 });
    }
    console.log("lookup", url.pathname);
    return new Response(JSON.stringify({ ok: true }), {
      headers: {
        "access-control-allow-origin": "https://quickship.example.com",
        "content-type": "application/json",
      },
    });
  },
};
