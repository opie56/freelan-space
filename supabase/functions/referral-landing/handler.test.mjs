import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from './handler.mjs';

test('referral page uses validated code and the configured HTTPS download', async () => {
  const handler = createHandler({readDownload: async () => 'https://example.com/app.apk?a=1&b=2'});
  const response = await handler(new Request('https://example.test/?code=abcd123'));
  const body = await response.text();
  assert.equal(response.status, 200);
  assert.match(body, /ABCD123/);
  assert.match(body, /space\.freelan\.app:\/\/referral\?code=ABCD123/);
  assert.match(body, /https:\/\/example\.com\/app\.apk\?a=1&amp;b=2/);
  assert.match(response.headers.get('content-security-policy'), /default-src 'none'/);
});
test('rejects invalid or repeated codes and unsafe download URLs', async () => {
  const handler = createHandler({readDownload: async () => 'javascript:alert(1)'});
  assert.equal((await handler(new Request('https://example.test/?code=x'))).status, 400);
  assert.equal((await handler(new Request('https://example.test/?code=ABCD123&code=EFGH456'))).status, 400);
  const body = await (await handler(new Request('https://example.test/?code=ABCD123'))).text();
  assert.doesNotMatch(body, /javascript:/);
  assert.match(body, /enter the code in your profile/);
});
