-- AyoSuruh: Lokasi Utama Mitra wajib + sumber jarak penawaran.
-- Jalankan setelah:
-- 1) 20260808_batch11_stability_admin.sql
-- 2) 20260808_bid_location_distance.sql

alter table public.addresses
  add column if not exists is_mitra_base boolean not null default false;

-- Seed Mitra lama yang sudah punya alamat berkoordinat agar tidak kehilangan jarak.
with candidate as (
  select
    a.id,
    row_number() over (
      partition by a.user_id
      order by coalesce(a.is_default, false) desc, a.created_at desc
    ) as rn
  from public.addresses a
  join public.mitras m on m.id = a.user_id
  where a.latitude is not null
    and a.longitude is not null
    and not exists (
      select 1
      from public.addresses existing
      where existing.user_id = a.user_id
        and existing.is_mitra_base = true
    )
)
update public.addresses a
set is_mitra_base = true,
    label = coalesce(nullif(trim(a.label), ''), 'Lokasi Utama Mitra')
from candidate c
where a.id = c.id and c.rn = 1;

create unique index if not exists addresses_one_mitra_base_per_user_idx
  on public.addresses(user_id)
  where is_mitra_base = true;

create or replace function public.get_my_mitra_base_location()
returns table (
  id uuid,
  address text,
  latitude double precision,
  longitude double precision,
  updated_at timestamp with time zone
)
language sql
security definer
stable
set search_path = public
as $$
  select
    a.id,
    a.address,
    a.latitude,
    a.longitude,
    a.created_at as updated_at
  from public.addresses a
  where a.user_id = auth.uid()
    and a.is_mitra_base = true
  order by a.created_at desc
  limit 1;
$$;

revoke all on function public.get_my_mitra_base_location() from public;
grant execute on function public.get_my_mitra_base_location() to authenticated;

create or replace function public.save_my_mitra_base_location(
  p_address text,
  p_latitude double precision,
  p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_address_id uuid;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;
  if char_length(trim(coalesce(p_address, ''))) < 8 then
    raise exception 'Alamat Mitra belum lengkap.';
  end if;
  if p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Koordinat Lokasi Mitra tidak valid.';
  end if;

  select a.id into v_address_id
  from public.addresses a
  where a.user_id = v_user_id and a.is_mitra_base = true
  limit 1
  for update;

  if v_address_id is null then
    insert into public.addresses (
      user_id, label, address, latitude, longitude, is_default, is_mitra_base
    ) values (
      v_user_id,
      'Lokasi Utama Mitra',
      trim(p_address),
      p_latitude,
      p_longitude,
      false,
      true
    )
    returning id into v_address_id;
  else
    update public.addresses
    set label = 'Lokasi Utama Mitra',
        address = trim(p_address),
        latitude = p_latitude,
        longitude = p_longitude,
        is_mitra_base = true
    where id = v_address_id and user_id = v_user_id;
  end if;

  return v_address_id;
end;
$$;

revoke all on function public.save_my_mitra_base_location(text, double precision, double precision) from public;
grant execute on function public.save_my_mitra_base_location(text, double precision, double precision) to authenticated;

-- Pendaftaran Mitra tidak boleh masuk status applied tanpa titik Lokasi Utama Mitra.
create or replace function public.enforce_mitra_application_base_location()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.status = 'applied'::public.application_status and not exists (
    select 1
    from public.addresses a
    where a.user_id = new.user_id
      and a.is_mitra_base = true
      and a.latitude is not null
      and a.longitude is not null
  ) then
    raise exception 'Tentukan Lokasi Utama Mitra terlebih dahulu.';
  end if;
  return new;
end;
$$;

drop trigger if exists ayo_require_mitra_location_on_application on public.mitra_applications;
create trigger ayo_require_mitra_location_on_application
before insert or update of status on public.mitra_applications
for each row execute function public.enforce_mitra_application_base_location();

-- Mitra juga tidak boleh membuat bid baru sebelum lokasi utamanya lengkap.
create or replace function public.enforce_bid_mitra_base_location()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.addresses a
    where a.user_id = new.mitra_id
      and a.is_mitra_base = true
      and a.latitude is not null
      and a.longitude is not null
  ) then
    raise exception 'Lengkapi Lokasi Utama Mitra di Profil sebelum mengajukan penawaran.';
  end if;
  return new;
end;
$$;

drop trigger if exists ayo_require_mitra_base_location_on_bid on public.bids;
create trigger ayo_require_mitra_base_location_on_bid
before insert on public.bids
for each row execute function public.enforce_bid_mitra_base_location();

-- Approval Admin/service-role juga wajib memastikan lokasi calon Mitra sudah lengkap.
create or replace function public.approve_mitra_application(
  p_application_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
begin
  select application.user_id
  into v_user_id
  from public.mitra_applications application
  where application.id = p_application_id
  for update;

  if v_user_id is null then
    raise exception 'Pengajuan mitra tidak ditemukan.';
  end if;

  if not exists (
    select 1 from public.addresses a
    where a.user_id = v_user_id
      and a.is_mitra_base = true
      and a.latitude is not null
      and a.longitude is not null
  ) then
    raise exception 'Lokasi Utama Mitra belum dilengkapi.';
  end if;

  update public.mitra_applications
  set status = 'approved'::public.application_status,
      review_notes = null,
      reviewed_at = timezone('utc'::text, now()),
      updated_at = timezone('utc'::text, now())
  where id = p_application_id;

  update public.mitra_documents
  set verified = true,
      updated_at = timezone('utc'::text, now())
  where application_id = p_application_id;

  update public.users
  set role = 'mitra'::public.user_role
  where id = v_user_id;

  insert into public.mitras (id, rating, is_active)
  values (v_user_id, 0, true)
  on conflict (id) do update set is_active = true;

  perform public.enqueue_notification(
    v_user_id,
    'Pengajuan Mitra Disetujui',
    'Selamat! Akunmu sekarang aktif sebagai Mitra Ayo Suruh.',
    'mitra_application_approved',
    null,
    null,
    null,
    jsonb_build_object('application_id', p_application_id)
  );
end;
$$;

revoke all on function public.approve_mitra_application(uuid)
  from public, anon, authenticated;
grant execute on function public.approve_mitra_application(uuid)
  to service_role;

-- Gunakan HANYA Lokasi Utama Mitra sebagai sumber area/jarak penawaran.
drop function if exists public.get_job_bids_with_profiles(uuid);

create function public.get_job_bids_with_profiles(p_job_id uuid)
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
  mitra_phone text,
  mitra_area text,
  distance_km numeric
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
    select 1 from public.jobs owner_job
    where owner_job.id = p_job_id and owner_job.customer_id = auth.uid()
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
    coalesce(m.rating, 0::numeric),
    coalesce(m.is_active, false),
    coalesce(nullif(btrim(u.fullname), ''), 'Mitra Ayo Suruh'),
    u.avatar_url,
    u.phone,
    public.ayo_public_area(mitra_address.address),
    case
      when coalesce(j.latitude, job_address.latitude) is null
        or coalesce(j.longitude, job_address.longitude) is null
        or mitra_address.latitude is null
        or mitra_address.longitude is null
      then null::numeric
      else round((
        6371.0 * 2.0 * asin(
          sqrt(least(1.0, greatest(0.0,
            power(sin(radians(mitra_address.latitude - coalesce(j.latitude, job_address.latitude)) / 2.0), 2.0)
            + cos(radians(coalesce(j.latitude, job_address.latitude)))
            * cos(radians(mitra_address.latitude))
            * power(sin(radians(mitra_address.longitude - coalesce(j.longitude, job_address.longitude)) / 2.0), 2.0)
          )))
        )
      )::numeric, 2)
    end
  from public.bids b
  join public.jobs j on j.id = b.job_id
  join public.mitras m on m.id = b.mitra_id
  join public.users u on u.id = b.mitra_id
  left join public.addresses job_address on job_address.id = j.address_id
  left join lateral (
    select a.address, a.latitude, a.longitude
    from public.addresses a
    where a.user_id = b.mitra_id
      and a.is_mitra_base = true
    limit 1
  ) mitra_address on true
  where b.job_id = p_job_id
  order by b.created_at asc;
end;
$$;

revoke all on function public.get_job_bids_with_profiles(uuid) from public;
grant execute on function public.get_job_bids_with_profiles(uuid) to authenticated;
