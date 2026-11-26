<!-- coderabbit-ai-generated:v1 -->

# Real name verification

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7ff85b4827ad29ec7d4ee0296f58064fa3c0bdb0755d09c17ba2fea6621101cd -->

Apply `supabase/migrations/20261126162011_real_name_verification.sql` after the preceding migrations before distributing the updated apps. The connected production project recorded this migration as version `20261126162011`.

<!-- /coderabbit-ai-generated:v1 -->

A user sets their profile full name, then submits a clear JPEG or PNG image of an ID showing that name from Profile → Real name verification. Images are limited to 512 KiB and 4096 pixels per dimension. The request remains pending until an administrator reviews it. Rejected requests may be submitted again.

In the admin workspace, Real name requests shows pending requests. MFA-verified viewers may inspect the proof; MFA-verified editors may approve or reject. The administrator must compare the ID to the submitted name. If the profile name has changed, reject the request and ask for a new one. A verified badge appears only while the current profile name matches the approved name. A changed name requires a new review.

Proof images are stored in a private database table, removed on approval or rejection, and deleted with the account. Pending images are excluded from the deleted-account archive. Do not include proof in logs or support messages. Decisions are recorded in the administrator operations audit.

Run `flutter analyze --no-pub`, `flutter test --no-pub test/profile_layout_test.dart test/profile_service_test.dart`, and `python3 supabase/tests/run_integration.py` against a disposable local database. Verify image selection on Android and admin review on Windows against the deployed migration before release.
