import { test } from "node:test";
import assert from "node:assert/strict";
import { createVerificationHandler } from "./handler.mjs";

const config = {
  supabaseUrl: "https://database.example.test", anonKey: "public",
  serviceKey: "server", ocrUrl: "https://ocr.example.test/scan", ocrToken: "worker",
};
const payload = {
  action: "submit", name: "Taylor Example", document_type: "aadhaar",
  front: { mime: "image/png", data: "a".repeat(64) },
  back: { mime: "image/png", data: "b".repeat(64) },
  p_match: true, p_user: "spoofed",
};
function setup({ scan = "match", authenticated = true, allowed = true } = {}) {
  const submissions = [];
  let scans = 0;
  const handler = createVerificationHandler(config, async (url, init) => {
    if (url.endsWith("/auth/v1/user")) {
      return Response.json({ id: "actual-user" }, { status: authenticated ? 200 : 401 });
    }
    if (url.endsWith("allow_real_name_scan")) return Response.json(allowed);
    if (url === config.ocrUrl) {
      scans++;
      assert.equal(init.redirect, "error");
      const body = JSON.parse(init.body);
      assert.equal(body.front.data, payload.front.data);
      assert.equal(body.back.data, payload.back.data);
      assert.equal(body.p_match, undefined);
      if (scan === "offline") throw new Error("Unavailable");
      return Response.json({ status: scan });
    }
    assert.ok(url.endsWith("submit_scanned_real_name"));
    const body = JSON.parse(init.body);
    submissions.push(body);
    return Response.json(body.p_match ? { status: "processing", seconds_remaining: 10 } : { status: "pending" });
  });
  return { submissions, scans: () => scans, request: (body = payload) => handler(new Request("https://app.test", {
    method: "POST", headers: { authorization: "Bearer verified" }, body: JSON.stringify(body),
  })) };
}

test("only worker-confirmed names schedule approval; authenticated ID is authoritative", async () => {
  const { request, submissions } = setup();
  assert.deepEqual(await (await request()).json(), { status: "processing", seconds_remaining: 10 });
  assert.equal(submissions.length, 1);
  assert.equal(submissions[0].p_user, "actual-user");
  assert.equal(submissions[0].p_match, true);
});

test("mismatch or worker outage does not schedule approval and allows explicit manual review", async () => {
  for (const scan of ["mismatch", "offline", "unreadable"]) {
    const { request, submissions, scans } = setup({ scan });
    assert.equal((await (await request()).json()).status, scan === "offline" ? "unavailable" : scan);
    assert.equal(submissions.length, 0);
    assert.equal((await (await request({ ...payload, action: "manual" })).json()).status, "pending");
    assert.equal(submissions[0].p_match, false);
    assert.equal(scans(), 1);
  }
});

test("precheck is read-only; malformed, unauthenticated and rate limited requests never scan", async () => {
  const { request, submissions, scans } = setup();
  assert.equal((await (await request({ ...payload, action: "check" })).json()).status, "match");
  assert.equal(submissions.length, 0);
  assert.equal((await request({ ...payload, back: payload.front })).status, 422);
  assert.equal((await request({ ...payload, name: "A".repeat(1_420_000) })).status, 422);
  assert.equal(scans(), 1);
  for (const [options, status] of [[{ authenticated: false }, 401], [{ allowed: false }, 429]]) {
    const rejected = setup(options);
    assert.equal((await rejected.request()).status, status);
    assert.equal(rejected.scans(), 0);
  }
});
