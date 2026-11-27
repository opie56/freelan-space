const types = new Set(["aadhaar", "voter_id", "driving_licence", "passport", "pan"]);
const maxBody = 1_410_000;
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, x-client-info, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};
const reply = (status, body) => Response.json(body, {
  status,
  headers: { ...cors, "cache-control": "no-store" },
});

async function boundedJson(request) {
  const reader = request.body?.getReader();
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let length = 0;
  let content = "";
  if (!reader) throw new Error();
  let expired = false;
  const timer = setTimeout(() => {
    expired = true;
    void reader.cancel().catch(() => {});
  }, 8000);
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (expired) throw new Error();
      if (done) break;
      length += value.byteLength;
      if (length > maxBody) throw new Error();
      content += decoder.decode(value, { stream: true });
    }
    return JSON.parse(content + decoder.decode());
  } finally {
    clearTimeout(timer);
    void reader.cancel().catch(() => {});
  }
}

function validPhoto(photo) {
  return photo && (photo.mime === "image/jpeg" || photo.mime === "image/png") &&
    typeof photo.data === "string" && photo.data.length >= 32 && photo.data.length <= 699052;
}

export function createVerificationHandler(config, fetcher = fetch) {
  const authHeaders = { apikey: config.anonKey };
  const rpc = (name, body) => fetcher(`${config.supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      "content-type": "application/json", apikey: config.serviceKey,
      authorization: `Bearer ${config.serviceKey}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(8000),
  });
  return async (request) => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") return reply(405, { status: "method" });
    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) return reply(401, { status: "sign_in" });
    try {
      const auth = await fetcher(`${config.supabaseUrl}/auth/v1/user`, {
        headers: { ...authHeaders, authorization },
        signal: AbortSignal.timeout(8000),
      });
      if (!auth.ok) return reply(401, { status: "sign_in" });
      const { id } = await auth.json();
      if (!id) return reply(401, { status: "sign_in" });
      let body;
      try {
        body = await boundedJson(request);
      } catch {
        return reply(422, { status: "invalid_photos" });
      }
      const { action, name, document_type, front, back } = body ?? {};
      if (!["check", "submit", "manual"].includes(action) ||
        typeof name !== "string" || !name.trim() || [...name.trim()].length > 80 ||
        !types.has(document_type) || !validPhoto(front) || !validPhoto(back) ||
        front.data === back.data) return reply(422, { status: "invalid_photos" });

      const allowance = await rpc("allow_real_name_scan", { p_user: id });
      if (!allowance.ok) return reply(403, { status: "not_available" });
      if (await allowance.json() !== true) return reply(429, { status: "try_later" });

      let result = "unavailable";
      // Restrict the destination to an operator-configured HTTPS worker; never follow a redirect.
      if (action !== "manual" && config.ocrUrl?.startsWith("https://") && config.ocrToken) {
        try {
          const scan = await fetcher(config.ocrUrl, {
            method: "POST", redirect: "error",
            headers: { "content-type": "application/json", authorization: `Bearer ${config.ocrToken}` },
            body: JSON.stringify({
              name: name.trim(), document_type,
              front: { mime: front.mime, data: front.data },
              back: { mime: back.mime, data: back.data },
            }),
            signal: AbortSignal.timeout(12000),
          });
          if (scan.ok || scan.status === 422) {
            const { status } = await scan.json();
            if (["match", "mismatch", "unreadable", "invalid_photos"].includes(status)) result = status;
          }
        } catch {
          // Allow an explicit admin review when the OCR worker is unavailable.
        }
      }
      if (action === "check") return reply(200, { status: result });
      if (action !== "manual" && result !== "match") return reply(200, { status: result });

      const submitted = await rpc("submit_scanned_real_name", {
        p_user: id, p_name: name.trim(), p_type: document_type,
        p_front_mime: front.mime, p_front: front.data,
        p_back_mime: back.mime, p_back: back.data, p_match: result === "match",
      });
      if (!submitted.ok) return reply(409, { status: "submit_failed" });
      return reply(200, await submitted.json());
    } catch {
      return reply(503, { status: "unavailable" });
    }
  };
}
