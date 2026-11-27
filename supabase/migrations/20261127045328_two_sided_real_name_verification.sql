begin;

alter table growth_internal.real_name_verifications
  add column document_type text check (document_type in ('aadhaar','voter_id','driving_licence','passport','pan')),
  add column back_mime text,
  add column back_data text,
  add column auto_verify_at timestamptz,
  add column rejection_reason text check (length(rejection_reason) between 1 and 500),
  add constraint real_name_back_proof check (
    (back_data is null and back_mime is null and (status <> 'pending' or document_type is null))
    or (status = 'pending' and document_type is not null and back_data is not null and back_mime is not null)
  ),
  add constraint real_name_auto_pending check (auto_verify_at is null or (status = 'pending' and document_type is not null));
create index real_name_auto_due on growth_internal.real_name_verifications(auto_verify_at) where auto_verify_at is not null;

-- Match the lock order used by submissions and decisions: Auth row, then request row.
create function growth_internal.lock_verified_profile_name() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.raw_user_meta_data->'full_name' is distinct from new.raw_user_meta_data->'full_name'
    and exists (select 1 from growth_internal.real_name_verifications r
      where r.user_id = old.id and r.submitted_name = btrim(old.raw_user_meta_data->>'full_name')
        and (r.status = 'approved' or r.auto_verify_at is not null))
  then
    raise exception 'Your verified profile name is locked.' using errcode='P0001';
  end if;
  return new;
end $$;
create trigger zz_lock_verified_profile_name before update of raw_user_meta_data
on auth.users for each row execute function growth_internal.lock_verified_profile_name();

create table growth_internal.real_name_scan_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_start timestamptz not null,
  attempts integer not null
);
alter table growth_internal.real_name_scan_limits enable row level security;
revoke all on growth_internal.real_name_scan_limits from public, anon, authenticated;

create function growth_internal.require_real_name_user(p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if p_user is null then raise exception 'Please sign in.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 314159));
  if not exists(select 1 from auth.users where id=p_user)
      or exists(select 1 from public.user_access where user_id=p_user and blocked)
  then raise exception 'Account access is blocked.'; end if;
end $$;

create function public.allow_real_name_scan(p_user uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare permitted boolean;
begin
  perform growth_internal.require_real_name_user(p_user);
  if exists (select 1 from growth_internal.real_name_verifications r join auth.users u on u.id=r.user_id
      where r.user_id=p_user and (r.status='pending' or
        (r.status='approved' and r.submitted_name=btrim(u.raw_user_meta_data->>'full_name')))) then
    return false;
  end if;
  insert into growth_internal.real_name_scan_limits as s values(p_user,now(),1)
    on conflict(user_id) do update set
      attempts = case when s.window_start <= now()-interval '1 minute' then 1 else s.attempts+1 end,
      window_start = case when s.window_start <= now()-interval '1 minute' then now() else s.window_start end
      where s.attempts < 8 or s.window_start <= now()-interval '1 minute'
    returning true into permitted;
  return coalesce(permitted,false);
end $$;

-- The trusted OCR Edge Function is the only API caller permitted to schedule approval.
create function public.submit_scanned_real_name(
 p_user uuid, p_name text, p_type text, p_front_mime text, p_front text,
 p_back_mime text, p_back text, p_match boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare current_name text; r growth_internal.real_name_verifications%rowtype; deadline timestamptz;
begin
  perform growth_internal.require_real_name_user(p_user);
  select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=p_user for update;
  if current_name is null or length(current_name) not between 1 and 80 or current_name is distinct from p_name
    then raise exception 'Profile name changed. Reload and try again.'; end if;
  if p_type is null or p_type not in ('aadhaar','voter_id','driving_licence','passport','pan')
      or not growth_internal.evidence_image_safe(p_front_mime,p_front)
      or not growth_internal.evidence_image_safe(p_back_mime,p_back)
      or decode(p_front,'base64') = decode(p_back,'base64')
    then raise exception 'Provide two different valid ID photos.'; end if;
  select * into r from growth_internal.real_name_verifications where user_id=p_user for update;
  if r.status='pending' or (r.status='approved' and r.submitted_name=current_name) then
    raise exception 'Name is already verified or being checked.';
  end if;
  if p_match is true then deadline := clock_timestamp()+interval '10 seconds'; end if;
  insert into growth_internal.real_name_verifications(user_id,submitted_name,status,document_type,
    proof_mime,proof_data,back_mime,back_data,auto_verify_at)
    values(p_user,current_name,'pending',p_type,p_front_mime,p_front,p_back_mime,p_back,deadline)
  on conflict(user_id) do update set request_id=excluded.request_id,submitted_name=excluded.submitted_name,
    status='pending',document_type=excluded.document_type,proof_mime=excluded.proof_mime,
    proof_data=excluded.proof_data,back_mime=excluded.back_mime,back_data=excluded.back_data,
    auto_verify_at=excluded.auto_verify_at,submitted_at=now(),decided_at=null,rejection_reason=null;
  return jsonb_build_object('status',case when deadline is null then 'pending' else 'processing' end,
    'seconds_remaining',case when deadline is null then null else 10 end);
end $$;

-- Older user apps can still resubmit a rejected request for manual review.
create or replace function public.submit_real_name_verification(p_mime text,p_data text) returns void language plpgsql security definer set search_path='' as $$
declare current_name text; current_status text; old_name text;
begin
 perform growth_internal.require_active();
 select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=auth.uid() for update;
 if current_name is null or length(current_name) not between 1 and 80 then raise exception 'Set your full name first.'; end if;
 if not coalesce(growth_internal.evidence_image_safe(p_mime,p_data),false) then raise exception 'Choose a valid JPEG or PNG image under 512 KB.'; end if;
 select status,submitted_name into current_status,old_name from growth_internal.real_name_verifications where user_id=auth.uid() for update;
 if current_status='pending' then raise exception 'A request is already pending.'; end if;
 if current_status='approved' and old_name=current_name then raise exception 'Name is already verified.'; end if;
 insert into growth_internal.real_name_verifications(user_id,submitted_name,status,proof_mime,proof_data)
 values(auth.uid(),current_name,'pending',p_mime,p_data)
 on conflict(user_id) do update set request_id=excluded.request_id,submitted_name=excluded.submitted_name,status='pending',proof_mime=excluded.proof_mime,proof_data=excluded.proof_data,submitted_at=now(),decided_at=null,
 document_type=null,back_mime=null,back_data=null,auto_verify_at=null,rejection_reason=null;
end $$;

create function growth_internal.finish_real_name_scan(p_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  -- The name trigger already freezes the matching name while approval is queued.
  perform 1 from auth.users where id=p_user for update;
  update growth_internal.real_name_verifications
    set status='approved',proof_data=null,proof_mime=null,back_data=null,back_mime=null,
        auto_verify_at=null,decided_at=clock_timestamp()
    where user_id=p_user and auto_verify_at<=clock_timestamp();
end $$;

create or replace function public.real_name_verification_status() returns jsonb
language plpgsql security definer set search_path='' as $$
declare r growth_internal.real_name_verifications%rowtype; current_name text;
begin
  perform growth_internal.require_active();
  select * into r from growth_internal.real_name_verifications where user_id=auth.uid();
  if r.auto_verify_at<=clock_timestamp() then
    perform growth_internal.finish_real_name_scan(auth.uid());
    select * into r from growth_internal.real_name_verifications where user_id=auth.uid();
  end if;
  select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=auth.uid();
  return jsonb_build_object(
    'status',case when r.status='approved' and r.submitted_name is distinct from current_name then 'name_changed'
      else coalesce(r.status,'none') end,
    'verified_name',case when r.status='approved' and r.submitted_name=current_name then r.submitted_name end,
    'seconds_remaining',case when r.auto_verify_at is not null then
      greatest(1,ceil(extract(epoch from r.auto_verify_at-clock_timestamp()))::integer) end,
    'rejection_reason',case when r.status='rejected' then r.rejection_reason end,
    'profile_name',current_name);
end $$;

-- Keep older admin clients working with one-sided requests; the new dialog sees both.
create function public.admin_real_name_proofs(p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  return (select jsonb_build_object('document_type',document_type,'front',proof_data,'back',back_data)
    from growth_internal.real_name_verifications where request_id=p_request_id and status='pending'
    and (auto_verify_at is null or auto_verify_at>clock_timestamp()));
end $$;

create or replace function public.admin_real_name_requests()
returns table(request_id uuid,user_id uuid,email text,submitted_name text,current_name text,submitted_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin();
  return query select r.request_id,r.user_id,u.email::text,r.submitted_name,
    btrim(u.raw_user_meta_data->>'full_name'),r.submitted_at
    from growth_internal.real_name_verifications r join auth.users u on u.id=r.user_id
    where r.status='pending' and (r.auto_verify_at is null or r.auto_verify_at>clock_timestamp())
    order by r.submitted_at,r.user_id limit 100;
end $$;

create or replace function public.admin_real_name_proof(p_request_id uuid) returns text
language sql security definer set search_path='' as $$
  select public.admin_real_name_proofs(p_request_id)->>'front';
$$;

create function public.admin_decide_real_name(p_request_id uuid,p_approve boolean,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
declare current_name text; target_user uuid; r growth_internal.real_name_verifications%rowtype;
begin
  perform growth_internal.require_admin_editor();
  if p_request_id is null or p_approve is null then raise exception 'Invalid decision.'; end if;
  if not p_approve and coalesce(length(btrim(p_reason)),0) not between 1 and 500 then
    raise exception 'Enter a rejection reason (1–500 characters).';
  end if;
  select user_id into target_user from growth_internal.real_name_verifications where request_id=p_request_id;
  select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=target_user for update;
  select * into r from growth_internal.real_name_verifications where request_id=p_request_id for update;
  if not found or r.status<>'pending' or r.auto_verify_at<=clock_timestamp() then raise exception 'Request unavailable.'; end if;
  if p_approve and current_name is distinct from r.submitted_name then raise exception 'Profile name changed; reject this request.'; end if;
  update growth_internal.real_name_verifications
    set status=case when p_approve then 'approved' else 'rejected' end,
      rejection_reason=case when not p_approve then btrim(p_reason) end,
      proof_mime=null,proof_data=null,back_mime=null,back_data=null,auto_verify_at=null,decided_at=now()
    where request_id=p_request_id;
  insert into growth_internal.admin_operations_audit(actor_id,action,subject_id)
    values(auth.uid(),case when p_approve then 'Real name approved' else 'Real name rejected' end,target_user);
end $$;

create or replace function public.admin_decide_real_name(p_request_id uuid,p_approve boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform growth_internal.require_admin_editor();
  if exists (select 1 from growth_internal.real_name_verifications where request_id=p_request_id and document_type is not null) then
    raise exception 'Update the admin app to review both photos.';
  end if;
  perform public.admin_decide_real_name(p_request_id,p_approve,
    'We could not verify the name on your ID. Retake a clear photo showing your full name.');
end $$;

-- If the app closes during the countdown, pg_cron clears approved proofs in the background.
create function growth_internal.finish_due_real_name_scans() returns void
language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
  for target in select u.id from growth_internal.real_name_verifications r join auth.users u on u.id=r.user_id
      where r.auto_verify_at<=clock_timestamp() order by r.auto_verify_at limit 100 for update of u skip locked
  loop
    perform growth_internal.finish_real_name_scan(target);
  end loop;
end $$;

revoke all on function growth_internal.lock_verified_profile_name(),growth_internal.require_real_name_user(uuid),
  growth_internal.finish_real_name_scan(uuid),growth_internal.finish_due_real_name_scans() from public,anon,authenticated,service_role;
revoke all on function public.allow_real_name_scan(uuid),
  public.submit_scanned_real_name(uuid,text,text,text,text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.allow_real_name_scan(uuid),
  public.submit_scanned_real_name(uuid,text,text,text,text,text,text,boolean) to service_role;
revoke all on function public.admin_real_name_proofs(uuid),public.admin_decide_real_name(uuid,boolean,text) from public,anon;
grant execute on function public.admin_real_name_proofs(uuid),public.admin_decide_real_name(uuid,boolean,text) to authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname='pg_cron') then
    perform cron.schedule('freelan-real-name-verification', '* * * * *',
      'select growth_internal.finish_due_real_name_scans()');
  end if;
end $$;
commit;
