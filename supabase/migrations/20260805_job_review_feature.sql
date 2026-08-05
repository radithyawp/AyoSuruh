-- Ayo Suruh - Rating dan ulasan mitra
-- Jalankan setelah 20260805_job_progress_feature.sql.

-- ---------------------------------------------------------------------------
-- 1. Struktur review
-- ---------------------------------------------------------------------------
alter table public.reviews
  add column if not exists tags text[] not null default '{}'::text[];

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'reviews_job_unique'
      and conrelid = 'public.reviews'::regclass
  ) then
    alter table public.reviews
      add constraint reviews_job_unique unique (job_id);
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. Sinkronisasi pendapatan saat pekerjaan selesai
-- ---------------------------------------------------------------------------
create or replace function public.ensure_completed_job_earning(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mitra_id uuid;
  v_status public.job_status;
  v_amount numeric;
  v_type_schema text;
  v_type_name text;
  v_type_label text;
begin
  select
    j.mitra_id,
    j.status,
    coalesce(
      (
        select b.price
        from public.bids b
        where b.job_id = j.id
          and b.status = 'accepted'::public.bid_status
        order by b.created_at desc
        limit 1
      ),
      j.budget,
      0
    )
  into v_mitra_id, v_status, v_amount
  from public.jobs j
  where j.id = p_job_id;

  if not found
     or v_status <> 'completed'::public.job_status
     or v_mitra_id is null
     or coalesce(v_amount, 0) <= 0 then
    return;
  end if;

  if exists (
    select 1
    from public.earnings e
    where e.job_id = p_job_id
  ) then
    return;
  end if;

  select ns.nspname, t.typname
  into v_type_schema, v_type_name
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace cn on cn.oid = c.relnamespace
  join pg_type t on t.oid = a.atttypid
  join pg_namespace ns on ns.oid = t.typnamespace
  where cn.nspname = 'public'
    and c.relname = 'earnings'
    and a.attname = 'type'
    and a.attnum > 0
    and not a.attisdropped;

  select e.enumlabel
  into v_type_label
  from pg_enum e
  join pg_type t on t.oid = e.enumtypid
  join pg_namespace ns on ns.oid = t.typnamespace
  where t.typname = v_type_name
    and ns.nspname = v_type_schema
    and lower(e.enumlabel) in (
      'income',
      'job_income',
      'earning',
      'credit',
      'pendapatan',
      'job'
    )
  order by
    case lower(e.enumlabel)
      when 'income' then 1
      when 'job_income' then 2
      when 'earning' then 3
      when 'credit' then 4
      when 'pendapatan' then 5
      when 'job' then 6
      else 100
    end,
    e.enumsortorder
  limit 1;

  if v_type_label is null then
    raise notice 'Pendapatan job % belum dicatat karena enum earnings.type tidak memiliki label pemasukan yang dikenali.', p_job_id;
    return;
  end if;

  execute format(
    'insert into public.earnings (mitra_id, job_id, amount, type) '
    'values ($1, $2, $3, %L::%I.%I)',
    v_type_label,
    v_type_schema,
    v_type_name
  )
  using v_mitra_id, p_job_id, v_amount;
end;
$$;

revoke all on function public.ensure_completed_job_earning(uuid) from public;

-- Perbarui RPC konfirmasi agar pendapatan tercatat pada transaksi yang sama.
create or replace function public.confirm_job_completion(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_status public.job_status;
  v_progress public.job_progress_stage;
begin
  select j.customer_id, j.status, j.progress_stage
  into v_customer_id, v_status, v_progress
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if auth.uid() is null or auth.uid() <> v_customer_id then
    raise exception 'Hanya pemilik pekerjaan yang dapat mengonfirmasi.';
  end if;

  if v_status <> 'on_progress'::public.job_status
     or v_progress <> 'completion_submitted'::public.job_progress_stage then
    raise exception 'Mitra belum mengajukan pekerjaan selesai.';
  end if;

  update public.jobs
  set status = 'completed'::public.job_status
  where id = p_job_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'completed'::public.job_status,
    'completion_submitted'::public.job_progress_stage,
    'Customer mengonfirmasi bahwa pekerjaan telah selesai.'
  );

  perform public.ensure_completed_job_earning(p_job_id);
end;
$$;

revoke all on function public.confirm_job_completion(uuid) from public;
grant execute on function public.confirm_job_completion(uuid) to authenticated;

-- Backfill pendapatan untuk job yang sudah selesai sebelum migration ini.
do $$
declare
  completed_job record;
begin
  for completed_job in
    select j.id
    from public.jobs j
    where j.status = 'completed'::public.job_status
  loop
    perform public.ensure_completed_job_earning(completed_job.id);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- 3. Sinkronisasi rating rata-rata mitra
-- ---------------------------------------------------------------------------
create or replace function public.refresh_mitra_rating_from_reviews()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mitra_id uuid;
begin
  if tg_op = 'DELETE' then
    v_mitra_id := old.mitra_id;
  else
    v_mitra_id := new.mitra_id;
  end if;

  update public.mitras m
  set rating = coalesce(
    (
      select round(avg(r.rating)::numeric, 2)
      from public.reviews r
      where r.mitra_id = v_mitra_id
    ),
    0
  )
  where m.id = v_mitra_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_refresh_mitra_rating_from_reviews
on public.reviews;

create trigger trg_refresh_mitra_rating_from_reviews
after insert or update or delete
on public.reviews
for each row
execute function public.refresh_mitra_rating_from_reviews();

-- Hitung ulang rating untuk data review yang mungkin sudah ada.
update public.mitras m
set rating = coalesce(
  (
    select round(avg(r.rating)::numeric, 2)
    from public.reviews r
    where r.mitra_id = m.id
  ),
  0
);

-- ---------------------------------------------------------------------------
-- 4. RPC customer mengirim satu penilaian untuk job yang telah selesai
-- ---------------------------------------------------------------------------
create or replace function public.submit_job_review(
  p_job_id uuid,
  p_rating integer,
  p_review text default null,
  p_tags text[] default '{}'::text[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_mitra_id uuid;
  v_status public.job_status;
  v_review_id uuid;
  v_tags text[];
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating harus berada di antara 1 sampai 5.';
  end if;

  select j.customer_id, j.mitra_id, j.status
  into v_customer_id, v_mitra_id, v_status
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if auth.uid() <> v_customer_id then
    raise exception 'Hanya customer pemilik pekerjaan yang dapat memberi penilaian.';
  end if;

  if v_status <> 'completed'::public.job_status then
    raise exception 'Penilaian hanya dapat diberikan setelah pekerjaan selesai.';
  end if;

  if v_mitra_id is null then
    raise exception 'Pekerjaan ini belum memiliki mitra.';
  end if;

  select coalesce(array_agg(tag_value), '{}'::text[])
  into v_tags
  from (
    select distinct trim(raw_tag) as tag_value
    from unnest(coalesce(p_tags, '{}'::text[])) as supplied_tags(raw_tag)
    where trim(raw_tag) <> ''
    limit 6
  ) cleaned_tags;

  insert into public.reviews (
    job_id,
    customer_id,
    mitra_id,
    rating,
    review,
    tags
  ) values (
    p_job_id,
    v_customer_id,
    v_mitra_id,
    p_rating,
    nullif(trim(p_review), ''),
    v_tags
  )
  returning id into v_review_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'completed'::public.job_status,
    'completion_submitted'::public.job_progress_stage,
    format('Customer memberikan penilaian %s dari 5.', p_rating)
  );

  return v_review_id;
exception
  when unique_violation then
    raise exception 'Pekerjaan ini sudah pernah diberi penilaian.';
end;
$$;

revoke all on function public.submit_job_review(uuid, integer, text, text[])
from public;
grant execute on function public.submit_job_review(uuid, integer, text, text[])
to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RPC membaca review untuk customer dan mitra yang terlibat
-- ---------------------------------------------------------------------------
create or replace function public.get_job_review(p_job_id uuid)
returns table (
  id uuid,
  job_id uuid,
  customer_id uuid,
  mitra_id uuid,
  rating integer,
  review text,
  tags text[],
  created_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  return query
  select
    r.id,
    r.job_id,
    r.customer_id,
    r.mitra_id,
    r.rating,
    r.review,
    r.tags,
    r.created_at
  from public.reviews r
  join public.jobs j on j.id = r.job_id
  where r.job_id = p_job_id
    and (j.customer_id = auth.uid() or j.mitra_id = auth.uid());
end;
$$;

revoke all on function public.get_job_review(uuid) from public;
grant execute on function public.get_job_review(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RLS review
-- ---------------------------------------------------------------------------
alter table public.reviews enable row level security;

drop policy if exists "ayo_reviews_read_participants" on public.reviews;
create policy "ayo_reviews_read_participants"
on public.reviews for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = reviews.job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  )
);

-- Insert normal diarahkan melalui RPC agar validasi job dan sinkronisasi rating
-- dilakukan secara atomik. Policy ini menjadi lapisan pengaman tambahan.
drop policy if exists "ayo_reviews_insert_customer" on public.reviews;
create policy "ayo_reviews_insert_customer"
on public.reviews for insert
to authenticated
with check (
  customer_id = auth.uid()
  and exists (
    select 1
    from public.jobs j
    where j.id = reviews.job_id
      and j.customer_id = auth.uid()
      and j.mitra_id = reviews.mitra_id
      and j.status = 'completed'::public.job_status
  )
);
