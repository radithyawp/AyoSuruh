-- AyoSuruh - Google OAuth profile synchronization
-- Safe to run repeatedly.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  resolved_name text;
  resolved_phone text;
  resolved_avatar text;
begin
  resolved_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'fullname'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Pengguna Ayo Suruh'
  );

  resolved_phone := coalesce(
    nullif(trim(new.phone), ''),
    nullif(trim(new.raw_user_meta_data ->> 'phone'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'phone_number'), '')
  );

  resolved_avatar := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'picture'), '')
  );

  insert into public.users (
    id,
    email,
    fullname,
    phone,
    avatar_url
  )
  values (
    new.id,
    new.email,
    resolved_name,
    resolved_phone,
    resolved_avatar
  )
  on conflict (id) do update
  set
    email = excluded.email,
    fullname = case
      when public.users.fullname is null or trim(public.users.fullname) = ''
        then excluded.fullname
      else public.users.fullname
    end,
    phone = coalesce(nullif(trim(public.users.phone), ''), excluded.phone),
    avatar_url = coalesce(
      nullif(trim(public.users.avatar_url), ''),
      excluded.avatar_url
    );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_sync_profile on auth.users;
create trigger on_auth_user_created_sync_profile
after insert or update of email, phone, raw_user_meta_data
on auth.users
for each row
execute function public.handle_new_auth_user();

create or replace function public.sync_current_user_profile()
returns public.users
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  auth_row auth.users%rowtype;
  result_row public.users%rowtype;
  resolved_name text;
  resolved_phone text;
  resolved_avatar text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login' using errcode = 'P0001';
  end if;

  select *
  into auth_row
  from auth.users
  where id = auth.uid();

  if not found then
    raise exception 'Data Auth pengguna tidak ditemukan' using errcode = 'P0001';
  end if;

  resolved_name := coalesce(
    nullif(trim(auth_row.raw_user_meta_data ->> 'fullname'), ''),
    nullif(trim(auth_row.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(auth_row.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(auth_row.email, ''), '@', 1), ''),
    'Pengguna Ayo Suruh'
  );

  resolved_phone := coalesce(
    nullif(trim(auth_row.phone), ''),
    nullif(trim(auth_row.raw_user_meta_data ->> 'phone'), ''),
    nullif(trim(auth_row.raw_user_meta_data ->> 'phone_number'), '')
  );

  resolved_avatar := coalesce(
    nullif(trim(auth_row.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(trim(auth_row.raw_user_meta_data ->> 'picture'), '')
  );

  insert into public.users (
    id,
    email,
    fullname,
    phone,
    avatar_url
  )
  values (
    auth_row.id,
    auth_row.email,
    resolved_name,
    resolved_phone,
    resolved_avatar
  )
  on conflict (id) do update
  set
    email = excluded.email,
    fullname = case
      when public.users.fullname is null or trim(public.users.fullname) = ''
        then excluded.fullname
      else public.users.fullname
    end,
    phone = coalesce(nullif(trim(public.users.phone), ''), excluded.phone),
    avatar_url = coalesce(
      nullif(trim(public.users.avatar_url), ''),
      excluded.avatar_url
    )
  returning * into result_row;

  return result_row;
end;
$$;

revoke all on function public.sync_current_user_profile() from public;
grant execute on function public.sync_current_user_profile() to authenticated;
grant execute on function public.sync_current_user_profile() to service_role;

-- Backfill akun lama yang belum mempunyai profil public.users.
insert into public.users (
  id,
  email,
  fullname,
  phone,
  avatar_url
)
select
  au.id,
  au.email,
  coalesce(
    nullif(trim(au.raw_user_meta_data ->> 'fullname'), ''),
    nullif(trim(au.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(au.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(au.email, ''), '@', 1), ''),
    'Pengguna Ayo Suruh'
  ),
  coalesce(
    nullif(trim(au.phone), ''),
    nullif(trim(au.raw_user_meta_data ->> 'phone'), ''),
    nullif(trim(au.raw_user_meta_data ->> 'phone_number'), '')
  ),
  coalesce(
    nullif(trim(au.raw_user_meta_data ->> 'avatar_url'), ''),
    nullif(trim(au.raw_user_meta_data ->> 'picture'), '')
  )
from auth.users au
on conflict (id) do nothing;
