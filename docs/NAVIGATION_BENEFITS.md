<!-- coderabbit-ai-generated:v1 -->

# Navigation and user controls

The user feature controls page lets administrators enable or disable referral links, notification shortcuts, campaign pause, saved filters, bonus coupons, quiet hours, device sessions and offline wallet snapshots. These switches default to enabled. Admin editors can create or disable coupons, choosing the amount, total redemption limit and expiry; each user can redeem a given coupon once. The server enforces the limit and records each credit in the wallet ledger.

Pausing a campaign prevents new submissions. Pending reviews and reserved coins remain in place; the existing cancellation window remains unchanged. A paused campaign can be resumed even after the administrator disables new pauses.

Quiet hours use the device's UTC offset saved with the preference; users should update it after a timezone or daylight-saving change. Notifications already leased to the push worker can still arrive, and in-app notifications remain visible. Existing push schedules release pending jobs after quiet hours.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:8156e54d51dba55c4af930f28bfa075bce8f2d4f8a03c6749f280de5f9055d47 -->

Device sign-out deletes the selected session, its refresh tokens and session-linked push registrations. On the first remote revocation, older registrations that lack a session link are also removed; other devices can re-register on app resume. Already leased push notifications can still be delivered. Already issued access tokens can remain valid until they expire. Session listing and revocation use the Supabase Auth `sessions` schema, so verify compatibility with the target project before deployment. Offline view shows the last cached available wallet balance, its update time and may remain visible offline until the app reconnects and receives an administrator's setting change.

<!-- /coderabbit-ai-generated:v1 -->

Referral links open a public landing page with an app link, referral code and the administrator's published download URL. If the app is installed, the app asks the user to confirm and verifies the existing security PIN before applying the code. After a fresh install, reopen the original link or enter the code in Profile; automatic post-install attribution is not provided. Notification shortcuts open the relevant history or section; notification payloads do not currently identify an individual submission.

## Rollout

1. Test the migration and the session revocation flow against the target project's current Auth schema and a disposable user. Validate existing sessions, refresh-token cascades and issued-token expiry behavior with Supabase Auth.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ef106fcab7284b6060320fa85c5c1acd9e44274853107918b0b2a65bb9c83357 -->

2. The `referral-landing` function is deployed to the connected project with JWT verification disabled, as requested, so invitations open before sign-in. It reads the published HTTPS referral download URL using the platform-provided service role. Anonymous HTTP checks passed; verify app opening and download on a real device.

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5fba97fc621f35615fd4dcac5647f5a298b33c7f69d868cc0aa311ef7a3be963 -->

3. The `navigation_benefits` migration is applied to the connected project as version `20261124154209`; the matching local file is `supabase/migrations/20261124154209_navigation_benefits.sql`. The existing push worker uses the updated database queue claim function; no push worker redeploy or new schedule is needed for quiet hours.

<!-- /coderabbit-ai-generated:v1 -->
4. Build and distribute updated user and admin applications with the correct project configuration. Test referral links on a real Android device, notification taps, push delivery around quiet hours and sign-out of a second device. JWT access tokens can outlive session revocation.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a87e0d2ab5e16ecac9c5a80d80e90b5a3596a37ace5a83bef2ac8cea8fd96f71 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:148c1a333d113ddaf292c64d4136d8b2707ea97f58ffe8481d54322ab930f37f -->

The migration and referral function are live. Updated app builds still need distribution; local tests do not establish behavior on an Android device.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
