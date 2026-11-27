import { createVerificationHandler } from "./handler.mjs";

Deno.serve(createVerificationHandler({
  supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
  anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  ocrUrl: Deno.env.get("REAL_NAME_OCR_URL"),
  ocrToken: Deno.env.get("REAL_NAME_OCR_TOKEN"),
}));
