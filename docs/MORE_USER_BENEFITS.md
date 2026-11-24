<!-- coderabbit-ai-generated:v1 -->

# Additional user benefits

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b5c7b78aa75a5b06970f3aa1c59133ec2f08a5fbffecd6c1d7fc81dd80329717 -->

Migration `20261124142627_more_user_benefits.sql` was applied to project `stpxbshwdiupigymakfy` on 2026-11-24, and `push-delivery` version 26 was deployed with JWT verification enabled. Distribute updated user and admin apps. Existing seven feature controls remain available. Actual Auth events, CSV sharing and FCM delivery require separate device verification.

<!-- /coderabbit-ai-generated:v1 -->

## Admin settings

In User features, an MFA-verified editor can enable or disable daily check-in, badges, drafts, coin goals, wallet statements, saved-task alerts, support references and login alerts. Viewers can inspect settings. Reward settings separately control the check-in amount, total daily coin cap and badge bonuses for 5, 10 and 25 approvals; changes are audited. The default check-in reward is 1 coin with a 1,000 coin UTC-day cap; each badge bonus defaults to 0. A zero check-in amount disables payouts. Each user may claim one check-in per UTC day. Server locks, unique records and a global issuance counter prevent duplicate credits and enforce the cap even after account deletion. As with existing registration/referral rewards, multiple accounts are not proof of distinct people.

Badge eligibility counts retained approved submission attempts. Badges reflect app review decisions and do not verify Instagram activity. Users can claim each configured milestone bonus once; a zero bonus leaves the badge visible and can be configured later. Past retained approvals count; attempts lost before history retention cannot be reconstructed.

## User experience

Campaign drafts store at most 10 drafts per user, without reserving coins. Loading a draft rechecks account selection, current campaign limits and prices before creation. The coin goal uses available wallet balance; it is informational and does not reserve coins. Wallet statements use UTC date boundaries and contain the signed amounts, reasons and references; Android's share sheet lets users save or share CSV files. Exports can contain private financial information.

Support references are checked on the server: users can request help only for their own campaign or ledger entry. Support tickets receive its order or transaction reference. <!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:f5ac13efd33a3db54c895db2636709834804ee0cad915ec59f37bd75adbc5d73 -->

Saved task alerts are created on campaign completion or cancellation, include the saved link in the in-app notification and follow the existing task-notification preference. Push messages remain generic.

<!-- /coderabbit-ai-generated:v1 --> Login alerts are based on changes to `auth.users.last_sign_in_at`; provider behavior and device delivery must be verified with the actual Supabase Auth setup. Notification failure does not block sign-in.

New per-user benefit records are included in the existing deletion audit archive before account deletion. The global daily issuance total is kept separately to preserve the cap. Test an updated Android device and admin application, including date selection, CSV sharing, login notification delivery and support before release.
