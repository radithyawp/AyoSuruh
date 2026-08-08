-- AyoSuruh: area publik Mitra + jarak ke lokasi pekerjaan pada daftar penawaran.
-- Aman dijalankan setelah 20260805_bid_profile_fix.sql dan migration job/location.
-- Privasi: alamat lengkap Mitra tidak dikirim ke customer. RPC hanya mengembalikan
-- area ringkas dan jarak hasil perhitungan server-side.

create or replace function public.ayo_public_area(p_address text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  parts text[];
  part_count integer;
begin
  select array_agg(trim(raw_part) order by ord)
  into parts
  from unnest(
    regexp_split_to_array(trim(coalesce(p_address, '')), '\s*,\s*')
  ) with ordinality as item(raw_part, ord)
  where trim(raw_part) <> ''
    and lower(trim(raw_part)) <> 'indonesia'
    and trim(raw_part) !~ '^[0-9]{5}$';

  part_count := coalesce(array_length(parts, 1), 0);
  if part_count = 0 then
    return null;
  elsif part_count = 1 then
    return parts[1];
  elsif part_count = 2 then
    return parts[1] || ', ' || parts[2];
  elsif part_count = 3 then
    -- Sembunyikan komponen paling detail, mis. nama jalan/komplek/nomor rumah.
    return parts[2] || ', ' || parts[3];
  end if;

  -- Untuk alamat geocoder yang panjang, cukup tampilkan tiga area administratif
  -- terakhir setelah kode pos/negara dibuang.
  return parts[part_count - 2] || ', '
      || parts[part_count - 1] || ', '
      || parts[part_count];
end;
$$;

revoke all on function public.ayo_public_area(text) from public;

-- Return type RPC bertambah (mitra_area, distance_km), sehingga fungsi lama perlu
-- di-drop lalu dibuat ulang dengan signature parameter yang sama.
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
    select 1
    from public.jobs owner_job
    where owner_job.id = p_job_id
      and owner_job.customer_id = auth.uid()
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
    u.phone as mitra_phone,
    public.ayo_public_area(mitra_address.address) as mitra_area,
    case
      when coalesce(j.latitude, job_address.latitude) is null
        or coalesce(j.longitude, job_address.longitude) is null
        or mitra_address.latitude is null
        or mitra_address.longitude is null
      then null::numeric
      else round(
        (
          6371.0 * 2.0 * asin(
            sqrt(
              least(
                1.0,
                greatest(
                  0.0,
                  power(
                    sin(
                      radians(
                        mitra_address.latitude
                        - coalesce(j.latitude, job_address.latitude)
                      ) / 2.0
                    ),
                    2.0
                  )
                  + cos(radians(coalesce(j.latitude, job_address.latitude)))
                  * cos(radians(mitra_address.latitude))
                  * power(
                    sin(
                      radians(
                        mitra_address.longitude
                        - coalesce(j.longitude, job_address.longitude)
                      ) / 2.0
                    ),
                    2.0
                  )
                )
              )
            )
          )
        )::numeric,
        2
      )
    end as distance_km
  from public.bids b
  join public.jobs j on j.id = b.job_id
  join public.mitras m on m.id = b.mitra_id
  join public.users u on u.id = b.mitra_id
  left join public.addresses job_address on job_address.id = j.address_id
  left join lateral (
    select
      a.address,
      a.latitude,
      a.longitude
    from public.addresses a
    where a.user_id = b.mitra_id
    order by coalesce(a.is_default, false) desc, a.created_at desc
    limit 1
  ) as mitra_address on true
  where b.job_id = p_job_id
  order by b.created_at asc;
end;
$$;

revoke all on function public.get_job_bids_with_profiles(uuid) from public;
grant execute on function public.get_job_bids_with_profiles(uuid) to authenticated;

comment on function public.get_job_bids_with_profiles(uuid) is
  'Mengambil bid, profil publik Mitra, area ringkas, dan jarak ke lokasi pekerjaan hanya untuk customer pemilik job.';
