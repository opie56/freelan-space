<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:6946cdf13410aac306f33f197d601c95805a81d1b45ef53e89c8d1e058c27cbc -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:839d4b92f805dbbd5ccc6ba2ae0b5f0ccd8ece1d43944e89c5b6bbc554843b15 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ca9b04827a87f2d2f3eae1355e3f106724ec14bc924ef7e7bd5dfad44b7baf83 -->

# Freelan Space

<!-- /coderabbit-ai-generated:v1 -->

Flutter Android app using Supabase Auth and PostgreSQL for self-reported Instagram engagement campaigns. Claims are not verified Instagram actions. Instagram passwords are never collected.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1c07e2717a8f2f9782074e698bf8261404c2dec1f9c1f703699aa1999c8a939a -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:743638fbc433e0c881b7c60d62e876d92ae532f37d2fd7d0d2bf555e4cb689b6 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7e374a63d0ab436337c7c1e1e72fdeee95a367879add9060ed9d72ddc682aeee -->

[One-command user APK and Windows admin builds (Malayalam)](docs/ONE_COMMAND_BUILDS.md)

[Visual Studio setup and build guide (Malayalam)](docs/VISUAL_STUDIO_BUILD_GUIDE.md)

<!-- /coderabbit-ai-generated:v1 -->

[Windows APK validator + Cloudflare Tunnel: complete setup guide (Malayalam)](docs/WINDOWS_APK_VALIDATOR_SETUP.md)

<!-- /coderabbit-ai-generated:v1 -->

## Supabase setup

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f24dde85e125e562cf2124f3ccc92529f5111eda2b20320eecc21d7bc2111f9e -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:bb7f26bba409c994aff694dc36a35cfe61121fc0a0fdc824b10cbe631281c292 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:fa0348a4265fec4bf157e4bdf167474e26bce42a9640b0322dda6ef8fec283e8 -->

1. Enable email/password authentication and **Confirm email** in Supabase Authentication. Configure custom SMTP. In Authentication → Email templates → Confirm signup, replace the confirmation link with `<p>Your Freelan Space verification code is: <strong>{{ .Token }}</strong></p>`. Configure email OTP length to 6 digits. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0aae538fcf50bb8df9f20967443047ee2494ac30494309e79570f14351bc18f2 -->

For password recovery configure `supabase/templates/recovery.html` in the Reset Password email template, including both `{{ .Token }}` for current apps and `{{ .ConfirmationURL }}` for older user apps. Verify six-digit email delivery before distributing the new app.

<!-- /coderabbit-ai-generated:v1 --> Signup uses `signUp(email, password)`, then `verifyOTP(type: signup)` on a separate in-memory client; verification never logs the main app in. The user must then sign in using email and password. Invalid credentials display a signup suggestion because Supabase does not distinguish an unknown email from a wrong password. Signup/resend have a 60-second client cooldown; server rate limits still apply. The Already received a code option lets an unconfirmed user resume after app restart.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:fa38bdc9a4b45a6858448acb3089bc3cdb8ff9ded9e6a33ec12bfcd62202b957 -->

2. Before distributing the updated Android app, add `space.freelan.app://login-callback/` under Authentication → URL Configuration → Redirect URLs. Keep `io.supabase.growthcircle://login-callback/` allowed while older app versions and previously sent recovery links are in use. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:9e0592e2021dcce4099a91f633877395cfe10c8c63e79795d14dae1bfa54f3eb -->

The current app verifies recovery OTPs in an isolated session; the URL remains necessary for older user app recovery links.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ae87e7b9ad6474da4755d50a24fed3ca759194e89d12befb8fdb545ba30a95b9 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f281b6fbd28e9a638d156e70d9294f3f4bfc60de25d3c896fe7468217c62bdec -->

3. In the SQL Editor, apply `supabase/migrations/20261107000000_growth_circle.sql` to a new project, then apply `supabase/migrations/20261107010000_owner_review.sql` once. Existing Freelan Space projects that already have the first migration only need the second. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:132c4708b1de61e31999242bc95cbe10e4a50ac66334906a3d05424758ce401e -->

The second migration changes the coin contract: new submissions require review. Later migrations also permit administrator editors to decide submissions.

<!-- /coderabbit-ai-generated:v1 --> It disables immediate claims from old APKs; distribute the upgraded APK after applying the migration. <!-- coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3030a55e17c45b50c9148e9cc745817009e204d58213b7dcdbe8d5ecd6754fe0 -->

Existing paid claims remain marked as legacy self-reports and are not reversed.

<!-- /coderabbit-ai-generated:v1 --> There is no automatic migration of Firebase accounts or data.

<!-- /coderabbit-ai-generated:v1 -->
4. Copy the project URL and publishable key (or legacy anon key) from the project's API settings. These are client-side values. Never put the service-role key or database password in the app.
5. Install Flutter 3.47.9, JDK 21 and the Android SDK, then run `flutter pub get` and build:

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:38bc30e3ffae6a6c634d87b2be22ccb891dffaec1f864293a62c2462b0ae6ef2 -->

For this Freelan Space project, use the checked-in public client configuration. Android user release builds reject missing or unsafe configuration. See [Android release recovery](docs/ANDROID_RELEASE_BUILD.md) for replacing the affected build16 with version1.1.9+17. For another project, supply its own public configuration file.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:feab8182865565dff88700f5c7a180d42c1197dbe1fc18d29d68be71759c7c1e -->

<!-- coderabbit-ai-generated-section:v1:af2b2ad3d9223e3a3d7d7520efc0c9b7493539560976e4847e950f2bfbe27960 -->

```sh
mkdir -p release-symbols
SYMBOLS_DIR="$(mktemp -d "$PWD/release-symbols/release.XXXXXXXX")"
flutter build apk --release --dart-define-from-file=config/production.json --obfuscate --split-debug-info="$SYMBOLS_DIR"
```

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cdf3790b66b8b62a19ec3bf70d716adbeec05a2420193ed0e111921511118131 -->

Debug builds show a setup screen if values are missing; Android user release builds now fail before packaging instead.

<!-- /coderabbit-ai-generated:v1 --> For a distributable release configure `android/key.properties` with `storeFile` (absolute path), `storePassword`, `keyAlias` and `keyPassword` for a securely retained release keystore. Keep the keystore and passwords private and backed up; future updates require the same signing key. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:de61abf7b131aaf3ae5fc1ac0e48c9b4080ecd739f5954886f4d1ca672357792 -->

Release APK and app bundle packaging fails with an actionable error when signing configuration is missing or incomplete, rather than creating an uninstallable unsigned package. Debug builds do not require this file. Keep using the same signing key for updates; an APK signed with a different key cannot update an installed app. To diagnose an existing APK, run `apksigner verify --verbose --print-certs app-release.apk` from Android SDK Build-Tools and compare the certificate with the installed release.

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e34f99d2a3fd37fcb3ae604015065399b2a5b886fc2fdd92354a37f11c57367c -->

The Android package name is `space.freelan.app`. This is a new Android installation: it cannot replace `com.growthcircle.growth_circle`. Users install it manually and sign in again; their existing Supabase accounts and server data remain available. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:661aea7a6bc0295b261819ce4cc69a065519135aea64c73b3a9c434940b3319b -->

The supplied Firebase configuration for `space.freelan.app` uses project `freelan-space`; verify that the server push worker uses this project before release. The earlier Android app used `growth-circle-c8efe`, so changing the worker project can affect its push delivery. Alternatively register the new package in the old Firebase project and replace the configuration file; see `docs/USER_FEATURES.md`. Production packaging requires the matching Firebase configuration and a signing keystore.

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:5c3bc7c9a47c40b7d935a2dd6323f92b52b12224bd9fa65802d911d1cfc38ecb -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c8f34ee9bae304071f9700732bd2e4c82da8f3ee1f58ae08c000d9545bbe5e50 -->

Current password recovery requests send an email OTP and use an isolated temporary session to set a confirmed new password. Older user apps use the recovery link in the shared email template. The app also accepts legacy callbacks for previously issued links; retain both redirect URLs until older clients and outstanding links are retired.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cd37f3b5cf27005467ce51dba5ef788d107000199de4aba6890481c57bfa8db9 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a98e37d76ff9563248a081ae337b40f87d0960362413007ec2bebd1247e4907f -->

## Android release signing

If you have an existing release keystore, use that same keystore and alias. If this app has never been distributed with a retained signing key, create one with `keytool -genkeypair -v -keystore ~/growth-circle-release.jks -alias growth-circle -keyalg RSA -keysize 2048 -validity 10000` and securely retain the keystore and passwords. A newly created key cannot update an app signed with another key.

Create `android/key.properties` locally (do not commit it):

```properties
storeFile=/absolute/path/to/growth-circle-release.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyAlias=growth-circle
keyPassword=YOUR_KEY_PASSWORD
```

Build with the Supabase project URL and public key shown above. Before sharing the APK, run `apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk`. To investigate an installation error, check the exact APK's signature, app ID, version code, and device architecture; the same message can have more than one cause.

## Windows administrator app

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:574f1f064021b2b79954e99a20f01c96d5e33fa6db54cf5ece2588fea1189ece -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d7497ac201d9c80d65ba10dce3c8363651734699dfc3ec01cb1c611f588fb192 -->

The Windows administrator app lists/searches accounts, shows coin balances, and blocks/restores app data access. It uses normal Supabase email/password authentication and the publishable/anon key; no service-role key is used or stored in the client. Blocking is enforced in database RLS and RPCs even for previously issued sessions; requests already in progress can finish before a block commits. After applying `supabase/migrations/20261116162613_account_block_realtime.sql`, updated user apps sign out when a block is received while connected, and recheck on startup, reconnection, resume and every 30 seconds while running. Offline or older clients may retain cached data until they reconnect or update. Supabase Auth sign-in itself remains available; a blocked user of the updated app is signed out again.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Apply migrations in order, including `supabase/migrations/20261107020000_admin_access.sql`, in the intended Supabase project. Then create a confirmed admin account through the existing app, and as the project owner run this in the Supabase SQL Editor after replacing the placeholder with that account's email:

```sql
insert into public.admin_members (user_id)
select id from auth.users
where lower(email) = lower('ADMIN_EMAIL_HERE') and email_confirmed_at is not null
on conflict (user_id) do nothing;
```

Only a database owner can provision administrators. The admin UI cannot block administrator accounts. Admin changes are recorded in `public.admin_access_audit`; that table and the admin allowlist are not directly readable or writable by app clients. No delete-account or coin-edit feature is provided.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:31b97719c787e6520a754072963f17bfc3206fb5b4bd351aa51ad9f3b2d0de0e -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:70b042161d85705e27ad0cfed458b21254052dc2006112a5ccee454cab9da524 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f434a160767ddba86c2fda78ab50811b9e492344382c458906df885a1292fd1a -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ecef63f81d8602246154419693588e6582eb983b5d8fb05ce53453025134bebc -->

On Windows with Flutter 3.47.9 and Visual Studio C++ tools, run `flutter pub get` and `flutter build windows --release -t lib/admin_main.dart --dart-define=AUTH_CAPTCHA_ENABLED=true`. Run `build\windows\x64\runner\Release\freelan_space_admin.exe` with the entire Release directory. A GitHub Actions workflow also produces a Windows ZIP artifact. On first launch enter the project URL and publishable/anon key, then sign in as the provisioned admin. The public project configuration is stored locally. When Save login is selected, the administrator login is stored using Windows secure storage; no service-role key is stored by the app. Supabase SQL deployment and a real Windows build must be verified on the target environment.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

For the admin workspace, reports, alert thresholds and viewer/editor roles, see [Admin workspace](docs/ADMIN_WORKSPACE.md).

<!-- /coderabbit-ai-generated:v1 -->

## Tests

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:58bf115b1cd3357bb53e5e0e96db454c86b715e5a78c3e28995f81aed7d1ae2f -->

Run `flutter analyze` and `flutter test`. PostgreSQL tests mock Supabase `auth.uid()` and must only be run against isolated disposable databases, never a real project. For the original contract use `supabase/tests/bootstrap.sql`, the original migration, then `python3 supabase/tests/integration.py DATABASE_NAME`. For owner review, use a separate fresh database with bootstrap and the original migration, then run `python3 supabase/tests/review_integration.py DATABASE_NAME`; this script applies the owner-review migration after creating historical claims. Tests require a PostgreSQL superuser and do not replace verification against Supabase Auth, Realtime or a real Android device.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f2f17671c506c58af26acf8ab677d734ecaa328e0bab90e83fda3cbcdf5c828f -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dd8737c9688b580259fd2d3f80adfd03b0afd0c1f3f266a036775b7109ba6356 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:907444502ca19dd120b7a8274d64fd7fe01235a134066b9b475dda7122ddef4b -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:00d23226cd9b44dff7373890f13416954c466ed19f96947df380fc36e9e8f145 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:40898aafea10f08a5e4c83d28271a67f3572bcd60748b57ef221489e5b77a5d5 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:70bf78bff72d93bf90e70badef71da3e261c6514ae11cd29fbd61a4dd25ea3b3 -->

## Instagram username lookup

For project `stpxbshwdiupigymakfy`, follow the [Malayalam live setup checklist](docs/INSTAGRAM_LIVE_SETUP.md). Hosted deployment and Meta access must be verified separately from source tests.

<!-- /coderabbit-ai-generated:v1 -->

The in-app lookup searches an exact username using Meta Business Discovery. Meta supports Business/Creator accounts for this endpoint; personal or age-restricted accounts may not be returned, partial-name suggestions are not supported, and a result does not establish ownership. Manual username entry remains available.

Apply `supabase/migrations/20261107070000_instagram_lookup_rate.sql` after all earlier migrations. Set up a Meta app and an authorized Instagram professional account using [Meta's Business Discovery requirements](https://developers.facebook.com/documentation/instagram-platform/instagram-graph-api/reference/ig-user/business_discovery): the applicable Facebook access token requires `instagram_basic`, `instagram_manage_insights` and `pages_read_engagement`; Meta app review or additional permissions may be required for your deployment. Obtain that authorized account's Instagram user ID and access token through Meta's official flow. The token belongs only on the server; do not put it in the Flutter app, source control, or chat.

Deploy `supabase/functions/instagram-lookup` to the same Supabase project. Set the Edge Function secrets `META_INSTAGRAM_USER_ID` and `META_INSTAGRAM_ACCESS_TOKEN` in Supabase's secret manager; the platform supplies `SUPABASE_URL` and `SUPABASE_ANON_KEY`. For example, after installing and authenticating the [Supabase CLI](https://supabase.com/docs/guides/functions/deploy), link the intended project and use `supabase secrets set --env-file <secure-file-outside-repository>` followed by `supabase functions deploy instagram-lookup`. The secure file contains those two `NAME=value` entries and must be protected and excluded from version control. Keep JWT verification enabled. Invalid/expired credentials show an unavailable message; rotate them through Meta and update the Supabase secrets. The server validates the user session, rejects blocked users and limits lookups to 20 per user per minute.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:0c829ef2a10d0ac13f82b0a314d87ef3ebcce2934d0131ccdccf13b5c84f8763 -->

## Task filters and notifications

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3fe50bf68fcd4089bb4ced784dc8c555991840b0fc9c848368878a3c9b8c4327 -->

Earn tasks can be filtered by Follow, Like, Comment or Share; submission history stays visible. Apply `supabase/migrations/20261107080000_notifications.sql` after the earlier migrations and enable the `notifications` table in Supabase Realtime if it is not already published. The new migration records future approvals, rejections and positive coin ledger entries transactionally; earlier events are not backfilled. Signed-in active users can view only their own notifications and mark them read. An unread indicator and list update while the app is open and connected. These are in-app notifications. Optional Android push requires the additional setup in [User app features and Android push setup](docs/USER_FEATURES.md).

<!-- /coderabbit-ai-generated:v1 -->

## Administrator submission inspection

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107060000_admin_submission_review.sql` after the preceding migrations. Administrators can inspect pending usernames and screenshots; each inspection is recorded in a private audit table. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3ceeea8a6f7add72f8994cabee4291ff7327c84afdd653ca3f0705c0dd1a589c -->

Participants see “AI is checking your submission” while an administrator is checking it.

<!-- /coderabbit-ai-generated:v1 --> The indicator expires after two minutes without a connection and is refreshed while the inspection is open. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:cfeb64b3a72bb07bf2b68757c24137fd4b78ede075171f5f6efda8526a77f2aa -->

<!-- coderabbit-ai-generated-section:v1:c947922b7af6c02433f24827dfe2d96ecbc57f451cc2fb08fdec2ee03b53f90b -->

Campaign owners can make approval decisions using their PIN. After `20261119074241_admin_users_and_submission_decisions.sql`, MFA-verified editors can also approve or reject independently. No AI review is performed.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

## Administrator campaign overview

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107050000_admin_campaigns.sql` after the preceding migrations. The administrator app can list campaigns by action and status, including their owner email and task progress. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:7c61c051ab47f1de730559a2c54dd6684a9a255f8ac029ed45a33523f35a20a6 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c380870997a8121922c42e7b0bd3561d95f68c1393a31e0726c3f67984972d0a -->

Campaign owners and administrator editors can decide pending submissions as described above.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

## Administrator action controls

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:d9800465e09a152836be6b55f9a44f07370ef3fafecdc1cb0bda326b5e83b80f -->

Apply `supabase/migrations/20261107040000_admin_action_controls.sql` after the preceding migrations and distribute updated user and administrator apps. In the administrator app, open Action controls to enable or disable Follow, Like, Share and Comment independently. Disabling an action blocks new campaigns and submissions for that action on the server, including requests from older clients. Operations already in progress can finish before the change commits. Existing submissions remain available for owner review or withdrawal, and campaign cancellation still refunds unused coins. These controls apply inside Freelan Space; they cannot control actions directly on Instagram.

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:1ce76b4e4b99a55e89f1d4c9b37beb991ebf83d06740bce98ae128c6b9a4acd4 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:3a88de9ea64157cf907adfedb072d93bae9ecee31ede80d08208ef681ef934c8 -->

## Security hardening

Apply `supabase/migrations/20261107100000_security_hardening.sql` after **all ten earlier migrations**, then distribute updated user/admin apps. If Instagram lookup is deployed, redeploy its updated Edge Function as well; lookup activation remains separate.

- App data and coin RPCs now require a real account with a confirmed email. Anonymous Auth sessions and unconfirmed accounts cannot bypass the signup UI to initialize wallets or earn referral credits. User-editable metadata is not accepted as email verification. Existing RLS ownership and administrator checks remain enforced.
- PIN setup/reset now checks the current confirmed account email against the signed JWT email. Generic `otp` AMR can also represent SMS, so PIN setup/reset explicitly rejects accounts with a linked phone or JWT phone claim. This app supports email account login; phone-linked accounts need account support before changing their PIN. Existing PINs still release coins for active verified-email users. Freshness, one-use OTP proof and five-failure/15-minute release lockout remain intact. A stale email claim must be refreshed before setup/reset.
- Evidence remains JPEG/PNG and at most 512 KiB, and now must also be static and no more than 4096 pixels in either dimension. The database checks PNG/JPEG metadata for new writes. Both reviewer apps check dimensions before decoding and validate a bounded thumbnail before rendering. Historical malformed evidence is not deleted by the migration; updated owners can reject it, while approval stays disabled when evidence cannot be safely decoded. A dimension check is not a claim that a screenshot proves Instagram activity.
- The lookup Edge Function stops reading request bodies at 2048 bytes and cancels stalled reads after eight seconds. This applies before upstream API calls; credentials remain server-side.
- <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:ca9153e3e05d9bc23d6c86480c0b08bedb2b4d4603346477f3e2aa5253f94707 -->

Android debug, profile and release builds disallow cleartext HTTP. App backup is disabled, with Android 12+ cloud/device-transfer exclusions to keep stored login sessions from being copied. Debug tooling that needs cleartext network access may be affected.

<!-- /coderabbit-ai-generated:v1 --> See [Android backup configuration](https://developer.android.com/identity/data/autobackup).

Verification: Flutter analyzer and all 52 tests passed; isolated PostgreSQL security/economy/notification/action/admin-inspection/lookup tests passed; Edge handler tests and Deno checks passed; Gradle debug/release manifest merging and debug resource compilation passed. A query of OSV for the 93 hosted packages in the unchanged lockfile returned no listed advisories. These checks use synthetic Auth/Meta fixtures and do not establish live Supabase configuration, actual OTP delivery, native device behavior or production deployment. Committing migrations and pushing GitHub does **not** apply them to Supabase.

## Coin settings, referral rewards and email OTP PIN

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107090000_coin_settings_referrals_pin_otp.sql` **after all preceding migrations**, including `20261107080000_notifications.sql`. Distribute updated user and administrator builds with this migration. Old clients cannot set/change a PIN after the upgrade; existing PINs still release coins. New clients use `create_campaign_at_rate` to reject a changed price before spending coins. Legacy creation requests use the current configured rate: retire old builds before changing task prices, because they display a fixed one-coin cost.

In the administrator dashboard, choose **Coin settings**. Defaults and limits:

| Setting | Default coins | Allowed range |
| --- | ---: | ---: |
| Registration bonus | 10 | 0–10000 |
| Follow / Like / Comment / Share | 1 each | 1–10000 |
| Each successful referral | 100 | 0–10000 |
| 5 / 10 / 15 referrals: extra milestone bonus | 100 / 200 / 300 | 0–10000 each |

Only active administrators can change settings, and each change is audited. Registration changes affect wallets initialized afterward. Each new campaign saves its reward; approval and cancellation use that saved amount. Existing campaigns retain a one-coin reward. Available task cards show the reward; the creation form shows the total reservation and rejects a stale displayed rate.

A referral is credited when a signed-in user successfully applies another account's valid referral code. The inviter must have initialized their wallet. Credit and notifications commit in the same transaction. Self-referrals and duplicate codes for a joined user are rejected. At invite 5, 10 and 15, the current extra milestone amount is added to that invite's reward once. A zero setting disables that credit. Historical referrals receive no backfill; previously achieved milestones are recorded as consumed without payout. A zero-valued milestone is also consumed when reached. Deleting a referred account cannot earn the same milestone again. These are account referrals; they do not prove an Instagram follow or prevent someone registering multiple email accounts.

### Email OTP configuration and PIN recovery

1. In Supabase Authentication, keep **Email** authentication enabled. Configure SMTP/email sending and provider rate limits for production. This app uses email accounts; phone OTP is not an app login flow.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a55fdd09bd5f1bf05679e8a231eb4b5a4395525edfb11b809a88e3ddabde8912 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:eac21dc7e8ecb624c9b7563a920cf20f7f33f96059e00a693e534b8fba760b99 -->

2. In **Authentication → Email Templates → Reauthentication**, use `supabase/templates/reauthentication.html` with `{{ .Token }}` and subject **Freelan Space PIN verification**. Set email OTP length to six digits. PIN setup/reset uses authenticated `reauthenticate()`, not Magic Link. Signup and password recovery templates are separate. Apply the latest `pin_reauthentication` migration and distribute the updated Android build; see [PIN reauthentication](docs/PIN_REAUTHENTICATION.md).

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
3. In Profile, choose **Coin release PIN → Set up** or **Change / reset PIN**. Send the OTP to the signed-in email, enter that code, then enter and confirm the new four-digit PIN. The app permits resend after 60 seconds; Supabase may impose a longer sending limit.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f76d3dd6d80d9ecd3e66371fd5a4070029651941292f002a821d5745dc56ccf8 -->

4. The signed-in session sends the Reauthentication email, then calls `set_release_pin_reauthenticated` with the PIN and nonce. The server checks current verified email identity, a five-minute nonce lifetime and at most five incorrect attempts per issued nonce; successful use consumes the nonce atomically. Passwords and sessions are unchanged. The previous `set_release_pin` endpoint now returns `otp_required`; old clients cannot set/reset PINs. Existing PIN hashes and coin release lockout remain intact. This intentionally supersedes the earlier Magic Link / OTP-AMR proof contract.

<!-- /coderabbit-ai-generated:v1 -->
5. A successful email-verified reset clears PIN lockout. Releasing coins still requires the PIN and retains the five-failure, 15-minute lock. Verify email delivery, first setup, forgotten-PIN recovery and approval on your live project before distributing builds.

Local verification uses Flutter tests plus `python3 supabase/tests/economy_integration.py DATABASE_NAME` after `bootstrap.sql` and all migrations in an isolated PostgreSQL database. The test bootstrap's `auth.jwt()` is a privileged mock; **never install that bootstrap in Supabase**. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:568a3f680279c7cafcd1ebb18a7d222eec126f871abadff8a2d03003ff8ca51b -->

Notification/action/admin inspection tests seed a synthetic Auth reauthentication nonce through `pin_test_support.py` for setup; they do not exercise email delivery.

<!-- /coderabbit-ai-generated:v1 --> Existing `profile_integration.py` documents/tests the earlier four-migration PIN contract and must use that earlier schema.

Live rollout is not performed by committing SQL or pushing GitHub. Apply only unapplied migrations in the correct project, configure email templates/SMTP, and verify actual email and Realtime delivery. No Edge Function or Meta credentials are required for these features. Instagram live search remains separate.

## Profile and release PIN upgrade

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->

Apply `supabase/migrations/20261107030000_profile_pin_referrals.sql` after the administrator migration. Distribute the updated app at the same time: older clients cannot review submissions after this upgrade. Owners must set a four-digit PIN in Profile before approving and releasing a coin. Five incorrect attempts lock the PIN for 15 minutes. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c009fa4e50f7f72b3f0068404f465c0032a57f65fbca343e81865be63df838e7 -->

After the economy/OTP upgrade below, both initial PIN setup and change/reset require a fresh email OTP instead of the current PIN. PIN release attempts retain the five-attempt lockout.

<!-- /coderabbit-ai-generated:v1 -->

Profile supports multiple Instagram usernames, a separate coin history page and referral codes. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:720f73b969649381e83927dd616b5bbf422f53a0e5b4cb7853aaddfb87af416a -->

A user can apply one other user's code once. The economy migration below enables configurable rewards for future referral events.

<!-- /coderabbit-ai-generated:v1 -->

## Coin model

<!-- /coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c64faf45931f12ec47d077d6d2401381342ff7988e233c74cb245f02e21f94de -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:edb3e906f6395dd43354cbb3a3b30fb96533f500b6227a5099e527c48b29fa98 -->

The default registration bonus is 10 coins once, and the default campaign reward is one coin per task. After the economy migration, administrators can change both. Campaigns reserve the configured reward multiplied by the requested task count.

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:8e0b2abfa5f49ef6b6fcca81b7a2c836a041f5c5cfa65a6b99fa5ac6e2d7fe70 -->

A participant submits an Instagram username and a JPEG or PNG screenshot (maximum 512 KiB). The campaign owner or an MFA-verified administrator editor can review it and approve or reject it.

<!-- /coderabbit-ai-generated:v1 --> <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:04c6b5e61c4712e1f6c99ef7592762da032e646f0bf8ddc1006f9c76cef62ee8 -->

Approving pays the campaign's saved reward and consumes one reserved task. Later setting changes do not alter existing campaign payouts or refunds.

<!-- /coderabbit-ai-generated:v1 --> Rejecting or withdrawing reopens the slot. Cancellation refunds all unapproved slots, including pending submissions. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:fe5d94089b88fd5520ac3eac467b5dcf4d301cd218dd3803a58442b0e7928c07 -->

Campaign owners, the claimant and administrators can access pending evidence. Evidence is deleted on review, withdrawal or cancellation.

<!-- /coderabbit-ai-generated:v1 --> A submission identifier prevents approving a replacement using stale evidence. Row locks serialize submission, decisions and cancellation. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:23ba3e61e44ea6b383e78113db5aba087f9dd4a8226ec86c5c1503e9d774b855 -->

Legacy claims remain paid and are displayed as self-reported, not owner-approved.

<!-- /coderabbit-ai-generated:v1 --> Owner review and screenshots do not verify or guarantee real Instagram engagement and may be abused. Review Instagram policies before distribution.

<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->


<!-- /coderabbit-ai-generated:v1 -->