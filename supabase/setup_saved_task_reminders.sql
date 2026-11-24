-- Run once as database owner after enabling pg_cron and applying the migration.
-- Check the existing job first; unschedule it before rescheduling when needed.
select cron.schedule('freelan-saved-task-reminders', '* * * * *',
  $job$select public.dispatch_saved_task_reminders(500);$job$);
