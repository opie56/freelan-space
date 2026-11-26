begin;
-- Proof is private, bounded and removed when a decision is made or the account is deleted.
create table growth_internal.real_name_verifications (
 user_id uuid primary key references auth.users(id) on delete cascade,
 request_id uuid not null unique default gen_random_uuid(),
 submitted_name text not null check(length(submitted_name) between 1 and 80),
 status text not null check(status in ('pending','approved','rejected')),
 proof_mime text,
 proof_data text,
 submitted_at timestamptz not null default now(),
 decided_at timestamptz,
 check ((status='pending' and proof_mime is not null and proof_data is not null) or (status<>'pending' and proof_mime is null and proof_data is null))
);
alter table growth_internal.real_name_verifications enable row level security;
revoke all on growth_internal.real_name_verifications from public, anon, authenticated;

create function public.real_name_verification_status() returns jsonb language plpgsql security definer set search_path='' as $$
declare r growth_internal.real_name_verifications%rowtype; current_name text;
begin
 perform growth_internal.require_active();
 select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=auth.uid();
 select * into r from growth_internal.real_name_verifications where user_id=auth.uid();
 if not found then return jsonb_build_object('status','none'); end if;
 return jsonb_build_object('status',case when r.status='approved' and r.submitted_name is distinct from current_name then 'name_changed' else r.status end,
  'verified_name',case when r.status='approved' and r.submitted_name=current_name then r.submitted_name else null end);
end $$;

create function public.submit_real_name_verification(p_mime text,p_data text) returns void language plpgsql security definer set search_path='' as $$
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
 on conflict(user_id) do update set request_id=excluded.request_id,submitted_name=excluded.submitted_name,status='pending',proof_mime=excluded.proof_mime,proof_data=excluded.proof_data,submitted_at=now(),decided_at=null;
end $$;

create function public.admin_real_name_requests() returns table(request_id uuid,user_id uuid,email text,submitted_name text,current_name text,submitted_at timestamptz) language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin();
 return query select r.request_id,r.user_id,u.email::text,r.submitted_name,btrim(u.raw_user_meta_data->>'full_name'),r.submitted_at from growth_internal.real_name_verifications r join auth.users u on u.id=r.user_id where r.status='pending' order by r.submitted_at,r.user_id limit 100;
end $$;
create function public.admin_real_name_proof(p_request_id uuid) returns text language plpgsql security definer set search_path='' as $$
begin perform growth_internal.require_admin();
 return (select proof_data from growth_internal.real_name_verifications where request_id=p_request_id and status='pending');
end $$;
create function public.admin_decide_real_name(p_request_id uuid,p_approve boolean) returns void language plpgsql security definer set search_path='' as $$
declare current_name text; target_user uuid; r growth_internal.real_name_verifications%rowtype;
begin
 perform growth_internal.require_admin_editor();
 if p_request_id is null or p_approve is null then raise exception 'Invalid decision.'; end if;
 select user_id into target_user from growth_internal.real_name_verifications where request_id=p_request_id;
 select btrim(raw_user_meta_data->>'full_name') into current_name from auth.users where id=target_user for update;
 select * into r from growth_internal.real_name_verifications where request_id=p_request_id for update;
 if not found or r.status<>'pending' then raise exception 'Request unavailable.'; end if;
 if p_approve and current_name is distinct from r.submitted_name then raise exception 'Profile name changed; reject this request.'; end if;
 update growth_internal.real_name_verifications set status=case when p_approve then 'approved' else 'rejected' end,proof_mime=null,proof_data=null,decided_at=now() where request_id=p_request_id;
 insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),case when p_approve then 'Real name approved' else 'Real name rejected' end,target_user);
end $$;
revoke all on function public.real_name_verification_status(),public.submit_real_name_verification(text,text),public.admin_real_name_requests(),public.admin_real_name_proof(uuid),public.admin_decide_real_name(uuid,boolean) from public,anon;
grant execute on function public.real_name_verification_status(),public.submit_real_name_verification(text,text),public.admin_real_name_requests(),public.admin_real_name_proof(uuid),public.admin_decide_real_name(uuid,boolean) to authenticated;
commit;
