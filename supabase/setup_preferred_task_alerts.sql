-- Run as database owner after enabling pg_cron and applying the migration.
-- Re-running under the same owner updates the existing named schedule.
select cron.schedule('freelan-preferred-task-alerts', '* * * * *',
  $job$select public.dispatch_preferred_task_alerts(500);$job$);
