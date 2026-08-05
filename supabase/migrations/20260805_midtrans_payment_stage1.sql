-- AyoSuruh - Midtrans Payment Gateway Stage 1
-- Fondasi database + Snap-ready tanpa langsung memblokir alur pekerjaan lama.
-- Jalankan setelah seluruh migration fitur job/progress sebelumnya.

begin;

-- ---------------------------------------------------------------------------
-- 1. Kolom generik dan metadata Midtrans
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists provider text not null default 'midtrans',
  add column if not exists payment_required boolean not null default false,
  add column if not exists order_id text,
  add column if not exists snap_token text,
  add column if not exists redirect_url text,
  add column if not exists transaction_id text,
  add column if not exists transaction_status text,
  add column if not exists fraud_status text,
  add column if not exists payment_type text,
  add column if not exists status_code text,
  add column if not exists status_message text,
  add column if not exists expires_at timestamp with time zone,
  add column if not exists updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  add column if not exists raw_response jsonb,
  add column if not exists raw_notification jsonb;

create unique index if not exists payments_job_id_unique
  on public.payments(job_id);

create unique index if not exists payments_order_id_unique
  on public.payments(order_id)
  where order_id is not null;

create or replace function public.touch_payment_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_payment_updated_at on public.payments;
create trigger trg_touch_payment_updated_at
before update on public.payments
for each row execute function public.touch_payment_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Buat transaksi lokal saat customer memilih mitra
--    payment_required tetap false sampai Snap Token berhasil dibuat.
-- ---------------------------------------------------------------------------
create or replace function public.accept_job_bid(
  p_job_id uuid,
  p_bid_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_mitra_id uuid;
  v_bid_price numeric;
  v_job_status public.job_status;
begin
  select j.customer_id, j.status
    into v_customer_id, v_job_status
  from public.jobs j
  where j.id = p_job_id
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if auth.uid() is null or auth.uid() <> v_customer_id then
    raise exception 'Hanya pemilik pekerjaan yang dapat memilih mitra.';
  end if;

  if v_job_status not in (
    'posted'::public.job_status,
    'waiting_bid'::public.job_status
  ) then
    raise exception 'Pekerjaan sudah tidak menerima penawaran.';
  end if;

  select b.mitra_id, b.price
    into v_mitra_id, v_bid_price
  from public.bids b
  where b.id = p_bid_id
    and b.job_id = p_job_id
    and b.status = 'pending'::public.bid_status
  for update;

  if not found then
    raise exception 'Penawaran tidak ditemukan atau sudah diproses.';
  end if;

  update public.bids
  set status = 'rejected'::public.bid_status
  where job_id = p_job_id
    and id <> p_bid_id
    and status = 'pending'::public.bid_status;

  update public.bids
  set status = 'accepted'::public.bid_status
  where id = p_bid_id;

  update public.jobs
  set mitra_id = v_mitra_id,
      status = 'accepted'::public.job_status
  where id = p_job_id;

  insert into public.payments (
    job_id,
    amount,
    service_fee,
    provider,
    payment_required,
    status
  ) values (
    p_job_id,
    v_bid_price,
    0,
    'midtrans',
    false,
    'pending'::public.payment_status
  )
  on conflict (job_id) do update
  set amount = excluded.amount,
      service_fee = excluded.service_fee,
      provider = 'midtrans',
      updated_at = timezone('utc'::text, now())
  where public.payments.status <> 'paid'::public.payment_status;

  insert into public.job_timelines (job_id, status, description)
  values (
    p_job_id,
    'accepted'::public.job_status,
    'Customer memilih mitra untuk mengerjakan pekerjaan.'
  );
end;
$$;

revoke all on function public.accept_job_bid(uuid, uuid) from public;
grant execute on function public.accept_job_bid(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Start job hanya diblokir bila payment_required sudah aktif.
-- ---------------------------------------------------------------------------
create or replace function public.start_assigned_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_required boolean := false;
  v_payment_status public.payment_status;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select p.payment_required, p.status
    into v_payment_required, v_payment_status
  from public.payments p
  where p.job_id = p_job_id;

  if coalesce(v_payment_required, false)
     and coalesce(v_payment_status <> 'paid'::public.payment_status, true) then
    raise exception 'Customer belum menyelesaikan pembayaran Midtrans.';
  end if;

  update public.jobs
  set status = 'on_progress'::public.job_status,
      progress_stage = 'heading_to_location'::public.job_progress_stage
  where id = p_job_id
    and mitra_id = auth.uid()
    and status = 'accepted'::public.job_status;

  if not found then
    raise exception 'Pekerjaan tidak dapat dimulai oleh akun ini.';
  end if;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'on_progress'::public.job_status,
    'heading_to_location'::public.job_progress_stage,
    'Mitra sedang menuju lokasi pekerjaan.'
  );
end;
$$;

revoke all on function public.start_assigned_job(uuid) from public;
grant execute on function public.start_assigned_job(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC baca pembayaran hanya untuk customer/mitra pada job tersebut
-- ---------------------------------------------------------------------------
create or replace function public.get_job_payment(p_job_id uuid)
returns setof public.payments
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1
    from public.jobs j
    where j.id = p_job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  ) then
    raise exception 'Kamu tidak memiliki akses ke pembayaran pekerjaan ini.';
  end if;

  return query
  select p.*
  from public.payments p
  where p.job_id = p_job_id;
end;
$$;

revoke all on function public.get_job_payment(uuid) from public;
grant execute on function public.get_job_payment(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. RLS payments: hanya peserta job yang boleh membaca
-- ---------------------------------------------------------------------------
alter table public.payments enable row level security;

drop policy if exists "ayo_payments_read_participants" on public.payments;
create policy "ayo_payments_read_participants"
on public.payments for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = payments.job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  )
);

-- Tidak ada policy insert/update client. Perubahan provider dilakukan oleh RPC
-- atau Edge Function menggunakan secret/service-role key.

-- ---------------------------------------------------------------------------
-- 6. Backfill transaksi lokal untuk job lama tanpa mewajibkan pembayaran
-- ---------------------------------------------------------------------------
insert into public.payments (
  job_id,
  amount,
  service_fee,
  provider,
  payment_required,
  status,
  paid_at
)
select
  j.id,
  coalesce(b.price, j.budget, 0),
  0,
  'midtrans',
  false,
  case
    when j.status in ('on_progress'::public.job_status, 'completed'::public.job_status)
      then 'paid'::public.payment_status
    else 'pending'::public.payment_status
  end,
  case
    when j.status in ('on_progress'::public.job_status, 'completed'::public.job_status)
      then coalesce(j.created_at, timezone('utc'::text, now()))
    else null
  end
from public.jobs j
left join lateral (
  select b.price
  from public.bids b
  where b.job_id = j.id
    and b.status = 'accepted'::public.bid_status
  order by b.created_at desc
  limit 1
) b on true
where j.mitra_id is not null
  and j.status in (
    'accepted'::public.job_status,
    'on_progress'::public.job_status,
    'completed'::public.job_status
  )
on conflict (job_id) do nothing;

commit;
