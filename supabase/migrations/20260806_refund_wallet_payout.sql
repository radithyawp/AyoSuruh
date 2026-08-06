-- AyoSuruh - Refund Midtrans + Dompet/Pencairan Mitra
-- Jalankan setelah migration Midtrans tahap 1 dan tahap 2.
-- Refund riil menggunakan Midtrans Sandbox. Payout mitra pada tahap ini memakai provider mock.

-- Nilai enum baru harus ditambahkan di luar blok transaksi agar langsung dapat dipakai.
alter type public.payment_status add value if not exists 'refunded';
alter type public.payment_status add value if not exists 'cancelled';

begin;

-- ---------------------------------------------------------------------------
-- 1. Metadata refund pada pembayaran utama dan setiap attempt.
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists refunded_amount numeric not null default 0,
  add column if not exists refund_status text,
  add column if not exists refunded_at timestamp with time zone;

alter table public.payment_attempts
  add column if not exists refunded_amount numeric not null default 0,
  add column if not exists refund_status text,
  add column if not exists refunded_at timestamp with time zone;

-- ---------------------------------------------------------------------------
-- 2. Permintaan refund customer.
-- ---------------------------------------------------------------------------
create table if not exists public.refund_requests (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  customer_id uuid not null references public.users(id) on delete cascade,
  amount numeric not null check (amount > 0),
  reason text not null check (char_length(trim(reason)) >= 10),
  status text not null default 'requested' check (
    status in (
      'requested',
      'processing',
      'manual_review',
      'refunded',
      'partially_refunded',
      'cancelled',
      'rejected',
      'failed'
    )
  ),
  provider text not null default 'midtrans',
  provider_refund_key text unique,
  provider_refund_id text,
  transaction_status text,
  status_message text,
  requested_at timestamp with time zone not null default timezone('utc'::text, now()),
  processed_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  raw_response jsonb,
  raw_notification jsonb
);

create index if not exists refund_requests_job_idx
  on public.refund_requests(job_id, created_at desc);
create index if not exists refund_requests_payment_idx
  on public.refund_requests(payment_id, created_at desc);
create index if not exists refund_requests_customer_idx
  on public.refund_requests(customer_id, created_at desc);

create unique index if not exists refund_requests_one_active_per_payment_idx
  on public.refund_requests(payment_id)
  where status in ('requested', 'processing', 'manual_review');

create or replace function public.touch_refund_request_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_refund_request_updated_at
on public.refund_requests;
create trigger trg_touch_refund_request_updated_at
before update on public.refund_requests
for each row execute function public.touch_refund_request_updated_at();

alter table public.refund_requests enable row level security;

drop policy if exists "ayo_refunds_read_participants" on public.refund_requests;
create policy "ayo_refunds_read_participants"
on public.refund_requests for select
to authenticated
using (
  customer_id = auth.uid()
  or exists (
    select 1
    from public.jobs j
    where j.id = refund_requests.job_id
      and j.mitra_id = auth.uid()
  )
);

create or replace function public.get_job_refund(p_job_id uuid)
returns setof public.refund_requests
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
    raise exception 'Kamu tidak memiliki akses ke refund pekerjaan ini.';
  end if;

  return query
  select r.*
  from public.refund_requests r
  where r.job_id = p_job_id
  order by r.created_at desc
  limit 1;
end;
$$;

revoke all on function public.get_job_refund(uuid) from public;
grant execute on function public.get_job_refund(uuid) to authenticated;

create or replace function public.get_my_refund_history()
returns table (
  refund_id uuid,
  job_id uuid,
  job_title text,
  amount numeric,
  reason text,
  refund_status text,
  status_message text,
  order_id text,
  requested_at timestamp with time zone,
  processed_at timestamp with time zone
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
    j.id,
    j.title,
    r.amount,
    r.reason,
    r.status,
    r.status_message,
    p.order_id,
    r.requested_at,
    r.processed_at
  from public.refund_requests r
  join public.jobs j on j.id = r.job_id
  join public.payments p on p.id = r.payment_id
  where r.customer_id = auth.uid()
  order by r.requested_at desc;
end;
$$;

revoke all on function public.get_my_refund_history() from public;
grant execute on function public.get_my_refund_history() to authenticated;

-- Penyelesaian manual melalui SQL Editor setelah admin memastikan tindakan
-- refund di dashboard Midtrans. Fungsi ini tidak diberikan ke authenticated.
create or replace function public.process_manual_refund(
  p_refund_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_refund public.refund_requests%rowtype;
  v_job public.jobs%rowtype;
  v_action text := lower(trim(coalesce(p_action, '')));
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_now timestamp with time zone := timezone('utc'::text, now());
begin
  select * into v_refund
  from public.refund_requests
  where id = p_refund_id
  for update;

  if not found then
    raise exception 'Permintaan refund tidak ditemukan.';
  end if;

  if v_refund.status not in ('manual_review', 'processing', 'failed') then
    raise exception 'Status refund ini tidak dapat diselesaikan manual.';
  end if;

  select * into v_job
  from public.jobs
  where id = v_refund.job_id;

  if v_action = 'reject' then
    update public.refund_requests
    set
      status = 'rejected',
      status_message = coalesce(v_note, 'Permintaan refund ditolak setelah pemeriksaan.'),
      processed_at = v_now
    where id = p_refund_id;

    perform public.enqueue_notification(
      p_user_id => v_refund.customer_id,
      p_title => 'Permintaan Refund Ditolak',
      p_body => coalesce(v_note, 'Permintaan refund ditolak setelah pemeriksaan.'),
      p_type => 'refund_failed',
      p_job_id => v_refund.job_id,
      p_data => jsonb_build_object('refund_id', p_refund_id)
    );
  elsif v_action = 'refunded' then
    update public.refund_requests
    set
      status = 'refunded',
      transaction_status = 'refund',
      status_message = coalesce(v_note, 'Refund ditandai selesai setelah verifikasi admin.'),
      processed_at = v_now
    where id = p_refund_id;

    update public.payments
    set
      status = 'refunded'::public.payment_status,
      payment_required = false,
      refund_status = 'refund',
      refunded_amount = v_refund.amount,
      refunded_at = v_now,
      transaction_status = 'refund',
      status_message = coalesce(v_note, 'Refund ditandai selesai setelah verifikasi admin.')
    where id = v_refund.payment_id;

    update public.payment_attempts
    set
      status = 'refunded'::public.payment_status,
      refund_status = 'refund',
      refunded_amount = v_refund.amount,
      refunded_at = v_now,
      transaction_status = 'refund',
      status_message = coalesce(v_note, 'Refund ditandai selesai setelah verifikasi admin.')
    where payment_id = v_refund.payment_id;

    if v_job.id is not null and v_job.status <> 'cancelled'::public.job_status then
      update public.jobs
      set status = 'cancelled'::public.job_status
      where id = v_refund.job_id;

      insert into public.job_timelines (job_id, status, description)
      values (
        v_refund.job_id,
        'cancelled'::public.job_status,
        coalesce(v_note, 'Pekerjaan ditutup setelah refund diselesaikan manual.')
      );
    end if;

    perform public.enqueue_notification(
      p_user_id => v_refund.customer_id,
      p_title => 'Refund Selesai',
      p_body => coalesce(v_note, 'Refund telah diverifikasi dan ditandai selesai.'),
      p_type => 'refund_success',
      p_job_id => v_refund.job_id,
      p_data => jsonb_build_object('refund_id', p_refund_id)
    );

    if v_job.mitra_id is not null then
      perform public.enqueue_notification(
        p_user_id => v_job.mitra_id,
        p_title => 'Pembayaran Direfund',
        p_body => 'Pembayaran pekerjaan telah dikembalikan kepada customer.',
        p_type => 'refund_success',
        p_job_id => v_refund.job_id,
        p_data => jsonb_build_object('refund_id', p_refund_id)
      );
    end if;
  else
    raise exception 'Action harus refunded atau reject.';
  end if;
end;
$$;

revoke all on function public.process_manual_refund(uuid, text, text) from public;

-- ---------------------------------------------------------------------------
-- 3. Payout request dan ledger dompet mitra.
-- ---------------------------------------------------------------------------
create table if not exists public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  mitra_id uuid not null references public.mitras(id) on delete cascade,
  amount numeric not null check (amount > 0),
  bank_name text not null,
  account_number text not null,
  account_holder text not null,
  status text not null default 'requested' check (
    status in (
      'requested',
      'under_review',
      'approved',
      'processing',
      'paid',
      'rejected',
      'failed',
      'cancelled'
    )
  ),
  provider text not null default 'mock',
  provider_reference text,
  rejection_reason text,
  requested_at timestamp with time zone not null default timezone('utc'::text, now()),
  processed_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists payout_requests_mitra_idx
  on public.payout_requests(mitra_id, created_at desc);

create unique index if not exists payout_requests_one_active_idx
  on public.payout_requests(mitra_id)
  where status in ('requested', 'under_review', 'approved', 'processing');

create table if not exists public.mitra_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  mitra_id uuid not null references public.mitras(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  payout_request_id uuid references public.payout_requests(id) on delete set null,
  amount numeric not null check (amount <> 0),
  bucket text not null check (bucket in ('pending', 'available', 'held', 'withdrawn')),
  entry_type text not null check (
    entry_type in (
      'job_earning',
      'payout_hold',
      'payout_release',
      'payout_paid',
      'refund_adjustment',
      'manual_adjustment'
    )
  ),
  state text not null default 'posted' check (state in ('posted', 'reversed')),
  available_at timestamp with time zone,
  reference_key text not null unique,
  description text,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  raw_data jsonb
);

create index if not exists mitra_wallet_ledger_mitra_idx
  on public.mitra_wallet_ledger(mitra_id, created_at desc);
create index if not exists mitra_wallet_ledger_job_idx
  on public.mitra_wallet_ledger(job_id);

create or replace function public.touch_payout_request_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_payout_request_updated_at
on public.payout_requests;
create trigger trg_touch_payout_request_updated_at
before update on public.payout_requests
for each row execute function public.touch_payout_request_updated_at();

alter table public.payout_requests enable row level security;
alter table public.mitra_wallet_ledger enable row level security;

drop policy if exists "ayo_payout_requests_read_own" on public.payout_requests;
create policy "ayo_payout_requests_read_own"
on public.payout_requests for select
to authenticated
using (mitra_id = auth.uid());

drop policy if exists "ayo_wallet_ledger_read_own" on public.mitra_wallet_ledger;
create policy "ayo_wallet_ledger_read_own"
on public.mitra_wallet_ledger for select
to authenticated
using (mitra_id = auth.uid());

-- Lepaskan earning pending yang sudah melewati masa hold.
create or replace function public.release_mature_wallet_entries(p_mitra_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.mitra_wallet_ledger l
  set bucket = 'available'
  where l.bucket = 'pending'
    and l.state = 'posted'
    and l.available_at is not null
    and l.available_at <= timezone('utc'::text, now())
    and (p_mitra_id is null or l.mitra_id = p_mitra_id);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.release_mature_wallet_entries(uuid) from public;

-- Kredit earning hanya ketika payment paid dan pekerjaan completed.
create or replace function public.sync_job_wallet_credit(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mitra_id uuid;
  v_job_status public.job_status;
  v_payment_status public.payment_status;
  v_amount numeric;
begin
  select
    j.mitra_id,
    j.status,
    p.status,
    coalesce(
      (
        select b.price
        from public.bids b
        where b.job_id = j.id
          and b.status = 'accepted'::public.bid_status
        order by b.created_at desc
        limit 1
      ),
      p.amount,
      j.budget,
      0
    )
  into v_mitra_id, v_job_status, v_payment_status, v_amount
  from public.jobs j
  join public.payments p on p.job_id = j.id
  where j.id = p_job_id;

  if not found
     or v_mitra_id is null
     or v_job_status <> 'completed'::public.job_status
     or v_payment_status <> 'paid'::public.payment_status
     or coalesce(v_amount, 0) <= 0 then
    return;
  end if;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    job_id,
    amount,
    bucket,
    entry_type,
    available_at,
    reference_key,
    description
  ) values (
    v_mitra_id,
    p_job_id,
    v_amount,
    'pending',
    'job_earning',
    timezone('utc'::text, now()) + interval '1 day',
    'job:' || p_job_id::text || ':earning',
    'Pendapatan pekerjaan selesai. Menunggu masa hold 1 hari.'
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.sync_job_wallet_credit(uuid) from public;

-- Tarik kembali earning apabila pembayaran kemudian direfund, dibatalkan, atau chargeback.
-- Jika saldo sudah sempat ditahan/dicairkan, adjustment pada bucket available dapat
-- menghasilkan saldo negatif yang harus diselesaikan melalui pemeriksaan admin.
create or replace function public.reverse_job_wallet_credit(
  p_job_id uuid,
  p_reason text default 'Pembayaran direfund atau dibatalkan.'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_earning public.mitra_wallet_ledger%rowtype;
begin
  select l.*
  into v_earning
  from public.mitra_wallet_ledger l
  where l.job_id = p_job_id
    and l.entry_type = 'job_earning'
    and l.state = 'posted'
  order by l.created_at asc
  limit 1;

  if not found then
    return;
  end if;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    job_id,
    amount,
    bucket,
    entry_type,
    reference_key,
    description,
    raw_data
  ) values (
    v_earning.mitra_id,
    p_job_id,
    -v_earning.amount,
    case
      when v_earning.bucket = 'pending' then 'pending'
      else 'available'
    end,
    'refund_adjustment',
    'job:' || p_job_id::text || ':refund_adjustment',
    coalesce(nullif(trim(p_reason), ''), 'Pembayaran direfund atau dibatalkan.'),
    jsonb_build_object(
      'earning_entry_id', v_earning.id,
      'earning_bucket', v_earning.bucket
    )
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.reverse_job_wallet_credit(uuid, text) from public;

create or replace function public.trg_sync_job_wallet_credit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_table_name = 'jobs' then
    if new.status = 'completed'::public.job_status
       and old.status is distinct from new.status then
      perform public.sync_job_wallet_credit(new.id);
    end if;
  elsif tg_table_name = 'payments' then
    if new.status = 'paid'::public.payment_status
       and old.status is distinct from new.status then
      perform public.sync_job_wallet_credit(new.job_id);
    elsif new.status in (
            'refunded'::public.payment_status,
            'cancelled'::public.payment_status
          )
          and old.status is distinct from new.status then
      perform public.reverse_job_wallet_credit(
        new.job_id,
        'Pendapatan ditarik kembali karena pembayaran ' || new.status::text || '.'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_jobs_sync_wallet_credit on public.jobs;
create trigger trg_jobs_sync_wallet_credit
after update of status on public.jobs
for each row execute function public.trg_sync_job_wallet_credit();

drop trigger if exists trg_payments_sync_wallet_credit on public.payments;
create trigger trg_payments_sync_wallet_credit
after update of status on public.payments
for each row execute function public.trg_sync_job_wallet_credit();

-- Backfill pekerjaan lama yang sudah completed dan paid.
do $$
declare
  row_job record;
begin
  for row_job in
    select j.id
    from public.jobs j
    join public.payments p on p.job_id = j.id
    where j.status = 'completed'::public.job_status
      and p.status = 'paid'::public.payment_status
  loop
    perform public.sync_job_wallet_credit(row_job.id);
  end loop;
end
$$;

create or replace function public.get_mitra_wallet_summary()
returns table (
  pending_balance numeric,
  available_balance numeric,
  held_balance numeric,
  withdrawn_total numeric,
  minimum_payout numeric,
  bank_name text,
  account_number text,
  account_holder text,
  active_payout_id uuid,
  active_payout_status text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1 from public.mitras m
    where m.id = auth.uid() and m.is_active = true
  ) then
    raise exception 'Akun ini bukan mitra aktif.';
  end if;

  perform public.release_mature_wallet_entries(auth.uid());

  return query
  with balances as (
    select
      coalesce(sum(l.amount) filter (where l.bucket = 'pending' and l.state = 'posted'), 0) as pending,
      coalesce(sum(l.amount) filter (where l.bucket = 'available' and l.state = 'posted'), 0) as available,
      coalesce(sum(l.amount) filter (where l.bucket = 'held' and l.state = 'posted'), 0) as held,
      coalesce(sum(l.amount) filter (where l.bucket = 'withdrawn' and l.state = 'posted'), 0) as withdrawn
    from public.mitra_wallet_ledger l
    where l.mitra_id = auth.uid()
  ), latest_bank as (
    select
      a.bank_name,
      a.account_number,
      coalesce(u.fullname, 'Mitra Ayo Suruh') as account_holder
    from public.mitra_applications a
    join public.users u on u.id = a.user_id
    where a.user_id = auth.uid()
      and a.status = 'approved'::public.application_status
    order by a.created_at desc
    limit 1
  ), active_payout as (
    select pr.id, pr.status
    from public.payout_requests pr
    where pr.mitra_id = auth.uid()
      and pr.status in ('requested', 'under_review', 'approved', 'processing')
    order by pr.created_at desc
    limit 1
  )
  select
    b.pending,
    b.available,
    b.held,
    b.withdrawn,
    10000::numeric,
    lb.bank_name,
    lb.account_number,
    lb.account_holder,
    ap.id,
    ap.status
  from balances b
  left join latest_bank lb on true
  left join active_payout ap on true;
end;
$$;

revoke all on function public.get_mitra_wallet_summary() from public;
grant execute on function public.get_mitra_wallet_summary() to authenticated;

create or replace function public.get_my_wallet_ledger(p_limit integer default 50)
returns setof public.mitra_wallet_ledger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public.release_mature_wallet_entries(auth.uid());

  return query
  select l.*
  from public.mitra_wallet_ledger l
  where l.mitra_id = auth.uid()
  order by l.created_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 100));
end;
$$;

revoke all on function public.get_my_wallet_ledger(integer) from public;
grant execute on function public.get_my_wallet_ledger(integer) to authenticated;

create or replace function public.get_my_payout_requests()
returns setof public.payout_requests
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  return query
  select pr.*
  from public.payout_requests pr
  where pr.mitra_id = auth.uid()
  order by pr.created_at desc;
end;
$$;

revoke all on function public.get_my_payout_requests() from public;
grant execute on function public.get_my_payout_requests() to authenticated;

create or replace function public.request_mitra_payout(
  p_amount numeric,
  p_bank_name text,
  p_account_number text,
  p_account_holder text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available numeric;
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1 from public.mitras m
    where m.id = auth.uid() and m.is_active = true
  ) then
    raise exception 'Akun ini bukan mitra aktif.';
  end if;

  if p_amount is null or p_amount < 10000 then
    raise exception 'Minimum pencairan adalah Rp10.000.';
  end if;

  if trim(coalesce(p_bank_name, '')) = ''
     or trim(coalesce(p_account_number, '')) = ''
     or trim(coalesce(p_account_holder, '')) = '' then
    raise exception 'Data rekening belum lengkap.';
  end if;

  if exists (
    select 1 from public.payout_requests pr
    where pr.mitra_id = auth.uid()
      and pr.status in ('requested', 'under_review', 'approved', 'processing')
  ) then
    raise exception 'Masih ada pencairan yang sedang diproses.';
  end if;

  perform public.release_mature_wallet_entries(auth.uid());

  select coalesce(sum(l.amount), 0)
  into v_available
  from public.mitra_wallet_ledger l
  where l.mitra_id = auth.uid()
    and l.bucket = 'available'
    and l.state = 'posted';

  if v_available < p_amount then
    raise exception 'Saldo tersedia tidak mencukupi.';
  end if;

  insert into public.payout_requests (
    mitra_id,
    amount,
    bank_name,
    account_number,
    account_holder,
    status,
    provider
  ) values (
    auth.uid(),
    p_amount,
    trim(p_bank_name),
    trim(p_account_number),
    trim(p_account_holder),
    'requested',
    'mock'
  ) returning id into v_request_id;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    payout_request_id,
    amount,
    bucket,
    entry_type,
    reference_key,
    description
  ) values
  (
    auth.uid(),
    v_request_id,
    -p_amount,
    'available',
    'payout_hold',
    'payout:' || v_request_id::text || ':from_available',
    'Saldo ditahan untuk permintaan pencairan.'
  ),
  (
    auth.uid(),
    v_request_id,
    p_amount,
    'held',
    'payout_hold',
    'payout:' || v_request_id::text || ':to_held',
    'Saldo menunggu proses pencairan.'
  );

  perform public.enqueue_notification(
    p_user_id => auth.uid(),
    p_title => 'Pencairan Diajukan',
    p_body => 'Permintaan pencairan saldo sedang menunggu pemeriksaan.',
    p_type => 'payout_requested',
    p_data => jsonb_build_object('payout_request_id', v_request_id)
  );

  return v_request_id;
end;
$$;

revoke all on function public.request_mitra_payout(numeric, text, text, text) from public;
grant execute on function public.request_mitra_payout(numeric, text, text, text) to authenticated;

create or replace function public.cancel_mitra_payout(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.payout_requests%rowtype;
begin
  select * into v_request
  from public.payout_requests
  where id = p_request_id
  for update;

  if not found or auth.uid() is null or v_request.mitra_id <> auth.uid() then
    raise exception 'Permintaan pencairan tidak ditemukan.';
  end if;

  if v_request.status <> 'requested' then
    raise exception 'Pencairan yang sudah diproses tidak dapat dibatalkan.';
  end if;

  update public.payout_requests
  set status = 'cancelled', processed_at = timezone('utc'::text, now())
  where id = p_request_id;

  insert into public.mitra_wallet_ledger (
    mitra_id,
    payout_request_id,
    amount,
    bucket,
    entry_type,
    reference_key,
    description
  ) values
  (
    v_request.mitra_id,
    v_request.id,
    -v_request.amount,
    'held',
    'payout_release',
    'payout:' || v_request.id::text || ':cancel_from_held',
    'Pencairan dibatalkan oleh mitra.'
  ),
  (
    v_request.mitra_id,
    v_request.id,
    v_request.amount,
    'available',
    'payout_release',
    'payout:' || v_request.id::text || ':cancel_to_available',
    'Saldo dikembalikan setelah pencairan dibatalkan.'
  );

  perform public.enqueue_notification(
    p_user_id => v_request.mitra_id,
    p_title => 'Pencairan Dibatalkan',
    p_body => 'Saldo yang ditahan sudah dikembalikan ke saldo tersedia.',
    p_type => 'payout_cancelled',
    p_data => jsonb_build_object('payout_request_id', v_request.id)
  );
end;
$$;

revoke all on function public.cancel_mitra_payout(uuid) from public;
grant execute on function public.cancel_mitra_payout(uuid) to authenticated;

-- Fungsi admin/mock. Tidak diberikan ke role authenticated.
create or replace function public.process_mock_payout(
  p_request_id uuid,
  p_action text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.payout_requests%rowtype;
  v_action text := lower(trim(coalesce(p_action, '')));
begin
  select * into v_request
  from public.payout_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Permintaan pencairan tidak ditemukan.';
  end if;

  if v_request.status not in ('requested', 'under_review', 'approved', 'processing') then
    raise exception 'Status pencairan tidak dapat diproses lagi.';
  end if;

  if v_action = 'review' then
    update public.payout_requests
    set status = 'under_review'
    where id = p_request_id;
  elsif v_action = 'approve' then
    update public.payout_requests
    set status = 'approved'
    where id = p_request_id;
  elsif v_action = 'paid' then
    update public.payout_requests
    set
      status = 'paid',
      provider = 'mock',
      provider_reference = coalesce(provider_reference, 'MOCK-' || upper(substr(replace(id::text, '-', ''), 1, 12))),
      processed_at = timezone('utc'::text, now())
    where id = p_request_id;

    insert into public.mitra_wallet_ledger (
      mitra_id,
      payout_request_id,
      amount,
      bucket,
      entry_type,
      reference_key,
      description
    ) values
    (
      v_request.mitra_id,
      v_request.id,
      -v_request.amount,
      'held',
      'payout_paid',
      'payout:' || v_request.id::text || ':paid_from_held',
      'Saldo pencairan diproses melalui provider mock.'
    ),
    (
      v_request.mitra_id,
      v_request.id,
      v_request.amount,
      'withdrawn',
      'payout_paid',
      'payout:' || v_request.id::text || ':paid_to_withdrawn',
      'Pencairan mock berhasil.'
    )
    on conflict (reference_key) do nothing;

    perform public.enqueue_notification(
      p_user_id => v_request.mitra_id,
      p_title => 'Pencairan Berhasil',
      p_body => 'Pencairan saldo mock telah ditandai berhasil.',
      p_type => 'payout_paid',
      p_data => jsonb_build_object('payout_request_id', v_request.id)
    );
  elsif v_action = 'reject' then
    update public.payout_requests
    set
      status = 'rejected',
      rejection_reason = coalesce(nullif(trim(p_note), ''), 'Permintaan pencairan ditolak.'),
      processed_at = timezone('utc'::text, now())
    where id = p_request_id;

    insert into public.mitra_wallet_ledger (
      mitra_id,
      payout_request_id,
      amount,
      bucket,
      entry_type,
      reference_key,
      description
    ) values
    (
      v_request.mitra_id,
      v_request.id,
      -v_request.amount,
      'held',
      'payout_release',
      'payout:' || v_request.id::text || ':reject_from_held',
      'Pencairan ditolak.'
    ),
    (
      v_request.mitra_id,
      v_request.id,
      v_request.amount,
      'available',
      'payout_release',
      'payout:' || v_request.id::text || ':reject_to_available',
      'Saldo dikembalikan setelah pencairan ditolak.'
    )
    on conflict (reference_key) do nothing;

    perform public.enqueue_notification(
      p_user_id => v_request.mitra_id,
      p_title => 'Pencairan Ditolak',
      p_body => coalesce(nullif(trim(p_note), ''), 'Permintaan pencairan ditolak.'),
      p_type => 'payout_rejected',
      p_data => jsonb_build_object('payout_request_id', v_request.id)
    );
  else
    raise exception 'Action harus review, approve, paid, atau reject.';
  end if;
end;
$$;

revoke all on function public.process_mock_payout(uuid, text, text) from public;

-- Helper khusus pengujian Sandbox. Tidak diberikan ke role authenticated.
create or replace function public.force_release_wallet_for_testing(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.mitra_wallet_ledger
  set available_at = timezone('utc'::text, now()), bucket = 'available'
  where job_id = p_job_id
    and entry_type = 'job_earning'
    and bucket = 'pending';
end;
$$;

revoke all on function public.force_release_wallet_for_testing(uuid) from public;

-- Realtime agar status refund/payout segera berubah di aplikasi.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'refund_requests'
  ) then
    alter publication supabase_realtime add table public.refund_requests;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'payout_requests'
  ) then
    alter publication supabase_realtime add table public.payout_requests;
  end if;
end
$$;

commit;
