<!-- coderabbit-ai-generated:v1 -->

# User benefits and administrator controls

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:b78deecb7cb02aa6103dab4098b73d306cace98d1b63764d8921abdd17104252 -->

Migration `20261124133002_user_benefit_controls.sql` was applied to project `stpxbshwdiupigymakfy` on 2026-11-24, and `push-delivery` version 25 was deployed with JWT verification enabled. The hourly `freelan-pending-review-reminders` job was configured; check its first run and actual Android push delivery. Distribute updated user and admin apps. In the admin console, **User features** lets MFA-verified editors enable or disable the seven features. Viewers have read-only access. Changes are audited. Open screens refresh settings when reopened; older apps do not display the new controls.

<!-- /coderabbit-ai-generated:v1 -->

## Pending review reminders

Enable pg_cron and run `supabase/setup_review_reminders.sql` as the database owner. It schedules an hourly job named `freelan-pending-review-reminders`; confirm exactly one active job and inspect `cron.job_run_details`. The job sends at most one reminder per pending submission each 24 hours after the submission has waited 24 hours. Delivery to Android requires the existing push setup and the updated worker. Pausing the feature prevents new reminders; existing notifications and queued pushes are not recalled.

## Appeals and insights

A rejected submission can be appealed once through submission history. It creates a support ticket referencing the submission and campaign. Admins respond through Users Supports; an appeal does not automatically reverse a decision or award coins. The original evidence is deleted on review under the existing contract, so support must request further information if necessary. Campaign insights summarize retained submission history, including repeated attempts; approval rate is approved divided by approved plus rejected. Older attempts that were overwritten before history retention cannot be recovered. Instagram activity is not automatically verified.

## Coins and notification preferences

The weekly summary uses Monday to Sunday UTC and sums positive and negative ledger entries separately. Amounts include credits, debits, campaign reservations and refunds; they are not cash earnings. Notification categories control future in-app and push delivery of task decisions and review reminders, coin credits, and referral credits. Support, app updates and administrator messages are unaffected. Transactional notification records remain stored; previously delivered or queued notifications are not recalled. Disabling the preferences feature prevents changes but preserves user choices.

The first-task guide is dismissed per account and device. The search and guide controls apply in the updated app when the relevant screen loads. Verify migration, scheduled reminders, actual FCM delivery, user and admin workflows on their target environments before release.
