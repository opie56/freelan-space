-- User features are independently controlled by MFA-verified administrators.
begin;
create table growth_internal.user_feature_settings (
  key text primary key,
  enabled boolean not null default true
);
insert into growth_internal.user_feature_settings(key) values
 ('task_search'),('review_reminders'),('submission_appeals'),('coin_summary'),
 ('campaign_insights'),('notification_controls'),('guided_task');
revoke all on growth_internal.user_feature_settings from public,anon,authenticated;

create function public.user_feature_settings() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 return (select jsonb_object_agg(key,enabled) from growth_internal.user_feature_settings);
end $$;
create function public.admin_user_feature_settings() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 return (select jsonb_object_agg(key,enabled) from growth_internal.user_feature_settings);
end $$;
create function public.admin_set_user_feature(p_key text,p_enabled boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 if p_enabled is null then raise exception 'Invalid feature setting.' using errcode='P0001'; end if;
 update growth_internal.user_feature_settings set enabled=p_enabled where key=p_key;
 if not found then raise exception 'Unknown feature.' using errcode='P0001'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action,details)
 values(auth.uid(),'User feature setting',jsonb_build_object('key',p_key,'enabled',p_enabled)::text);
end $$;

create function public.user_weekly_coin_summary() returns jsonb language plpgsql security definer set search_path='' as $$
declare start_at timestamptz := date_trunc('week',now() at time zone 'UTC') at time zone 'UTC';
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='coin_summary') then raise exception 'Feature unavailable.' using errcode='P0001'; end if;
 return (select jsonb_build_object('start_at',start_at,'earned',coalesce(sum(amount) filter(where amount>0),0), 'spent',coalesce(-sum(amount) filter(where amount<0),0))
 from public.coin_ledger where user_id=auth.uid() and "createdAt">=start_at and "createdAt"<start_at+interval '7 days');
end $$;

create function public.user_campaign_insights(p_campaign uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='campaign_insights') or not exists(select 1 from public.campaigns where id=p_campaign and "ownerId"=auth.uid()) then raise exception 'Campaign unavailable.' using errcode='P0001'; end if;
 return (select jsonb_build_object('approved',count(*) filter(where status='approved'),'rejected',count(*) filter(where status='rejected'),
 'average_review_seconds',avg(extract(epoch from (reviewed_at-submitted_at))) filter(where status in ('approved','rejected') and reviewed_at>=submitted_at))
 from public.submission_history where campaign_id=p_campaign);
end $$;

create table growth_internal.submission_appeals (
 submission_id uuid primary key references public.submission_history(submission_id) on delete cascade,
 ticket_id uuid not null unique references growth_internal.support_tickets(id) on delete cascade
);
revoke all on growth_internal.submission_appeals from public,anon,authenticated;
create function public.appeal_submission(p_submission uuid,p_message text) returns uuid language plpgsql security definer set search_path='' as $$
declare h public.submission_history%rowtype; ticket uuid; message text:=btrim(coalesce(p_message,''));
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='submission_appeals') then raise exception 'Feature unavailable.' using errcode='P0001'; end if;
 if length(message) not between 1 and 1500 then raise exception 'Enter an appeal message.' using errcode='P0001'; end if;
 select * into h from public.submission_history where submission_id=p_submission and user_id=auth.uid() and status='rejected' for update;
 if not found then raise exception 'Submission unavailable.' using errcode='P0001'; end if;
 if exists(select 1 from growth_internal.submission_appeals where submission_id=p_submission) then raise exception 'An appeal has already been submitted.' using errcode='P0001'; end if;
 ticket:=public.support_create_ticket('Submission appeal', 'Submission ID: ' || p_submission::text || E'\nCampaign ID: ' || h.campaign_id::text || E'\n\n' || message);
 insert into growth_internal.submission_appeals values(p_submission,ticket);
 return ticket;
end $$;

create table growth_internal.user_notification_preferences (
 user_id uuid primary key references auth.users(id) on delete cascade,
 task_updates boolean not null default true,
 coin_updates boolean not null default true,
 referral_updates boolean not null default true
);
revoke all on growth_internal.user_notification_preferences from public,anon,authenticated;
create function public.user_notification_preferences() returns jsonb language plpgsql security definer set search_path='' as $$
declare pref growth_internal.user_notification_preferences%rowtype;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='notification_controls') then raise exception 'Feature unavailable.' using errcode='P0001'; end if;
 select * into pref from growth_internal.user_notification_preferences where user_id=auth.uid();
 return jsonb_build_object('task_updates',coalesce(pref.task_updates,true),'coin_updates',coalesce(pref.coin_updates,true),'referral_updates',coalesce(pref.referral_updates,true));
end $$;
create function public.set_user_notification_preferences(p_task boolean,p_coin boolean,p_referral boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='notification_controls') or p_task is null or p_coin is null or p_referral is null then raise exception 'Invalid preferences.' using errcode='P0001'; end if;
 insert into growth_internal.user_notification_preferences values(auth.uid(),p_task,p_coin,p_referral)
 on conflict(user_id) do update set task_updates=excluded.task_updates,coin_updates=excluded.coin_updates,referral_updates=excluded.referral_updates;
end $$;
-- Keep transactional receipts while respecting preferences for future display and push.
create function growth_internal.apply_notification_preferences() returns trigger language plpgsql security definer set search_path='' as $$
declare allowed boolean;
begin
 select case when new.kind in ('approved','rejected','review_reminder') then task_updates
             when new.kind='coins_received' and new.credit_source='referral' then referral_updates
             when new.kind='coins_received' then coin_updates else true end
 into allowed from growth_internal.user_notification_preferences where user_id=new.user_id;
 if allowed=false then new.show_in_app:=false; new.deliver_push:=false; end if;
 return new;
end $$;
create trigger notification_preferences before insert on public.notifications for each row execute function growth_internal.apply_notification_preferences();

-- Preferences can suppress both channels; remove those records on the same
-- retention schedule while preserving the existing push-only exclusion.
create or replace function growth_internal.purge_expired_user_notifications()
returns bigint language sql security definer set search_path='' as $$
 with deleted as (delete from public.notifications where (show_in_app or not deliver_push) and created_at<=now()-interval '72 hours' returning 1)
 select count(*) from deleted;
$$;

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update','admin_message','review_reminder'));
create table growth_internal.review_reminder_log (
 submission_id uuid primary key references public.submission_history(submission_id) on delete cascade,
 last_sent timestamptz not null
);
revoke all on growth_internal.review_reminder_log from public,anon,authenticated;
-- Scheduled by a database owner. One reminder per submission per 24 hours.
create function public.send_pending_review_reminders() returns integer language plpgsql security definer set search_path='' as $$
declare r record; sent integer:=0; claimed uuid;
begin
 if not (select enabled from growth_internal.user_feature_settings where key='review_reminders') then return 0; end if;
 for r in select cl.submission_id,c."ownerId" owner_id from public.campaign_claims cl join public.campaigns c on c.id=cl.campaign_id
  where cl.status='pending' and c.status='active' and cl.created_at<=now()-interval '24 hours'
   and not exists(select 1 from growth_internal.review_reminder_log l where l.submission_id=cl.submission_id and l.last_sent>now()-interval '24 hours')
  order by cl.created_at limit 500 for update of cl skip locked loop
  claimed:=null;
  insert into growth_internal.review_reminder_log(submission_id,last_sent) values(r.submission_id,now())
  on conflict(submission_id) do update set last_sent=excluded.last_sent where growth_internal.review_reminder_log.last_sent<=now()-interval '24 hours'
  returning submission_id into claimed;
  if claimed is not null then
   insert into public.notifications(user_id,kind) values(r.owner_id,'review_reminder');
   sent:=sent+1;
  end if;
 end loop;
 return sent;
end $$;
revoke all on function growth_internal.apply_notification_preferences() from public,anon,authenticated;
revoke all on function public.send_pending_review_reminders() from public,anon,authenticated;
grant execute on function public.send_pending_review_reminders() to service_role;
revoke all on function public.user_feature_settings(),public.admin_user_feature_settings(),public.admin_set_user_feature(text,boolean),public.user_weekly_coin_summary(),public.user_campaign_insights(uuid),public.appeal_submission(uuid,text),public.user_notification_preferences(),public.set_user_notification_preferences(boolean,boolean,boolean) from public,anon;
grant execute on function public.user_feature_settings(),public.admin_user_feature_settings(),public.admin_set_user_feature(text,boolean),public.user_weekly_coin_summary(),public.user_campaign_insights(uuid),public.appeal_submission(uuid,text),public.user_notification_preferences(),public.set_user_notification_preferences(boolean,boolean,boolean) to authenticated;
commit;
