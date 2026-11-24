<!-- coderabbit-ai-generated:v1 -->

# Engagement benefits and controls

In User feature controls, administrators can switch each of the eight features on or off. Editors with MFA can set the weekly challenge target, reward and global weekly coin limit, and create, edit, publish or hide help articles. Defaults are five approved submissions, zero reward, and a 1,000 coin weekly limit; the zero reward prevents payouts until configured. Weekly periods and monthly insight boundaries use UTC. Challenge completion counts retained approvals reviewed during the current week, and each user may claim once. The global issuance counter survives account deletion.

Resubmission help directs users to the original task when it remains available; the existing submission API still checks eligibility and requires a new screenshot. Campaign copy fills the creation form without reserving coins; current account, rate, limits and confirmation checks still apply. Monthly insights summarize positive task, referral and bonus ledger entries; these are app coins.

Users may choose a reminder time for a saved task, up to 30 days ahead. Unsaving removes its reminder. The dispatch job processes up to 500 due reminders per run. Users can choose progress alerts and a low-balance threshold; low-balance alerts fire when available balance falls below that threshold and can fire again only after it recovers. Task and coin notification preferences, push opt-in and quiet hours apply. Campaign progress alerts are emitted at 50% and 100% of approved tasks. If a campaign crosses both thresholds in one update, one completion alert is emitted. Historic events are not backfilled.

## Rollout

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:c8ca73c729066fa3f16cc125abc1dde06ce896a2ad367e4d96bd25d8997d7dd2 -->

1. The `engagement_benefits` migration was applied to the connected project as version `20261124163802`, matching `supabase/migrations/20261124163802_engagement_benefits.sql`. The updated `push-delivery` function was deployed as version 27 with JWT verification enabled.
<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:2eed15de9b401f2788457ca6c7cd29f9b4186c3c583d3abe96b77e4202c665bc -->

2. The `freelan-saved-task-reminders` schedule runs every minute; its 16:40 UTC run on 2026-11-24 succeeded. The existing push and review schedules remain active. Worker version 27 returned HTTP 200, but actual device delivery and scheduled reminders with user data still need testing.

<!-- /coderabbit-ai-generated:v1 -->

<!-- /coderabbit-ai-generated:v1 -->
3. Build and distribute updated user and admin apps. Test reward claims, schedule timing, mobile notifications, campaign copy and resubmission with real devices. Local tests use synthetic accounts and do not deploy these changes.
