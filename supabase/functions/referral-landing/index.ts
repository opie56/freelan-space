import { createHandler } from './handler.mjs';
const project = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
Deno.serve(createHandler({
  readDownload: async () => {
    const response = await fetch(`${project}/rest/v1/referral_download_link?select=url&singleton=eq.true`, {
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) throw new Error('Download unavailable');
    const rows = await response.json();
    return Array.isArray(rows) ? rows[0]?.url : null;
  },
}));
