const html = (text) => String(text).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const headers = {
  'content-type': 'text/html; charset=utf-8',
  'cache-control': 'no-store',
  'content-security-policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
  'referrer-policy': 'no-referrer',
  'x-content-type-options': 'nosniff',
};
export function createHandler({ readDownload }) {
  return async (request) => {
    if (request.method !== 'GET') return new Response('Method not allowed', { status: 405, headers: {allow:'GET'} });
    const url = new URL(request.url);
    const codes = url.searchParams.getAll('code');
    const code = codes.length === 1 ? codes[0].toUpperCase() : '';
    if (!/^[A-Z]{4}[0-9]{3}$/.test(code)) return new Response('Invalid referral link', {status: 400, headers});
    let download = null;
    try {
      const candidate = await readDownload();
      const parsed = new URL(candidate);
      if (parsed.protocol === 'https:' && !parsed.username && !parsed.password) download = parsed.href;
    } catch (_) { /* The code and open-app link remain useful if download is unavailable. */ }
    const open = `space.freelan.app://referral?code=${encodeURIComponent(code)}`;
    return new Response(`<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Freelan Space invitation</title><style>body{font:16px system-ui;max-width:36rem;margin:4rem auto;padding:0 1rem;color:#222}a{display:inline-block;padding:.8rem 1rem;margin:.5rem .5rem .5rem 0;background:#693db4;color:white;border-radius:.5rem;text-decoration:none}strong{font-size:1.4rem}</style></head><body><h1>Freelan Space invitation</h1><p>Your referral code: <strong>${html(code)}</strong></p><a href="${html(open)}">Open app</a>${download ? `<a href="${html(download)}">Download app</a>` : ''}<p>After installing the app, return to this link and tap Open app, or enter the code in your profile after signing in.</p></body></html>`, {status: 200, headers});
  };
}
