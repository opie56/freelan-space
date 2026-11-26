-- Keep historical accounts intact while preventing new duplicate claims.
begin;
create index instagram_accounts_username_lookup on public.instagram_accounts (lower(username));

create or replace function public.add_instagram_account(p_username text) returns void
language plpgsql security definer set search_path='' as $$
declare handle text := regexp_replace(trim(coalesce(p_username,'')), '^@', '');
begin
  perform growth_internal.require_active();
  if handle !~ '^[A-Za-z0-9._]{1,30}$' then
    raise exception 'Invalid Instagram username.' using errcode='P0001';
  end if;
  -- Serialize claims of the same handle, including claims from different users.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(lower(handle), 0));
  if exists (select 1 from public.instagram_accounts where lower(username)=lower(handle)) then
    raise exception 'Username already added.' using errcode='23505';
  end if;
  insert into public.instagram_accounts(user_id,username) values(auth.uid(),handle);
end $$;

-- Existing clients must not be able to remove an account either.
revoke execute on function public.remove_instagram_account(text) from public, anon, authenticated;
commit;
