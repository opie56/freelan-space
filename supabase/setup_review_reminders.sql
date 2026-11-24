-- Run as the database owner after enabling pg_cron and applying migrations.
-- This schedule invokes the service-only function once per hour.
select cron.schedule('freelan-pending-review-reminders', '0 * * * *',
  $job$select public.send_pending_review_reminders();$job$);
