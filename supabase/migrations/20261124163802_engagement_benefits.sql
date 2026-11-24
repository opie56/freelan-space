begin;
insert into growth_internal.user_feature_settings(key) values
 ('weekly_challenges'),('resubmit_help'),('saved_task_reminders'),('monthly_coin_insights'),
 ('campaign_copy'),('campaign_progress_alerts'),('low_balance_alerts'),('editable_help');

-- Weekly UTC challenge. A global issuance total survives account deletion.
create table growth_internal.weekly_challenge_settings(singleton boolean primary key default true check(singleton), target integer not null default 5 check(target between 1 and 1000), reward integer not null default 0 check(reward between 0 and 10000), weekly_limit integer not null default 1000 check(weekly_limit between 0 and 1000000));
insert into growth_internal.weekly_challenge_settings(singleton) values(true);
create table growth_internal.weekly_challenge_grants(user_id uuid not null references auth.users(id) on delete cascade, week date not null, amount integer not null check(amount>0), primary key(user_id,week));
create table growth_internal.weekly_challenge_totals(week date primary key,total bigint not null check(total>=0));
alter table growth_internal.weekly_challenge_settings enable row level security;
alter table growth_internal.weekly_challenge_grants enable row level security;
alter table growth_internal.weekly_challenge_totals enable row level security;
revoke all on growth_internal.weekly_challenge_settings,growth_internal.weekly_challenge_grants,growth_internal.weekly_challenge_totals from public,anon,authenticated;
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment','purchase','transfer_sent','transfer_received','daily_bonus','badge_bonus','coupon_bonus','weekly_challenge'));
create function public.admin_weekly_challenge() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return (select to_jsonb(s)-'singleton' from growth_internal.weekly_challenge_settings s); end $$;
create function public.admin_set_weekly_challenge(p_target integer,p_reward integer,p_limit integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor();
 if p_target is null or p_target not between 1 and 1000 or p_reward is null or p_reward not between 0 and 10000 or p_limit is null or p_limit not between 0 and 1000000 then raise exception 'Invalid challenge settings.'; end if;
 update growth_internal.weekly_challenge_settings set target=p_target,reward=p_reward,weekly_limit=p_limit where singleton;
 insert into growth_internal.admin_operations_audit(actor_id,action,details) values(auth.uid(),'Weekly challenge settings',jsonb_build_object('target',p_target,'reward',p_reward,'weekly_limit',p_limit)::text);
end $$;
create function public.weekly_challenge_status() returns jsonb language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare start_at timestamptz:=date_trunc('week',now() at time zone 'UTC') at time zone 'UTC'; w date:=(date_trunc('week',now() at time zone 'UTC'))::date;
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='weekly_challenges') then raise exception 'Feature unavailable.'; end if;
 return (select jsonb_build_object('week',w,'target',s.target,'reward',s.reward,'completed',(select count(*) from public.submission_history h where h.user_id=auth.uid() and h.status='approved' and h.reviewed_at>=start_at and h.reviewed_at<start_at+interval '7 days'),'claimed',exists(select 1 from growth_internal.weekly_challenge_grants g where g.week=w and g.user_id=auth.uid())) from growth_internal.weekly_challenge_settings s where s.singleton);
end $$;
create function public.claim_weekly_challenge() returns integer language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare start_at timestamptz:=date_trunc('week',now() at time zone 'UTC') at time zone 'UTC'; w date:=(date_trunc('week',now() at time zone 'UTC'))::date; cfg growth_internal.weekly_challenge_settings%rowtype; used bigint;
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='weekly_challenges') then raise exception 'Feature unavailable.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('weekly_challenge:'||w::text,4731));
 select * into strict cfg from growth_internal.weekly_challenge_settings where singleton for share;
 if cfg.reward=0 or (select count(*) from public.submission_history h where h.user_id=auth.uid() and h.status='approved' and h.reviewed_at>=start_at and h.reviewed_at<start_at+interval '7 days')<cfg.target then raise exception 'Challenge unavailable.'; end if;
 if exists(select 1 from growth_internal.weekly_challenge_grants where user_id=auth.uid() and week=w) then raise exception 'Already claimed.'; end if;
 select coalesce((select total from growth_internal.weekly_challenge_totals where week=w),0) into used;
 if used+cfg.reward>cfg.weekly_limit then raise exception 'Weekly limit reached.'; end if;
 update public.wallets set balance=balance+cfg.reward where id=auth.uid(); if not found then raise exception 'Wallet unavailable.'; end if;
 insert into growth_internal.weekly_challenge_grants values(auth.uid(),w,cfg.reward);
 insert into growth_internal.weekly_challenge_totals values(w,cfg.reward) on conflict(week) do update set total=weekly_challenge_totals.total+excluded.total;
 insert into public.coin_ledger(user_id,amount,reason) values(auth.uid(),cfg.reward,'weekly_challenge'); return cfg.reward;
end $$;
create function public.monthly_coin_insights() returns jsonb language plpgsql security definer set search_path='' set timezone='UTC' as $$
declare start_at timestamptz:=date_trunc('month',now() at time zone 'UTC') at time zone 'UTC';
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='monthly_coin_insights') then raise exception 'Feature unavailable.'; end if;
 return (select jsonb_build_object('start_at',start_at,'task',coalesce(sum(amount) filter(where reason='task' and amount>0),0),'referral',coalesce(sum(amount) filter(where reason='referral' and amount>0),0),'bonus',coalesce(sum(amount) filter(where reason in ('daily_bonus','badge_bonus','coupon_bonus','weekly_challenge') and amount>0),0)) from public.coin_ledger where user_id=auth.uid() and "createdAt">=start_at and "createdAt"<start_at+interval '1 month');
end $$;

-- Users may choose a reminder for a saved task. A trusted scheduler dispatches it.
create table growth_internal.saved_task_reminders(user_id uuid not null,campaign_id uuid not null,remind_at timestamptz not null,primary key(user_id,campaign_id),foreign key(user_id,campaign_id) references public.saved_tasks(user_id,campaign_id) on delete cascade);
create index saved_task_reminders_due on growth_internal.saved_task_reminders(remind_at);
alter table growth_internal.saved_task_reminders enable row level security;
revoke all on growth_internal.saved_task_reminders from public,anon,authenticated;
create function public.set_saved_task_reminder(p_campaign uuid,p_at timestamptz) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='saved_task_reminders') then raise exception 'Feature unavailable.'; end if;
 if p_campaign is null or not exists(select 1 from public.saved_tasks where user_id=auth.uid() and campaign_id=p_campaign) then raise exception 'Save the task first.'; end if;
 if p_at is null then delete from growth_internal.saved_task_reminders where user_id=auth.uid() and campaign_id=p_campaign; return; end if;
 if p_at<=now() or p_at>now()+interval '30 days' then raise exception 'Invalid reminder time.'; end if;
 insert into growth_internal.saved_task_reminders values(auth.uid(),p_campaign,p_at) on conflict(user_id,campaign_id) do update set remind_at=excluded.remind_at;
end $$;
create function public.user_saved_task_reminders() returns table(campaign_id uuid,remind_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='saved_task_reminders') then raise exception 'Feature unavailable.'; end if; return query select r.campaign_id,r.remind_at from growth_internal.saved_task_reminders r where r.user_id=auth.uid() order by r.remind_at; end $$;

create table growth_internal.extra_alert_preferences(user_id uuid primary key references auth.users(id) on delete cascade,progress boolean not null default true,low_balance integer check(low_balance between 0 and 100000000));
alter table growth_internal.extra_alert_preferences enable row level security;
revoke all on growth_internal.extra_alert_preferences from public,anon,authenticated;
create function public.user_extra_alerts() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); return coalesce((select to_jsonb(p)-'user_id' from growth_internal.extra_alert_preferences p where p.user_id=auth.uid()),jsonb_build_object('progress',true,'low_balance',null)); end $$;
create function public.set_user_extra_alerts(p_progress boolean,p_low integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if p_progress is null or (p_low is not null and p_low not between 0 and 100000000) then raise exception 'Invalid alert settings.'; end if;
 if not (select enabled from growth_internal.user_feature_settings where key='campaign_progress_alerts') and p_progress is distinct from coalesce((select progress from growth_internal.extra_alert_preferences where user_id=auth.uid()),true) then raise exception 'Feature unavailable.'; end if;
 if not (select enabled from growth_internal.user_feature_settings where key='low_balance_alerts') and p_low is distinct from (select low_balance from growth_internal.extra_alert_preferences where user_id=auth.uid()) then raise exception 'Feature unavailable.'; end if;
 insert into growth_internal.extra_alert_preferences values(auth.uid(),p_progress,p_low) on conflict(user_id) do update set progress=excluded.progress,low_balance=excluded.low_balance;
end $$;
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update','admin_message','review_reminder','saved_task_unavailable','login_alert','saved_task_reminder','campaign_progress_50','campaign_progress_100','low_balance'));
create or replace function growth_internal.apply_notification_preferences() returns trigger language plpgsql security definer set search_path='' as $$
declare allowed boolean;
begin select case when new.kind in ('approved','rejected','review_reminder','saved_task_unavailable','saved_task_reminder','campaign_progress_50','campaign_progress_100') then task_updates when new.kind='coins_received' and new.credit_source='referral' then referral_updates when new.kind in ('coins_received','low_balance') then coin_updates else true end into allowed from growth_internal.user_notification_preferences where user_id=new.user_id;
 if allowed=false then new.show_in_app:=false; new.deliver_push:=false; end if; return new; end $$;
create function growth_internal.campaign_progress_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare progress50 boolean; progress100 boolean;
begin
 if not (select enabled from growth_internal.user_feature_settings where key='campaign_progress_alerts') or not coalesce((select p.progress from growth_internal.extra_alert_preferences p where p.user_id=new."ownerId"),true) or new.requested<=0 or new.remaining>=old.remaining then return new; end if;
 progress50 := (old.requested-old.remaining)*2<old.requested and (new.requested-new.remaining)*2>=new.requested;
 progress100 := old.remaining>0 and new.remaining=0 and new.status='completed';
 if progress50 or progress100 then insert into public.notifications(user_id,kind) values(new."ownerId",case when progress100 then 'campaign_progress_100' else 'campaign_progress_50' end); end if;
 return new; end $$;
create trigger campaign_progress_notification after update of remaining on public.campaigns for each row execute function growth_internal.campaign_progress_notification();
create function growth_internal.low_balance_notification() returns trigger language plpgsql security definer set search_path='' as $$
declare threshold integer;
begin if not (select enabled from growth_internal.user_feature_settings where key='low_balance_alerts') then return new; end if; select low_balance into threshold from growth_internal.extra_alert_preferences where user_id=new.id;
 if threshold is not null and old.balance-old.held_balance>=threshold and new.balance-new.held_balance<threshold then insert into public.notifications(user_id,kind) values(new.id,'low_balance'); end if; return new; end $$;
create trigger low_balance_notification after update of balance,held_balance on public.wallets for each row execute function growth_internal.low_balance_notification();
create function public.dispatch_saved_task_reminders(p_limit integer default 100) returns integer language plpgsql security definer set search_path='' as $$
declare r record; sent integer:=0;
begin if p_limit is null or p_limit not between 1 and 500 then raise exception 'Invalid limit.'; end if;
 if not (select enabled from growth_internal.user_feature_settings where key='saved_task_reminders') then return 0; end if;
 for r in select a.user_id,a.campaign_id,c.link from growth_internal.saved_task_reminders a join public.campaigns c on c.id=a.campaign_id where a.remind_at<=now() order by a.remind_at for update of a skip locked limit p_limit loop
  insert into public.notifications(user_id,kind,saved_task_link) values(r.user_id,'saved_task_reminder',r.link);
  delete from growth_internal.saved_task_reminders where user_id=r.user_id and campaign_id=r.campaign_id; sent:=sent+1;
 end loop; return sent; end $$;
revoke all on function public.dispatch_saved_task_reminders(integer) from public,anon,authenticated;
grant execute on function public.dispatch_saved_task_reminders(integer) to service_role;
revoke all on function growth_internal.campaign_progress_notification(),growth_internal.low_balance_notification() from public,anon,authenticated;

-- Admin maintained help supplements the existing local help topics.
create table growth_internal.help_articles(id uuid primary key default gen_random_uuid(),title text not null check(length(btrim(title)) between 1 and 150),body text not null check(length(btrim(body)) between 1 and 3000),enabled boolean not null default true,updated_at timestamptz not null default now());
alter table growth_internal.help_articles enable row level security;
revoke all on growth_internal.help_articles from public,anon,authenticated;
create function public.user_help_articles() returns table(id uuid,title text,body text) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='editable_help') then return; end if; return query select h.id,h.title,h.body from growth_internal.help_articles h where h.enabled order by h.updated_at desc limit 100; end $$;
create function public.admin_help_articles() returns table(id uuid,title text,body text,enabled boolean) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select h.id,h.title,h.body,h.enabled from growth_internal.help_articles h order by h.updated_at desc limit 100; end $$;
create function public.admin_save_help(p_id uuid,p_title text,p_body text,p_enabled boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin perform growth_internal.require_admin_editor(); if p_title is null or length(btrim(p_title)) not between 1 and 150 or p_body is null or length(btrim(p_body)) not between 1 and 3000 or p_enabled is null then raise exception 'Invalid help article.'; end if;
 if p_id is null then insert into growth_internal.help_articles(title,body,enabled) values(btrim(p_title),btrim(p_body),p_enabled) returning id into result;
 else update growth_internal.help_articles set title=btrim(p_title),body=btrim(p_body),enabled=p_enabled,updated_at=now() where id=p_id returning id into result; end if;
 if result is null then raise exception 'Article unavailable.'; end if; insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Help article updated',result); return result; end $$;
revoke all on function public.admin_weekly_challenge(),public.admin_set_weekly_challenge(integer,integer,integer),public.weekly_challenge_status(),public.claim_weekly_challenge(),public.monthly_coin_insights(),public.set_saved_task_reminder(uuid,timestamptz),public.user_saved_task_reminders(),public.user_extra_alerts(),public.set_user_extra_alerts(boolean,integer),public.user_help_articles(),public.admin_help_articles(),public.admin_save_help(uuid,text,text,boolean) from public,anon;
grant execute on function public.admin_weekly_challenge(),public.admin_set_weekly_challenge(integer,integer,integer),public.weekly_challenge_status(),public.claim_weekly_challenge(),public.monthly_coin_insights(),public.set_saved_task_reminder(uuid,timestamptz),public.user_saved_task_reminders(),public.user_extra_alerts(),public.set_user_extra_alerts(boolean,integer),public.user_help_articles(),public.admin_help_articles(),public.admin_save_help(uuid,text,text,boolean) to authenticated;

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
 'growth_internal.weekly_challenge_grants','growth_internal.saved_task_reminders','growth_internal.extra_alert_preferences'];
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
