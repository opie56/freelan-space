<!-- coderabbit-ai-generated:v1 -->

# Real name verification

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7ff85b4827ad29ec7d4ee0296f58064fa3c0bdb0755d09c17ba2fea6621101cd -->

Apply `supabase/migrations/20261126162011_real_name_verification.sql` after the preceding migrations before distributing the updated apps. The connected production project recorded this migration as version `20261126162011`.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:4dd3c3fd169c956641495cb6ac2fc072c412b68afe94921d8a622d56ef32713f -->

## User and admin flow

In Profile → Real name verification, choose Aadhaar, Voter ID, driving licence, passport or PAN card. Use the camera to capture the front and back; for a passport, use the photo page and the last page with address or file information. The app checks both photos. If the name differs, correct it in this screen and check again. Saving a changed name uses the existing security PIN confirmation.

The server rechecks both photos at submission. A recognized format with an exact name match starts a 10 second countdown and is then approved automatically. Unreadable or unsupported variants can go to admin review. The badge appears beside the verified profile name, which is locked once an automatic check is scheduled or an admin approves it. A historical approval for a name the account had already changed can be resubmitted. OCR verifies that the photographed name matches the profile; it does not verify that the document is genuine or that the account holder owns it.

MFA verified administrators can inspect both sides in Real name requests and open each at full size with zoom. Editors can decide and must enter a reason when rejecting; the reason appears on the user's verification page. Legacy submissions with one photo still appear with that limitation. Older admin apps can decide only legacy submissions. Both photos are removed on a decision or account deletion; they are not included in the deleted account archive.

## Deployment

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f637d617a327809fe58f08043520eb8961525cf69b976db22a40dcda0da07502 -->

1. Apply `supabase/migrations/20261127045328_two_sided_real_name_verification.sql` after the preceding migrations. With `pg_cron` enabled, the migration schedules background completion so approved proofs are cleared even if the user leaves the screen. Without it, the next status check completes a due request.
2. Build the private OCR worker: `docker build -t freelan-real-name-ocr services/real-name-ocr`. Run it on infrastructure you control, as a nonroot container behind an HTTPS proxy. Supply `REAL_NAME_OCR_TOKEN` using the host's secret manager (at least 32 random characters). Expose `POST /scan` only through that proxy; cap request bodies at 1.41 MB and turn off request and response body logging. `GET /health` checks the process. Do not give the worker database or Supabase credentials.
3. Set `REAL_NAME_OCR_URL` to the HTTPS scan endpoint and set the matching `REAL_NAME_OCR_TOKEN` in Supabase Edge Function secrets. Deploy `real-name-verification` with JWT verification enabled. The function also validates the session with Auth and rejects blocked accounts. If the worker is missing or unavailable, the app can still submit explicitly for admin review and will display that fallback.
4. Verify automatic approval and rejected submissions with synthetic documents on the intended project before distributing updated Android and Windows builds. Production ID photos should never be added to fixtures, logs or support messages.

On the connected project, migration `20261127045328` and version 1 of the Edge Function are deployed. The private HTTPS OCR worker and its two Supabase secrets still need to be provisioned for automatic approval.

<!-- /coderabbit-ai-generated:v1 -->

## Local checks

Run `flutter analyze --no-pub`, `flutter test --no-pub`, `python3 supabase/tests/run_integration.py`, `node --test supabase/functions/real-name-verification/handler.test.mjs` and `python3 -m unittest discover -s services/real-name-ocr`. The worker tests need Tesseract with English language data, Pillow and the DejaVu Sans font. Automatic OCR currently recognizes compatible English layouts; photos from other layouts can be reviewed manually.


<!-- /coderabbit-ai-generated:v1 -->
