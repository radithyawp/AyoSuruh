-- AyoSuruh: tampilkan profil mitra pada halaman Penawaran Mitra
-- Aman dijalankan berulang kali.

create or replace function public.get_job_bids_with_profiles(p_job_id uuid)
returns table (
  id uuid,
  job_id uuid,
  mitra_id uuid,
  price numeric,
  estimated_time text,
  message text,
  status public.bid_status,
  created_at timestamp with time zone,
  mitra_rating numeric,
  mitra_is_active boolean,
  mitra_fullname text,
  mitra_avatar_url text,
  mitra_phone text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'Sesi login tidak ditemukan.' using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.jobs j
    where j.id = p_job_id
      and j.customer_id = auth.uid()
  ) then
    raise exception 'Kamu bukan pemilik pekerjaan ini.' using errcode = 'P0001';
  end if;

  return query
  select
    b.id,
    b.job_id,
    b.mitra_id,
    b.price,
    b.estimated_time,
    b.message,
    b.status,
    b.created_at,
    coalesce(m.rating, 0::numeric) as mitra_rating,
    coalesce(m.is_active, false) as mitra_is_active,
    coalesce(nullif(btrim(u.fullname), ''), 'Mitra Ayo Suruh') as mitra_fullname,
    u.avatar_url as mitra_avatar_url,
    u.phone as mitra_phone
  from public.bids b
  join public.mitras m on m.id = b.mitra_id
  join public.users u on u.id = b.mitra_id
  where b.job_id = p_job_id
  order by b.created_at asc;
end;
$$;

revoke all on function public.get_job_bids_with_profiles(uuid) from public;
grant execute on function public.get_job_bids_with_profiles(uuid) to authenticated;

comment on function public.get_job_bids_with_profiles(uuid) is
  'Mengambil bid dan profil mitra hanya untuk customer pemilik job.';
