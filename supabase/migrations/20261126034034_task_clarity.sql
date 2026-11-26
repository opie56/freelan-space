begin;
insert into growth_internal.user_feature_settings(key) values ('task_instructions'),('screenshot_editing'),('submission_waiting'),('report_tracking'),('notification_filters'),('saved_task_notes'),('preferred_task_alerts'),('spending_insights');

-- Owner instructions are optional; existing campaign creation stays intact.
alter table public.campaigns add column task_instructions text check(task_instructions is null or length(task_instructions)<=1000);
create function public.set_campaign_instructions(p_campaign uuid,p_text text) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='task_instructions') then raise exception 'Feature unavailable.'; end if;
 if p_text is null or length(p_text)>1000 then raise exception 'Invalid instructions.'; end if;
 update public.campaigns set task_instructions=nullif(btrim(p_text),'') where id=p_campaign and "ownerId"=auth.uid() and status='active'; if not found then raise exception 'Campaign unavailable.'; end if;
end $$;
create function public.create_campaign_with_instructions(p_type text,p_username text,p_link text,p_count integer,p_reward integer,p_instructions text) returns uuid language plpgsql security definer set search_path='' as $$
declare id uuid;
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='task_instructions') or p_instructions is null or length(p_instructions)>1000 then raise exception 'Invalid instructions.'; end if;
 id:=public.create_campaign_for_account(p_type,p_username,p_link,p_count,p_reward); perform public.set_campaign_instructions(id,p_instructions); return id;
end $$;

-- Reports reveal only the current caller's own report, without admin details.
create function public.user_campaign_reports() returns table(id uuid,campaign_id uuid,campaign_link text,status text,created_at timestamptz,resolved_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='report_tracking') then raise exception 'Feature unavailable.'; end if;
 return query select r.id,r.campaign_id,c.link,case when r.status='open' then 'open' else 'resolved' end,r.created_at,r.resolved_at from growth_internal.campaign_reports r join public.campaigns c on c.id=r.campaign_id where r.reporter_id=auth.uid() order by r.created_at desc,r.id limit 100; end $$;

-- Private notes are removed with saved tasks and are excluded from deletion archives.
create table growth_internal.saved_task_notes(user_id uuid not null,campaign_id uuid not null,note text not null check(length(note) between 1 and 1000),updated_at timestamptz not null default now(),primary key(user_id,campaign_id),foreign key(user_id,campaign_id) references public.saved_tasks(user_id,campaign_id) on delete cascade);
alter table growth_internal.saved_task_notes enable row level security;
revoke all on growth_internal.saved_task_notes from public,anon,authenticated;
create function public.user_saved_task_note(p_campaign uuid) returns text language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='saved_task_notes') then raise exception 'Feature unavailable.'; end if; return (select note from growth_internal.saved_task_notes where user_id=auth.uid() and campaign_id=p_campaign); end $$;
create function public.set_saved_task_note(p_campaign uuid,p_note text) returns void language plpgsql security definer set search_path='' as $$
declare value text:=btrim(coalesce(p_note,''));
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='saved_task_notes') then raise exception 'Feature unavailable.'; end if;
 if p_campaign is null or length(value)>1000 or not exists(select 1 from public.saved_tasks where user_id=auth.uid() and campaign_id=p_campaign) then raise exception 'Saved task unavailable.'; end if;
 if value='' then delete from growth_internal.saved_task_notes where user_id=auth.uid() and campaign_id=p_campaign; else insert into growth_internal.saved_task_notes values(auth.uid(),p_campaign,value,now()) on conflict(user_id,campaign_id) do update set note=excluded.note,updated_at=now(); end if;
end $$;

-- Preferred categories are opt-in. Alert only campaigns created after opt-in,
-- and only after the existing one-minute publication delay.
create table growth_internal.preferred_task_categories(user_id uuid not null references auth.users(id) on delete cascade,category text not null check(category in ('follow','like','comment','share')),enabled_at timestamptz not null default now(),primary key(user_id,category));
create index preferred_task_categories_match on growth_internal.preferred_task_categories(category,enabled_at,user_id);
create index campaigns_preferred_task_match on public.campaigns(type,"createdAt",id) where status='active' and not paused;
create table growth_internal.preferred_task_alert_log(user_id uuid not null references auth.users(id) on delete cascade,campaign_id uuid not null references public.campaigns(id) on delete cascade,created_at timestamptz not null default now(),primary key(user_id,campaign_id));
alter table growth_internal.preferred_task_categories enable row level security;
alter table growth_internal.preferred_task_alert_log enable row level security;
revoke all on growth_internal.preferred_task_categories,growth_internal.preferred_task_alert_log from public,anon,authenticated;
create function public.user_preferred_tasks() returns text[] language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='preferred_task_alerts') then raise exception 'Feature unavailable.'; end if;
 return coalesce((select array_agg(category order by category) from growth_internal.preferred_task_categories where user_id=auth.uid()),'{}'::text[]); end $$;
create function public.set_preferred_tasks(p_categories text[]) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='preferred_task_alerts') or p_categories is null or cardinality(p_categories)>4 or exists(select 1 from unnest(p_categories) x where x is null or x not in ('follow','like','comment','share')) then raise exception 'Invalid categories.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('preferred_tasks:'||auth.uid()::text,6101));
 delete from growth_internal.preferred_task_categories where user_id=auth.uid() and not(category=any(p_categories));
 insert into growth_internal.preferred_task_categories(user_id,category) select auth.uid(),x from (select distinct unnest(p_categories) x) u on conflict(user_id,category) do nothing;
end $$;
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update','admin_message','review_reminder','saved_task_unavailable','login_alert','saved_task_reminder','campaign_progress_50','campaign_progress_100','low_balance','preferred_task'));
create or replace function growth_internal.apply_notification_preferences() returns trigger language plpgsql security definer set search_path='' as $$
declare allowed boolean;
begin select case when new.kind in ('approved','rejected','review_reminder','saved_task_unavailable','saved_task_reminder','campaign_progress_50','campaign_progress_100','preferred_task') then task_updates when new.kind='coins_received' and new.credit_source='referral' then referral_updates when new.kind in ('coins_received','low_balance') then coin_updates else true end into allowed from growth_internal.user_notification_preferences where user_id=new.user_id;
 if allowed=false then new.show_in_app:=false; new.deliver_push:=false; end if; return new; end $$;
create function public.dispatch_preferred_task_alerts(p_limit integer default 500) returns integer language plpgsql security definer set search_path='' as $$
declare r record; inserted integer; sent integer:=0;
begin if p_limit is null or p_limit not between 1 and 500 then raise exception 'Invalid limit.'; end if; if not (select enabled from growth_internal.user_feature_settings where key='preferred_task_alerts') then return 0; end if;
 if not pg_catalog.pg_try_advisory_xact_lock(61900013) then return 0; end if;
 for r in select p.user_id,p.category,c.id,c.link,c."createdAt" as created_at from growth_internal.preferred_task_categories p join public.campaigns c on c.type=p.category where c."createdAt">=p.enabled_at and c."createdAt"<=clock_timestamp()-interval '1 minute' and c.status='active' and not c.paused and c."ownerId"<>p.user_id and not exists(select 1 from public.user_access a where a.user_id=p.user_id and a.blocked) and exists(select 1 from public.action_controls a where a.action_type=c.type and a.enabled) and not exists(select 1 from growth_internal.preferred_task_alert_log l where l.user_id=p.user_id and l.campaign_id=c.id) order by c."createdAt",c.id,p.user_id limit p_limit loop
  perform 1 from growth_internal.preferred_task_categories p where p.user_id=r.user_id and p.category=r.category and p.enabled_at<=r.created_at for share;
  if not found then continue; end if;
  insert into growth_internal.preferred_task_alert_log(user_id,campaign_id) values(r.user_id,r.id) on conflict do nothing; get diagnostics inserted=row_count;
  if inserted=1 then insert into public.notifications(user_id,kind,saved_task_link) values(r.user_id,'preferred_task',r.link); sent:=sent+1; end if;
 end loop; return sent; end $$;
revoke all on function public.dispatch_preferred_task_alerts(integer) from public,anon,authenticated;
grant execute on function public.dispatch_preferred_task_alerts(integer) to service_role;

-- Monthly gross debits are separate from refunds and are not cash payouts.
create function public.monthly_spending_insights() returns jsonb language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare start_at timestamptz:=date_trunc('month',now() at time zone 'UTC') at time zone 'UTC';
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='spending_insights') then raise exception 'Feature unavailable.'; end if;
 return (select jsonb_build_object('start_at',start_at,'campaign',coalesce(-sum(amount) filter(where reason='campaign' and amount<0),0),'transfer',coalesce(-sum(amount) filter(where reason='transfer_sent' and amount<0),0),'other',coalesce(-sum(amount) filter(where reason not in ('campaign','transfer_sent') and amount<0),0),'refund',coalesce(sum(amount) filter(where reason='refund' and amount>0),0)) from public.coin_ledger where user_id=auth.uid() and "createdAt">=start_at and "createdAt"<start_at+interval '1 month'); end $$;
revoke all on function public.set_campaign_instructions(uuid,text),public.create_campaign_with_instructions(text,text,text,integer,integer,text),public.user_campaign_reports(),public.user_saved_task_note(uuid),public.set_saved_task_note(uuid,text),public.user_preferred_tasks(),public.set_preferred_tasks(text[]),public.monthly_spending_insights() from public,anon;
grant execute on function public.set_campaign_instructions(uuid,text),public.create_campaign_with_instructions(text,text,text,integer,integer,text),public.user_campaign_reports(),public.user_saved_task_note(uuid),public.set_saved_task_note(uuid,text),public.user_preferred_tasks(),public.set_preferred_tasks(text[]),public.monthly_spending_insights() to authenticated;

create or replace function growth_internal.archive_deleted_account() returns trigger
language plpgsql security definer set search_path='' as $$
declare snapshot jsonb; section jsonb; relation text; campaign_ids text[]; ticket_ids text[]; transfer_ids text[];
 relations constant text[] := array[
 'public.wallets','public.instagram_accounts','public.campaigns','public.campaign_claims','public.claim_evidence',
 'public.submission_history','public.saved_tasks','public.coin_ledger','public.coin_purchase_orders','public.wallet_transfers',
 'public.notifications','public.user_access','public.account_block_status','public.admin_access_audit','public.app_installations','public.app_releases',
 'growth_internal.profile_photos','growth_internal.user_identifiers','growth_internal.referral_codes','growth_internal.legacy_referral_codes',
 'growth_internal.referrals','growth_internal.referral_milestones','growth_internal.support_tickets','growth_internal.support_messages',
 'growth_internal.campaign_reports','growth_internal.admin_notes','growth_internal.admin_events','growth_internal.admin_operations_audit',
 'growth_internal.admin_review_audit','growth_internal.coin_adjustments','growth_internal.wallet_operations','growth_internal.wallet_payment_results',
 'growth_internal.security_password_events',
 'growth_internal.daily_bonus_grants','growth_internal.badge_bonus_grants','growth_internal.campaign_drafts','growth_internal.user_coin_goals',
 'growth_internal.coupon_redemptions','growth_internal.quiet_hours',
 'growth_internal.weekly_challenge_grants','growth_internal.saved_task_reminders','growth_internal.extra_alert_preferences',
 'growth_internal.preferred_task_categories'];
begin
 -- Capture only business records from a reviewed allowlist. Never copy Auth
 -- secrets, PIN hashes, OTP proofs, push tokens or user-controlled Auth metadata.
 snapshot := jsonb_build_object('schema_version',1,'account',jsonb_build_object(
   'id',old.id,'email',old.email,'phone',old.phone,'created_at',old.created_at,
   'email_confirmed_at',old.email_confirmed_at,'last_sign_in_at',old.last_sign_in_at,
   'display_name',old.raw_user_meta_data->>'full_name'));
 -- Freeze business writes until capture and cascading deletion commit together.
 foreach relation in array relations loop execute format('lock table %s in share row exclusive mode',relation); end loop;
 select coalesce(array_agg(id::text),'{}') into campaign_ids from public.campaigns where "ownerId"=old.id;
 select coalesce(array_agg(id::text),'{}') into ticket_ids from growth_internal.support_tickets where user_id=old.id;
 select coalesce(array_agg(id::text),'{}') into transfer_ids from public.wallet_transfers where sender_id=old.id or recipient_id=old.id;
 foreach relation in array relations loop
   execute format($q$select coalesce(jsonb_agg(j),'[]') from (select to_jsonb(t) j from %s t) rows
    where exists(select 1 from jsonb_each_text(j) e where e.key = any(array[
      'user_id','ownerId','sender_id','recipient_id','referrer_id','referred_id','actor_id','target_id','subject_id','author_id','reporter_id','admin_id','target_user_id']) and e.value=$1)
     or ($5='public.wallets' and j->>'id'=$1)
     or j->>'campaign_id'=any($2) or j->>'subject_id'=any($2)
     or j->>'ticket_id'=any($3) or j->>'transfer_id'=any($4)$q$,relation)
     into section using old.id::text,campaign_ids,ticket_ids,transfer_ids,relation;
   snapshot := snapshot || jsonb_build_object(relation,section);
 end loop;
 insert into growth_internal.deleted_account_archives(user_id,email,display_name,snapshot)
 values(old.id,old.email,old.raw_user_meta_data->>'full_name',snapshot);
 return old;
end $$;

commit;
