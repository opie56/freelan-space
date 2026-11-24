<!-- coderabbit-ai-generated:v1 -->

# Task clarity and privacy features

Admin editors can enable or disable task instructions, screenshot editing, submission waiting time, report tracking, notification filters, private saved-task notes, preferred-task alerts and monthly spending insights independently in User feature controls.

Campaign owners may add instructions when creating a campaign or edit them while it is active. The new creation RPC calls the existing account, plan, price and balance checks in the same transaction. Instructions are visible to users who can see the campaign; disabling the feature hides instructions in the updated app and prevents writes.

Screenshot editing is local. The editor renders a new PNG before the existing evidence validation and upload. Crop removes pixels outside the selection, blur obscures selected regions, and black-out replaces selected pixels with black. The final image appears in the submission preview; users should check it before sending. Encoding may exceed the existing 512 KiB limit; the user can choose a smaller crop. Blur may leave recognizable detail; black-out gives stronger redaction. No original image is uploaded by the editor.

Waiting time reflects the device clock and stored submission time, not a review guarantee. Report tracking returns only the caller's reports as open or resolved, without private administrator details. Notification filters operate on retained in-app records; the existing 72-hour retention still applies.

Saved notes are available only through the owner's app API while saved. Unsaving the task removes the note. The existing deleted-account audit ordinarily archives business records for administrators, but these new private notes and alert delivery logs are intentionally excluded; they are deleted with the task or account. Database operators with privileged access can read stored notes. Preferred category settings remain in the existing deletion archive.

Preferred-task alerts are opt-in. Only campaigns created after opt-in are considered, after the existing one-minute publication delay, while active, unpaused and in an enabled category. The dispatcher handles up to 500 per run and deduplicates by user and campaign. Task notification preferences and quiet hours apply; disabling the feature prevents new dispatches but does not recall already queued notifications. Monthly spending uses UTC, separates campaign reservations, transfers and other debits, and shows refunds separately; these are app coins.

## Rollout

1. Apply `supabase/migrations/20261124180000_task_clarity.sql` after all earlier migrations.
2. Deploy the updated `push-delivery` function with its existing JWT verification and worker secret configuration. Configure `supabase/setup_preferred_task_alerts.sql` as database owner with pg_cron; confirm one active schedule and successful runs.
3. Build and distribute updated user and admin applications. Test screenshot editing and submission, owner instructions, notification preferences, new category alerts, report privacy and device delivery. Local tests use synthetic data and do not deploy production changes.
