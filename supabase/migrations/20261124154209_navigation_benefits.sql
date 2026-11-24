begin;
insert into growth_internal.user_feature_settings(key) values
 ('referral_links'),('notification_shortcuts'),('campaign_pause'),('saved_filters'),
 ('bonus_coupons'),('quiet_hours'),('device_sessions'),('offline_view');

-- Pause affects only new submissions. Existing reviews and reserved coins retain
-- the existing active-campaign contract, including the one-minute cancel window.
alter table public.campaigns add column paused boolean not null default false;
create function public.set_campaign_paused(p_campaign uuid,p_paused boolean) returns void language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype;
begin
 perform growth_internal.require_active();
 if p_campaign is null or p_paused is null then raise exception 'Invalid campaign.'; end if;
 select * into c from public.campaigns where id=p_campaign for update;
 if not found or c."ownerId"<>auth.uid() or c.status<>'active' then raise exception 'Campaign unavailable.'; end if;
 if p_paused and not (select enabled from growth_internal.user_feature_settings where key='campaign_pause') then raise exception 'Feature unavailable.'; end if;
 update public.campaigns set paused=p_paused where id=c.id;
end $$;
create or replace function public.submit_claim(p_campaign_id uuid,p_instagram_handle text,p_mime text,p_evidence text) returns void language plpgsql security definer set search_path='' as $$
declare c public.campaigns%rowtype;
begin
 perform growth_internal.require_active();
 select * into c from public.campaigns where id=p_campaign_id for update;
 if not found then raise exception 'Campaign not found.' using errcode='P0001'; end if;
 if c."createdAt" + interval '1 minute' > clock_timestamp() then raise exception 'Campaign is not yet available.' using errcode='P0001'; end if;
 if c.paused then raise exception 'Campaign is paused.' using errcode='P0001'; end if;
 perform growth_internal.require_action_enabled(c.type);
 perform growth_internal.submit_claim(p_campaign_id,p_instagram_handle,p_mime,p_evidence);
end $$;

-- Coupon issuance is controlled by editors; each redemption is serialized and
-- credited atomically with a ledger entry. Only masked code hints are audited.
create table growth_internal.bonus_coupons(id uuid primary key default gen_random_uuid(), code text not null unique check(code ~ '^[A-Z0-9]{6,24}$'), amount integer not null check(amount between 1 and 10000), max_uses integer not null check(max_uses between 1 and 100000), use_count integer not null default 0 check(use_count between 0 and max_uses), expires_at timestamptz not null, enabled boolean not null default true, created_at timestamptz not null default now());
create table growth_internal.coupon_redemptions(coupon_id uuid not null references growth_internal.bonus_coupons(id),user_id uuid not null references auth.users(id) on delete cascade,amount integer not null,created_at timestamptz not null default now(),primary key(coupon_id,user_id));
create table growth_internal.coupon_attempts(user_id uuid primary key references auth.users(id) on delete cascade,window_start timestamptz not null,attempts integer not null check(attempts>=0));
alter table growth_internal.bonus_coupons enable row level security;
alter table growth_internal.coupon_redemptions enable row level security;
alter table growth_internal.coupon_attempts enable row level security;
revoke all on growth_internal.bonus_coupons,growth_internal.coupon_redemptions,growth_internal.coupon_attempts from public,anon,authenticated;
alter table public.coin_ledger drop constraint coin_ledger_reason_check;
alter table public.coin_ledger add constraint coin_ledger_reason_check check(reason in ('welcome','campaign','task','refund','referral','admin_adjustment','purchase','transfer_sent','transfer_received','daily_bonus','badge_bonus','coupon_bonus'));
create function public.admin_bonus_coupons() returns table(id uuid,code text,amount integer,max_uses integer,expires_at timestamptz,enabled boolean,used bigint) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin(); return query select c.id,c.code,c.amount,c.max_uses,c.expires_at,c.enabled,c.use_count::bigint from growth_internal.bonus_coupons c order by c.created_at desc limit 100; end $$;
create function public.admin_create_coupon(p_code text,p_amount integer,p_limit integer,p_expires timestamptz) returns uuid language plpgsql security definer set search_path='' as $$
declare id uuid; value text:=upper(btrim(coalesce(p_code,'')));
begin perform growth_internal.require_admin_editor();
 if value !~ '^[A-Z0-9]{6,24}$' or p_amount is null or p_amount not between 1 and 10000 or p_limit is null or p_limit not between 1 and 100000 or p_expires is null or p_expires<=now() or p_expires>now()+interval '2 years' then raise exception 'Invalid coupon.'; end if;
 insert into growth_internal.bonus_coupons(code,amount,max_uses,expires_at) values(value,p_amount,p_limit,p_expires) returning bonus_coupons.id into id;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Bonus coupon created',id); return id;
end $$;
create function public.admin_disable_coupon(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin_editor(); update growth_internal.bonus_coupons set enabled=false where id=p_id; if not found then raise exception 'Coupon unavailable.'; end if; insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Bonus coupon disabled',p_id); end $$;
create function public.redeem_bonus_coupon(p_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare value text:=upper(btrim(coalesce(p_code,''))); c growth_internal.bonus_coupons%rowtype; attempts integer; uses bigint;
begin
 perform growth_internal.require_active();
 if not (select enabled from growth_internal.user_feature_settings where key='bonus_coupons') then return jsonb_build_object('status','unavailable'); end if;
 insert into growth_internal.coupon_attempts(user_id,window_start,attempts) values(auth.uid(),clock_timestamp(),1) on conflict(user_id) do update set window_start=case when coupon_attempts.window_start<=clock_timestamp()-interval '1 hour' then clock_timestamp() else coupon_attempts.window_start end, attempts=case when coupon_attempts.window_start<=clock_timestamp()-interval '1 hour' then 1 else coupon_attempts.attempts+1 end returning coupon_attempts.attempts into attempts;
 if attempts>10 then return jsonb_build_object('status','limited'); end if;
 if value !~ '^[A-Z0-9]{6,24}$' then return jsonb_build_object('status','unavailable'); end if;
 select * into c from growth_internal.bonus_coupons where code=value for update;
 if not found or not c.enabled or c.expires_at<=clock_timestamp() then return jsonb_build_object('status','unavailable'); end if;
 if exists(select 1 from growth_internal.coupon_redemptions where coupon_id=c.id and user_id=auth.uid()) then return jsonb_build_object('status','already_used'); end if;
 uses:=c.use_count;
 if uses>=c.max_uses then return jsonb_build_object('status','unavailable'); end if;
 update public.wallets set balance=balance+c.amount where id=auth.uid(); if not found then raise exception 'Wallet unavailable.'; end if;
 update growth_internal.bonus_coupons set use_count=use_count+1 where id=c.id;
 insert into growth_internal.coupon_redemptions(coupon_id,user_id,amount) values(c.id,auth.uid(),c.amount);
 insert into public.coin_ledger(user_id,amount,reason) values(auth.uid(),c.amount,'coupon_bonus');
 return jsonb_build_object('status','ok','amount',c.amount);
end $$;

-- Pushes are held in the queue during a user's chosen fixed UTC offset hours;
-- in-app records stay available. Existing leases can still complete.
create table growth_internal.quiet_hours(user_id uuid primary key references auth.users(id) on delete cascade,start_minute integer not null check(start_minute between 0 and 1439),end_minute integer not null check(end_minute between 0 and 1439),offset_minute integer not null check(offset_minute between -720 and 840),check(start_minute<>end_minute));
alter table growth_internal.quiet_hours enable row level security;
revoke all on growth_internal.quiet_hours from public,anon,authenticated;
create function public.user_quiet_hours() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='quiet_hours') then raise exception 'Feature unavailable.'; end if; return (select to_jsonb(q)-'user_id' from growth_internal.quiet_hours q where user_id=auth.uid()); end $$;
create function public.set_user_quiet_hours(p_start integer,p_end integer,p_offset integer) returns void language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='quiet_hours') then raise exception 'Feature unavailable.'; end if;
 if p_start is null and p_end is null and p_offset is null then delete from growth_internal.quiet_hours where user_id=auth.uid(); return; end if;
 if p_start is null or p_end is null or p_offset is null or p_start not between 0 and 1439 or p_end not between 0 and 1439 or p_offset not between -720 and 840 or p_start=p_end then raise exception 'Invalid quiet hours.'; end if;
 insert into growth_internal.quiet_hours values(auth.uid(),p_start,p_end,p_offset) on conflict(user_id) do update set start_minute=excluded.start_minute,end_minute=excluded.end_minute,offset_minute=excluded.offset_minute;
end $$;
create function growth_internal.user_is_quiet(p_user uuid,p_at timestamptz) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select case when q.start_minute<q.end_minute then m.minute_of_day>=q.start_minute and m.minute_of_day<q.end_minute else m.minute_of_day>=q.start_minute or m.minute_of_day<q.end_minute end from growth_internal.quiet_hours q cross join lateral (select extract(hour from ((p_at at time zone 'UTC')+make_interval(mins=>q.offset_minute)))::int*60+extract(minute from ((p_at at time zone 'UTC')+make_interval(mins=>q.offset_minute)))::int as minute_of_day) m where q.user_id=p_user),false)
$$;
create or replace function public.claim_push_jobs(p_limit integer default 50) returns table(job_id uuid,lease_id uuid,token text,kind text) language plpgsql security definer set search_path='' as $$
begin
 if p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid limit.' using errcode='P0001'; end if;
 return query with selected as (select j.id from growth_internal.push_jobs j join growth_internal.push_tokens t on t.id=j.token_id where ((j.status='pending' and j.next_attempt<=now()) or (j.status='leased' and j.lease_until<now())) and (not (select enabled from growth_internal.user_feature_settings where key='quiet_hours') or not growth_internal.user_is_quiet(t.user_id,now())) order by j.next_attempt,j.id for update of j skip locked limit p_limit), claimed as (update growth_internal.push_jobs j set status='leased',attempts=j.attempts+1,lease_until=now()+interval '2 minutes',lease_id=gen_random_uuid() from selected s where j.id=s.id returning j.id,j.lease_id,j.notification_id,j.token_id) select c.id,c.lease_id,t.token,n.kind from claimed c join growth_internal.push_tokens t on t.id=c.token_id join public.notifications n on n.id=c.notification_id;
end $$;
revoke all on function growth_internal.user_is_quiet(uuid,timestamptz) from public,anon,authenticated;

-- Associate newly registered push tokens with the Auth session. Existing
-- registrations have no session identity and are removed on remote revocation;
-- other active devices restore registration on their next app resume.
alter table growth_internal.push_tokens add column session_id uuid references auth.sessions(id) on delete cascade;
create or replace function public.register_push_token(p_token text) returns void language plpgsql security definer set search_path='' as $$
declare sid uuid; raw_sid text := auth.jwt()->>'session_id';
begin
 perform growth_internal.require_active();
 if p_token is null or length(p_token) not between 20 and 4096 then raise exception 'Invalid push token.' using errcode='P0001'; end if;
 if raw_sid is not null then
  begin sid:=raw_sid::uuid; exception when others then raise exception 'Session unavailable.'; end;
  if not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=auth.uid()) then raise exception 'Session unavailable.'; end if;
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_token,86420));
 delete from growth_internal.push_tokens where token=p_token and user_id<>auth.uid();
 insert into growth_internal.push_tokens(user_id,token,session_id) values(auth.uid(),p_token,sid)
 on conflict(token) do update set updated_at=now(),session_id=excluded.session_id;
end $$;

-- The provider stores sessions and cascades their refresh tokens on deletion.
-- Access JWTs already issued remain valid until expiry, as in existing logout.
create function public.user_device_sessions() returns table(id uuid,created_at timestamptz,refreshed_at timestamp,user_agent text,is_current boolean) language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='device_sessions') then raise exception 'Feature unavailable.'; end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid; exception when others then raise exception 'Session unavailable.'; end;
 if sid is null or not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=auth.uid()) then raise exception 'Session unavailable.'; end if;
 return query select s.id,s.created_at,s.refreshed_at,left(coalesce(s.user_agent,''),120),s.id=sid from auth.sessions s where s.user_id=auth.uid() order by s.created_at desc limit 100;
end $$;
create function public.revoke_device_session(p_id uuid,p_pin text) returns text language plpgsql security definer set search_path='' as $$
declare sid uuid; state text;
begin perform growth_internal.require_active(); if not (select enabled from growth_internal.user_feature_settings where key='device_sessions') then raise exception 'Feature unavailable.'; end if;
 begin sid:=(auth.jwt()->>'session_id')::uuid; exception when others then raise exception 'Session unavailable.'; end;
 if sid is null or p_id is null or p_id=sid or not exists(select 1 from auth.sessions s where s.id=sid and s.user_id=auth.uid()) then raise exception 'Session unavailable.'; end if;
 state:=growth_internal.check_release_pin(p_pin); if state<>'ok' then return state; end if;
 if not exists(select 1 from auth.sessions s where s.id=p_id and s.user_id=auth.uid()) then return 'unavailable'; end if;
 delete from growth_internal.push_tokens where user_id=auth.uid() and session_id is null;
 delete from auth.sessions where id=p_id and user_id=auth.uid(); if not found then return 'unavailable'; end if; return 'ok';
end $$;
revoke all on function public.set_campaign_paused(uuid,boolean),public.admin_bonus_coupons(),public.admin_create_coupon(text,integer,integer,timestamptz),public.admin_disable_coupon(uuid),public.redeem_bonus_coupon(text),public.user_quiet_hours(),public.set_user_quiet_hours(integer,integer,integer),public.user_device_sessions(),public.revoke_device_session(uuid,text) from public,anon;
grant execute on function public.set_campaign_paused(uuid,boolean),public.admin_bonus_coupons(),public.admin_create_coupon(text,integer,integer,timestamptz),public.admin_disable_coupon(uuid),public.redeem_bonus_coupon(text),public.user_quiet_hours(),public.set_user_quiet_hours(integer,integer,integer),public.user_device_sessions(),public.revoke_device_session(uuid,text) to authenticated;

-- Retain new user business records in the existing deletion archive.
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
 'growth_internal.coupon_redemptions','growth_internal.quiet_hours'];
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
