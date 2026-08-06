-- AyoSuruh - Midtrans Payment Gateway Stage 2
-- Riwayat transaksi, percobaan pembayaran, realtime, dan retry aman.
-- Jalankan setelah 20260805_midtrans_payment_stage1.sql.

begin;

-- ---------------------------------------------------------------------------
-- 1. Catat setiap Snap order agar retry tidak menghapus riwayat lama.
-- ---------------------------------------------------------------------------
create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  order_id text not null unique,
  snap_token text,
  redirect_url text,
  amount numeric not null,
  service_fee numeric not null default 0,
  status public.payment_status not null default 'pending'::public.payment_status,
  transaction_id text,
  transaction_status text,
  fraud_status text,
  payment_type text,
  status_code text,
  status_message text,
  expires_at timestamp with time zone,
  paid_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  raw_response jsonb,
  raw_notification jsonb
);

create index if not exists payment_attempts_payment_id_idx
  on public.payment_attempts(payment_id, created_at desc);

create index if not exists payment_attempts_job_id_idx
  on public.payment_attempts(job_id, created_at desc);

create or replace function public.touch_payment_attempt_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_payment_attempt_updated_at
on public.payment_attempts;

create trigger trg_touch_payment_attempt_updated_at
before update on public.payment_attempts
for each row execute function public.touch_payment_attempt_updated_at();

-- Backfill order yang dibuat pada tahap 1.
insert into public.payment_attempts (
  payment_id,
  job_id,
  order_id,
  snap_token,
  redirect_url,
  amount,
  service_fee,
  status,
  transaction_id,
  transaction_status,
  fraud_status,
  payment_type,
  status_code,
  status_message,
  expires_at,
  paid_at,
  created_at,
  updated_at,
  raw_response,
  raw_notification
)
select
  p.id,
  p.job_id,
  p.order_id,
  p.snap_token,
  p.redirect_url,
  p.amount,
  p.service_fee,
  p.status,
  p.transaction_id,
  p.transaction_status,
  p.fraud_status,
  p.payment_type,
  p.status_code,
  p.status_message,
  p.expires_at,
  p.paid_at,
  p.created_at,
  p.updated_at,
  p.raw_response,
  p.raw_notification
from public.payments p
where p.order_id is not null
on conflict (order_id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. RLS: hanya customer dan mitra pada job terkait yang boleh membaca.
-- ---------------------------------------------------------------------------
alter table public.payment_attempts enable row level security;

drop policy if exists "ayo_payment_attempts_read_participants"
on public.payment_attempts;

create policy "ayo_payment_attempts_read_participants"
on public.payment_attempts for select
to authenticated
using (
  exists (
    select 1
    from public.jobs j
    where j.id = payment_attempts.job_id
      and (j.customer_id = auth.uid() or j.mitra_id = auth.uid())
  )
);

-- Insert/update hanya dilakukan Edge Function memakai service role.

-- ---------------------------------------------------------------------------
-- 3. RPC riwayat percobaan untuk satu pekerjaan.
-- ---------------------------------------------------------------------------
create or replace function public.get_job_payment_attempts(p_job_id uuid)
returns setof public.payment_attempts
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
    raise exception 'Kamu tidak memiliki akses ke riwayat pembayaran ini.';
  end if;

  return query
  select pa.*
  from public.payment_attempts pa
  where pa.job_id = p_job_id
  order by pa.created_at desc;
end;
$$;

revoke all on function public.get_job_payment_attempts(uuid) from public;
grant execute on function public.get_job_payment_attempts(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC riwayat transaksi customer, termasuk nama mitra tanpa membuka users.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_payment_history()
returns table (
  payment_id uuid,
  job_id uuid,
  job_title text,
  job_status text,
  amount numeric,
  service_fee numeric,
  total numeric,
  payment_status text,
  payment_type text,
  order_id text,
  paid_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  mitra_name text,
  mitra_avatar_url text,
  attempt_count bigint
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
    p.id,
    j.id,
    j.title,
    j.status::text,
    p.amount,
    p.service_fee,
    coalesce(p.amount, 0) + coalesce(p.service_fee, 0),
    p.status::text,
    p.payment_type,
    p.order_id,
    p.paid_at,
    p.created_at,
    p.updated_at,
    coalesce(mu.fullname, 'Mitra Ayo Suruh'),
    mu.avatar_url,
    (
      select count(*)
      from public.payment_attempts pa
      where pa.payment_id = p.id
    )
  from public.payments p
  join public.jobs j on j.id = p.job_id
  left join public.users mu on mu.id = j.mitra_id
  where j.customer_id = auth.uid()
  order by coalesce(p.paid_at, p.updated_at, p.created_at) desc;
end;
$$;

revoke all on function public.get_my_payment_history() from public;
grant execute on function public.get_my_payment_history() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Realtime untuk status payment yang diubah oleh webhook.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'payments'
  ) then
    alter publication supabase_realtime add table public.payments;
  end if;
end
$$;

commit;
