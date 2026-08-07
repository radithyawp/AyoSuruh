-- Ayo Suruh - Transaction Economics / Platform Commission
-- Core revenue model: Ayo Suruh mengambil 6% dari nilai jasa transaksi berhasil.
-- Fee ini merupakan platform commission (take rate), BUKAN biaya payment gateway.
-- Nilai fee disnapshot per transaksi agar histori tidak berubah ketika rate di masa depan diubah.

begin;

-- ---------------------------------------------------------------------------
-- 1. Business settings. Satu row aktif untuk parameter komersial utama.
-- ---------------------------------------------------------------------------
create table if not exists public.business_settings (
  id smallint primary key default 1 check (id = 1),
  platform_fee_percent numeric(5,2) not null default 6.00
    check (platform_fee_percent >= 0 and platform_fee_percent <= 100),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

insert into public.business_settings (id, platform_fee_percent)
values (1, 6.00)
on conflict (id) do nothing;

alter table public.business_settings enable row level security;

-- Tidak memberikan write policy ke client. Perubahan rate dilakukan melalui
-- SQL/admin backend, bukan langsung dari aplikasi customer/mitra.
drop policy if exists "ayo_business_settings_read" on public.business_settings;
create policy "ayo_business_settings_read"
on public.business_settings for select
to authenticated
using (true);

create or replace function public.touch_business_settings_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$;

drop trigger if exists trg_touch_business_settings_updated_at
on public.business_settings;
create trigger trg_touch_business_settings_updated_at
before update on public.business_settings
for each row execute function public.touch_business_settings_updated_at();

create or replace function public.current_platform_fee_percent()
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select bs.platform_fee_percent from public.business_settings bs where bs.id = 1),
    6.00::numeric
  );
$$;

revoke all on function public.current_platform_fee_percent() from public;
grant execute on function public.current_platform_fee_percent() to authenticated;
grant execute on function public.current_platform_fee_percent() to service_role;

create or replace function public.get_business_settings()
returns table (
  platform_fee_percent numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select public.current_platform_fee_percent();
$$;

revoke all on function public.get_business_settings() from public;
grant execute on function public.get_business_settings() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Snapshot ekonomi pada pembayaran utama dan setiap payment attempt.
-- amount                  = harga jasa yang disepakati customer & mitra (GMV)
-- service_fee             = biaya tambahan ke customer bila nanti digunakan
-- platform_fee_percent    = take rate Ayo Suruh (default 6%)
-- platform_fee_amount     = revenue kotor Ayo Suruh dari transaksi
-- mitra_net_amount        = hak pendapatan mitra setelah komisi platform
-- ---------------------------------------------------------------------------
alter table public.payments
  add column if not exists platform_fee_percent numeric(5,2),
  add column if not exists platform_fee_amount numeric,
  add column if not exists mitra_net_amount numeric;

alter table public.payment_attempts
  add column if not exists platform_fee_percent numeric(5,2),
  add column if not exists platform_fee_amount numeric,
  add column if not exists mitra_net_amount numeric;

create or replace function public.set_payment_economics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_percent numeric;
  v_gross numeric;
begin
  v_gross := greatest(coalesce(new.amount, 0), 0);

  if new.platform_fee_percent is not null then
    v_percent := new.platform_fee_percent;
  elsif tg_op = 'UPDATE' then
    v_percent := coalesce(old.platform_fee_percent, public.current_platform_fee_percent());
  else
    v_percent := public.current_platform_fee_percent();
  end if;

  v_percent := greatest(0, least(v_percent, 100));
  new.platform_fee_percent := v_percent;
  new.platform_fee_amount := round(v_gross * v_percent / 100.0);
  new.mitra_net_amount := greatest(v_gross - new.platform_fee_amount, 0);
  return new;
end;
$$;

drop trigger if exists trg_set_payment_economics on public.payments;
create trigger trg_set_payment_economics
before insert or update of amount, platform_fee_percent
on public.payments
for each row execute function public.set_payment_economics();

create or replace function public.set_payment_attempt_economics()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_percent numeric;
  v_parent_percent numeric;
  v_gross numeric;
begin
  select p.platform_fee_percent
    into v_parent_percent
  from public.payments p
  where p.id = new.payment_id;

  v_gross := greatest(coalesce(new.amount, 0), 0);

  if new.platform_fee_percent is not null then
    v_percent := new.platform_fee_percent;
  elsif tg_op = 'UPDATE' then
    v_percent := coalesce(
      old.platform_fee_percent,
      v_parent_percent,
      public.current_platform_fee_percent()
    );
  else
    v_percent := coalesce(v_parent_percent, public.current_platform_fee_percent());
  end if;

  v_percent := greatest(0, least(v_percent, 100));
  new.platform_fee_percent := v_percent;
  new.platform_fee_amount := round(v_gross * v_percent / 100.0);
  new.mitra_net_amount := greatest(v_gross - new.platform_fee_amount, 0);
  return new;
end;
$$;

drop trigger if exists trg_set_payment_attempt_economics
on public.payment_attempts;
create trigger trg_set_payment_attempt_economics
before insert or update of amount, platform_fee_percent, payment_id
on public.payment_attempts
for each row execute function public.set_payment_attempt_economics();

-- Backfill row lama dengan rate 6% sebagai snapshot awal. Bila transaksi lama
-- memang memakai rate berbeda, koreksi row tersebut secara manual sebelum launch.
update public.payments
set platform_fee_percent = coalesce(platform_fee_percent, 6.00)
where platform_fee_percent is null
   or platform_fee_amount is null
   or mitra_net_amount is null;

-- Memaksa trigger menghitung ulang fee/net untuk seluruh payment lama.
update public.payments
set amount = amount;

update public.payment_attempts pa
set platform_fee_percent = coalesce(
      pa.platform_fee_percent,
      p.platform_fee_percent,
      6.00
    )
from public.payments p
where p.id = pa.payment_id
  and (
    pa.platform_fee_percent is null
    or pa.platform_fee_amount is null
    or pa.mitra_net_amount is null
  );

update public.payment_attempts
set amount = amount;

-- Tidak memakai DEFAULT 6 pada kolom snapshot. BEFORE INSERT trigger akan
-- mengambil business_settings saat transaksi dibuat. Dengan begitu perubahan rate
-- di masa depan hanya berlaku untuk transaksi baru dan tidak mengubah histori.
alter table public.payments
  alter column platform_fee_percent drop default,
  alter column platform_fee_percent set not null,
  alter column platform_fee_amount set default 0,
  alter column platform_fee_amount set not null,
  alter column mitra_net_amount set default 0,
  alter column mitra_net_amount set not null;

alter table public.payment_attempts
  alter column platform_fee_percent drop default,
  alter column platform_fee_percent set not null,
  alter column platform_fee_amount set default 0,
  alter column platform_fee_amount set not null,
  alter column mitra_net_amount set default 0,
  alter column mitra_net_amount set not null;

-- ---------------------------------------------------------------------------
-- 3. Wallet mitra menerima NET earning, bukan seluruh GMV.
-- Kredit tetap hanya dibuat ketika payment paid + job completed.
-- ---------------------------------------------------------------------------
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
  v_gross_amount numeric;
  v_fee_percent numeric;
  v_fee_amount numeric;
  v_net_amount numeric;
begin
  select
    j.mitra_id,
    j.status,
    p.status,
    coalesce(p.amount, j.budget, 0),
    coalesce(p.platform_fee_percent, public.current_platform_fee_percent()),
    coalesce(
      p.platform_fee_amount,
      round(coalesce(p.amount, j.budget, 0) * public.current_platform_fee_percent() / 100.0)
    ),
    coalesce(
      p.mitra_net_amount,
      greatest(
        coalesce(p.amount, j.budget, 0) -
          round(coalesce(p.amount, j.budget, 0) * public.current_platform_fee_percent() / 100.0),
        0
      )
    )
  into
    v_mitra_id,
    v_job_status,
    v_payment_status,
    v_gross_amount,
    v_fee_percent,
    v_fee_amount,
    v_net_amount
  from public.jobs j
  join public.payments p on p.job_id = j.id
  where j.id = p_job_id;

  if not found
     or v_mitra_id is null
     or v_job_status <> 'completed'::public.job_status
     or v_payment_status <> 'paid'::public.payment_status
     or coalesce(v_net_amount, 0) <= 0 then
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
    description,
    raw_data
  ) values (
    v_mitra_id,
    p_job_id,
    v_net_amount,
    'pending',
    'job_earning',
    timezone('utc'::text, now()) + interval '1 day',
    'job:' || p_job_id::text || ':earning',
    'Pendapatan bersih pekerjaan setelah komisi platform ' ||
      trim(to_char(v_fee_percent, 'FM999990.00')) || '%. Menunggu masa hold 1 hari.',
    jsonb_build_object(
      'gross_amount', v_gross_amount,
      'platform_fee_percent', v_fee_percent,
      'platform_fee_amount', v_fee_amount,
      'mitra_net_amount', v_net_amount
    )
  )
  on conflict (reference_key) do nothing;
end;
$$;

revoke all on function public.sync_job_wallet_credit(uuid) from public;

-- Penting: ledger earning yang TELAH tercatat sebelum migration ini tidak
-- otomatis dipotong 6% agar histori keuangan tidak dimutasi diam-diam.
-- Untuk data sandbox/test, bersihkan/reseed ledger bila ingin menguji dari nol.

commit;
