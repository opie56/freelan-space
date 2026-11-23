<!-- coderabbit-ai-generated:v1 -->

# Administrator desktop controls

## Delivery channels

Send notification has separate In-app notification and Push notification checkboxes. Select either or both. Push only messages are excluded from the user's notification inbox through database RLS. Existing clients keep sending to both channels. Retrying the same request and delivery selection does not duplicate notifications.

## Saved sign-in and password recovery

After a successful administrator password sign-in and MFA challenge, Save login securely stores one login per project using flutter_secure_storage on the current Windows account. Click the email field on a later visit to fill the saved email/password. Passwords remain obscured until the visibility control is used. Forget saved login removes the protected entry. No passwords are stored in preferences.

In Supabase Dashboard → Authentication → Email Templates → Reset Password, set the recovery email body to the contents of supabase/templates/recovery.html. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:950f4dd2d778593bb15f45f11b171dada12c84c83e60a55c26a3c8baa1ae140d -->

The shared template includes {{ .Token }} for six-digit recovery OTPs and {{ .ConfirmationURL }} for older user-app recovery links.

<!-- /coderabbit-ai-generated:v1 --> Preserve configured SMTP, expiry and rate limits. This dashboard setting cannot be applied through the connected Supabase tools.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:2ea451984ab16bbdeb747c10c3b18f330919dcca363934b34410d07e93e5f9d5 -->

Forgot password uses an isolated recovery client: request email, verify the recovery OTP, then set matching passwords meeting the requirements in [Password policy](PASSWORD_POLICY.md). It does not authorize the administrator console. After reset, the saved login is removed and password sign-in/MFA must be completed again. Test the recovery email with your SMTP configuration.

<!-- /coderabbit-ai-generated:v1 -->

## Sessions

Use the Session settings clock button in the bottom right. Choose manual sign-out or 10/30/60 idle minutes, and whether minimizing signs out. Defaults preserve the former 10 minute timeout and sign-out on minimize. Preferences apply to this Windows account. Server session expiry, revoked access and MFA checks still apply. A transient access-check network error no longer logs out the UI; API operations continue to enforce server authorization.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c84826096a7229c4f163546c3a9397558389bdfe1efb4fb638f704aa94422fe7 -->

## Official social links

After `20261118130000_random_references_social.sql` is applied, open **Official social links** in the Windows admin sidebar. An editor with an MFA-verified session can save or clear each official Instagram, Facebook, YouTube and X profile URL. Only HTTPS URLs on the corresponding platform's approved domains are accepted. Changes are audited. Configured links are publicly readable so signed-out users can open them from the updated user app's sign-in screen; an unset platform is hidden. No profile URLs are prefilled.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:dc42661841a3b7e3a3af59192b2a6e951600eda2e034b1c5ea3f77e11bf71571 -->

The user app language picker offers English, Hindi, Tamil, Arabic and Malayalam. User-facing labels and messages use bundled translations, without sending account information to a translation service. Test translated content and Arabic layouts on a real device before release.

<!-- /coderabbit-ai-generated:v1 -->

## Users and wallets

<!-- /coderabbit-ai-generated:v1 -->

Users displays separate name, email, public eight-digit user ID, join date, coins and role/status columns. Copy controls are available for name/email/public ID, including the compact layout.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f80d555f7cad7243f7420641e0bc79ec8d326ee31d588c7570f53fcd82e4928c -->

**Wallets Management** replaces the previous coin correction approval workflow after `20261118120000_wallets_management.sql`. Search by name, public User ID or wallet number, then add, deduct, debit, hold, release, transfer or activate/deactivate coins and wallet access. A single editor completes the action in the verified session with a reason; viewers can search and inspect operation history. See [Wallets Management](ADMIN_OPERATIONS.md#wallets-management-and-notes) for hold/deactivation semantics, retry behavior and receipt push deployment. Review the user's full coin ledger under User details.

<!-- /coderabbit-ai-generated:v1 -->

## Verification

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:71b8d04cf05628e144705b1bdda559edd23bec91d14e82af4789dc72f36a1c4d -->

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:e908495bef61163b3b70b21e9b9bebe28ee031b011a396e14882919f5251c800 -->

The Wallets Management update passed Flutter analysis, 219 Flutter tests, all 31 current-contract PostgreSQL suites after replaying 43 repository migrations, nine push-worker tests, and a synthetic Android debug build. The `wallets_management` migration and updated push worker were applied to project `stpxbshwdiupigymakfy`; live schema/permissions were checked without changing user balances. These checks cover channel isolation, direct editor operations, retired approval writes, durable retries, wallet holds and balance protection. Windows secure storage, autofill and native layout, real email recovery, and Android FCM delivery still require device acceptance checks. The recovery email template above cannot be inspected or updated through the connected tools; verify it in the Supabase Dashboard.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
