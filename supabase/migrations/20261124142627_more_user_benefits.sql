begin;
insert into growth_internal.user_feature_settings(key) values
 ('daily_bonus'),('achievement_badges'),('campaign_drafts'),('coin_goal'),
 ('wallet_statement'),('saved_task_alerts'),('support_reference'),('login_alerts');

create table growth_internal.benefit_reward_settings (
 singleton boolean primary key default true check(singleton),
 daily_amount integer not null default 1 check(daily_amount between 0 and 10000),
 daily_limit integer not null default 1000 check(daily_limit between 0 and 1000000),
 badge_5 integer not null default 0 check(badge_5 between 0 and 10000),
 badge_10 integer not null default 0 check(badge_10 between 0 and 10000),
 badge_25 integer not null default 0 check(badge_25 between 0 and 10000)
);
insert into growth_internal.benefit_reward_settings(singleton) values(true);
alter table growth_internal.benefit_reward_settings enable row level security;
revoke all on growth_internal.benefit_reward_settings from public,anon,authenticated;
create function public.admin_benefit_rewards() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return (select to_jsonb(s)-'singleton' from growth_internal.benefit_reward_settings s where singleton); end $$;
create function public.admin_set_benefit_rewards(p_daily_amount integer,p_daily_limit integer,p_badge_5 integer,p_badge_10 integer,p_badge_25 integer) returns void language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 if p_daily_amount is null or p_daily_amount not between 0 and 10000 or p_daily_limit is null or p_daily_limit not between 0 and 1000000 or p_badge_5 is null or p_badge_5 not between 0 and 10000 or p_badge_10 is null or p_badge_10 not between 0 and 10000 or p_badge_25 is null or p_badge_25 not between 0 and 10000 then raise exception 'Invalid reward settings.'; end if;
 update growth_internal.benefit_reward_settings set daily_amount=p_daily_amount,daily_limit=p_daily_limit,badge_5=p_badge_5,badge_10=p_badge_10,badge_25=p_badge_25 where singleton;
 insert into growth_internal.admin_operations_audit(actor_id,action,details) values(auth.uid(),'Benefit reward settings',jsonb_build_object('daily_amount',p_daily_amount,'daily_limit',p_daily_limit,'badge_5',p_badge_5,'badge_10',p_badge_10,'badge_25',p_badge_25)::text);
end $$;

create table growth_internal.daily_bonus_grants(user_id uuid not null references auth.users(id) on delete cascade,day date not null,amount integer not null check(amount>0),primary key(user_id,day));
create table growth_internal.daily_bonus_totals(day date primary key,total bigint not null check(total>=0));
alter table growth_internal.daily_bonus_totals enable row level security;
revoke all on growth_internal.daily_bonus_totals from public,anon,authenticated;
create table growth_internal.badge_bonus_grants(user_id uuid not null references auth.users(id) on delete cascade,milestone integer not null check(milestone in (5,10,25)),amount integer not null check(amount>0),created_at timestamptz not null default now(),primary key(user_id,milestone));
alter table growth_internal.daily_bonus_grants enable row level security;
alter table growth_internal.badge_bonus_grants enable row level security;
revoke all on growth_internal.daily_bonus_grants,growth_internal.badge_bonus_grants from public,anon,authenticated;
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment','purchase','transfer_sent','transfer_received','daily_bonus','badge_bonus'));
create function public.user_reward_status() returns jsonb language plpgsql security definer set search_path='' as $$
declare d date:=(now() at time zone 'UTC')::date; approved bigint; cfg growth_internal.benefit_reward_settings%rowtype;
begin
 perform growth_internal.require_active();
 select * into strict cfg from growth_internal.benefit_reward_settings where singleton;
 select count(*) into approved from public.submission_history where user_id=auth.uid() and status='approved';
 return jsonb_build_object('day',d,'daily_amount',cfg.daily_amount,'daily_claimed',exists(select 1 from growth_internal.daily_bonus_grants where user_id=auth.uid() and day=d),
 'approved',approved,'badge_5',cfg.badge_5,'badge_10',cfg.badge_10,'badge_25',cfg.badge_25,
 'claimed_badges',coalesce((select jsonb_agg(milestone) from growth_internal.badge_bonus_grants where user_id=auth.uid()),'[]'::jsonb));
end $$;
create function public.claim_daily_bonus() returns integer language plpgsql security definer set search_path='' as $$
declare d date:=(now() at time zone 'UTC')::date; cfg growth_internal.benefit_reward_settings%rowtype; used bigint;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='daily_bonus') then raise exception 'Feature unavailable.'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('daily_bonus:'||d::text,9144));
 select * into strict cfg from growth_internal.benefit_reward_settings where singleton for share;
 if cfg.daily_amount=0 then raise exception 'Daily bonus unavailable.'; end if;
 if exists(select 1 from growth_internal.daily_bonus_grants where user_id=auth.uid() and day=d) then raise exception 'Daily bonus already claimed.'; end if;
 select coalesce((select total from growth_internal.daily_bonus_totals where day=d),0) into used;
 if used+cfg.daily_amount>cfg.daily_limit then raise exception 'Daily bonus limit reached.'; end if;
 update public.wallets set balance=balance+cfg.daily_amount where id=auth.uid();
 if not found then raise exception 'Wallet unavailable.'; end if;
 insert into growth_internal.daily_bonus_grants values(auth.uid(),d,cfg.daily_amount);
 insert into growth_internal.daily_bonus_totals(day,total) values(d,cfg.daily_amount) on conflict(day) do update set total=growth_internal.daily_bonus_totals.total+excluded.total;
 insert into public.coin_ledger(user_id,amount,reason) values(auth.uid(),cfg.daily_amount,'daily_bonus');
 return cfg.daily_amount;
end $$;
create function public.claim_badge_bonus(p_milestone integer) returns integer language plpgsql security definer set search_path='' as $$
declare reward integer; approved bigint;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='achievement_badges') or p_milestone is null or p_milestone not in (5,10,25) then raise exception 'Feature unavailable.'; end if;
 select count(*) into approved from public.submission_history where user_id=auth.uid() and status='approved';
 if approved<p_milestone then raise exception 'Milestone not reached.'; end if;
 select case p_milestone when 5 then badge_5 when 10 then badge_10 else badge_25 end into reward from growth_internal.benefit_reward_settings where singleton for share;
 if reward<=0 then raise exception 'Bonus unavailable.'; end if;
 if exists(select 1 from growth_internal.badge_bonus_grants where user_id=auth.uid() and milestone=p_milestone) then raise exception 'Bonus already claimed.'; end if;
 update public.wallets set balance=balance+reward where id=auth.uid(); if not found then raise exception 'Wallet unavailable.'; end if;
 insert into growth_internal.badge_bonus_grants(user_id,milestone,amount) values(auth.uid(),p_milestone,reward);
 insert into public.coin_ledger(user_id,amount,reason) values(auth.uid(),reward,'badge_bonus');
 return reward;
end $$;

create table growth_internal.campaign_drafts(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,kind text not null check(kind in ('follow','like','comment','share')),link text not null default '' check(length(link)<=500),username text not null default '' check(length(username)<=30),task_count integer not null check(task_count between 1 and 100),updated_at timestamptz not null default now());
create index campaign_drafts_user_idx on growth_internal.campaign_drafts(user_id,updated_at desc);
alter table growth_internal.campaign_drafts enable row level security;
revoke all on growth_internal.campaign_drafts from public,anon,authenticated;
create function public.user_campaign_drafts() returns table(id uuid,kind text,link text,username text,task_count integer,updated_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='campaign_drafts') then raise exception 'Feature unavailable.'; end if;
 return query select d.id,d.kind,d.link,d.username,d.task_count,d.updated_at from growth_internal.campaign_drafts d where d.user_id=auth.uid() order by d.updated_at desc,d.id limit 10; end $$;
create function public.save_campaign_draft(p_id uuid,p_kind text,p_link text,p_username text,p_count integer) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='campaign_drafts') or p_kind is null or p_kind not in ('follow','like','comment','share') or p_link is null or length(p_link)>500 or p_username is null or length(p_username)>30 or p_count is null or p_count not between 1 and 100 then raise exception 'Invalid draft.'; end if;
 if p_id is null then
  if (select count(*) from growth_internal.campaign_drafts where user_id=auth.uid())>=10 then raise exception 'Draft limit reached.'; end if;
  insert into growth_internal.campaign_drafts(user_id,kind,link,username,task_count) values(auth.uid(),p_kind,p_link,p_username,p_count) returning id into result;
 else
  update growth_internal.campaign_drafts set kind=p_kind,link=p_link,username=p_username,task_count=p_count,updated_at=now() where id=p_id and user_id=auth.uid() returning id into result;
  if result is null then raise exception 'Draft unavailable.'; end if;
 end if;
 return result;
end $$;
create function public.delete_campaign_draft(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='campaign_drafts') then raise exception 'Feature unavailable.'; end if; delete from growth_internal.campaign_drafts where id=p_id and user_id=auth.uid(); end $$;

create table growth_internal.user_coin_goals(user_id uuid primary key references auth.users(id) on delete cascade,target integer not null check(target between 1 and 100000000),updated_at timestamptz not null default now());
alter table growth_internal.user_coin_goals enable row level security;
revoke all on growth_internal.user_coin_goals from public,anon,authenticated;
create function public.user_coin_goal() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='coin_goal') then raise exception 'Feature unavailable.'; end if;
 return (select jsonb_build_object('target',g.target,'balance',w.balance-w.held_balance) from growth_internal.user_coin_goals g join public.wallets w on w.id=g.user_id where g.user_id=auth.uid()); end $$;
create function public.set_user_coin_goal(p_target integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='coin_goal') or (p_target is not null and p_target not between 1 and 100000000) then raise exception 'Invalid goal.'; end if;
 if p_target is null then delete from growth_internal.user_coin_goals where user_id=auth.uid(); else insert into growth_internal.user_coin_goals(user_id,target) values(auth.uid(),p_target) on conflict(user_id) do update set target=excluded.target,updated_at=now(); end if; end $$;
create function public.wallet_statement(p_from timestamptz,p_to timestamptz,p_offset integer default 0) returns table(created_at timestamptz,amount integer,reason text,reference_id text) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='wallet_statement') or p_from is null or p_to is null or p_from>=p_to or p_to-p_from>interval '366 days' or p_offset is null or p_offset not between 0 and 100000 then raise exception 'Invalid statement range.'; end if;
 return query select l."createdAt",l.amount,l.reason,l.reference_id from public.coin_ledger l where l.user_id=auth.uid() and l."createdAt">=p_from and l."createdAt"<p_to order by l."createdAt",l.id limit 200 offset p_offset; end $$;
create function public.support_reference_ticket(p_kind text,p_id uuid,p_message text) returns uuid language plpgsql security definer set search_path='' as $$
declare body text:=btrim(coalesce(p_message,'')); ref text;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='support_reference') or p_id is null or length(body) not between 1 and 1500 then raise exception 'Invalid support request.'; end if;
 if p_kind='campaign' then select order_id into ref from public.campaigns where id=p_id and "ownerId"=auth.uid();
 elsif p_kind='transaction' then select reference_id into ref from public.coin_ledger where id=p_id and user_id=auth.uid();
 else raise exception 'Invalid reference.'; end if;
 if ref is null then raise exception 'Reference unavailable.'; end if;
 return public.support_create_ticket('Help with '||p_kind, 'Reference: '||ref||E'\n\n'||body);
end $$;

alter table public.notifications add column saved_task_link text check(saved_task_link is null or length(saved_task_link)<=2048);
alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check(kind in ('approved','rejected','coins_received','support_reply','app_update','admin_message','review_reminder','saved_task_unavailable','login_alert'));
create or replace function growth_internal.apply_notification_preferences() returns trigger language plpgsql security definer set search_path='' as $$
declare allowed boolean;
begin
 select case when new.kind in ('approved','rejected','review_reminder','saved_task_unavailable') then task_updates
 when new.kind='coins_received' and new.credit_source='referral' then referral_updates
 when new.kind='coins_received' then coin_updates else true end into allowed from growth_internal.user_notification_preferences where user_id=new.user_id;
 if allowed=false then new.show_in_app:=false; new.deliver_push:=false; end if; return new;
end $$;
create function growth_internal.notify_saved_task_closed() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='active' and new.status in ('completed','cancelled') and (select enabled from growth_internal.user_feature_settings where key='saved_task_alerts') then
  insert into public.notifications(user_id,kind,saved_task_link) select user_id,'saved_task_unavailable',new.link from public.saved_tasks where campaign_id=new.id;
 end if;
 return new;
end $$;
create trigger saved_task_closed after update of status on public.campaigns for each row execute function growth_internal.notify_saved_task_closed();
create function growth_internal.notify_new_login() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.last_sign_in_at is distinct from old.last_sign_in_at and new.last_sign_in_at is not null and (select enabled from growth_internal.user_feature_settings where key='login_alerts') then
  insert into public.notifications(user_id,kind) values(new.id,'login_alert');
 end if;
 return new;
exception when others then
 -- Notification failures must never block authentication.
 raise warning 'Login alert could not be recorded'; return new;
end $$;
create trigger user_login_alert after update of last_sign_in_at on auth.users for each row execute function growth_internal.notify_new_login();
revoke all on function growth_internal.notify_saved_task_closed(),growth_internal.notify_new_login() from public,anon,authenticated;
revoke all on function public.admin_benefit_rewards(),public.admin_set_benefit_rewards(integer,integer,integer,integer,integer),public.user_reward_status(),public.claim_daily_bonus(),public.claim_badge_bonus(integer),public.user_campaign_drafts(),public.save_campaign_draft(uuid,text,text,text,integer),public.delete_campaign_draft(uuid),public.user_coin_goal(),public.set_user_coin_goal(integer),public.wallet_statement(timestamptz,timestamptz,integer),public.support_reference_ticket(text,uuid,text) from public,anon;
grant execute on function public.admin_benefit_rewards(),public.admin_set_benefit_rewards(integer,integer,integer,integer,integer),public.user_reward_status(),public.claim_daily_bonus(),public.claim_badge_bonus(integer),public.user_campaign_drafts(),public.save_campaign_draft(uuid,text,text,text,integer),public.delete_campaign_draft(uuid),public.user_coin_goal(),public.set_user_coin_goal(integer),public.wallet_statement(timestamptz,timestamptz,integer),public.support_reference_ticket(text,uuid,text) to authenticated;

-- Extend the existing account archive without weakening its allowlist.
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
 'growth_internal.daily_bonus_grants','growth_internal.badge_bonus_grants','growth_internal.campaign_drafts','growth_internal.user_coin_goals'];
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
