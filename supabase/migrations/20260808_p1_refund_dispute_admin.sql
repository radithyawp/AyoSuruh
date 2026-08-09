-- Ayo Suruh P1 - Refund/dispute sederhana untuk Admin in-app.
-- Prasyarat:
--   1. 20260806_refund_wallet_payout.sql
--   2. 20260808_batch11_stability_admin.sql
--   3. migration notifikasi / enqueue_notification sudah aktif.
--
-- Migration ini TIDAK mengubah integrasi Midtrans dan TIDAK memproses uang.
-- Aksi "refunded" tetap hanya boleh dipakai admin setelah refund/cancel benar-benar
-- dikonfirmasi melalui dashboard Midtrans Sandbox/operasional yang berlaku.

begin;

-- ---------------------------------------------------------------------------
-- 1. Antrean refund untuk Admin in-app.
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_refunds(p_limit integer default 100)
returns table (
  refund_id uuid,
  job_id uuid,
  job_title text,
  customer_id uuid,
  customer_name text,
  customer_email text,
  mitra_id uuid,
  mitra_name text,
  amount numeric,
  reason text,
  refund_status text,
  status_message text,
  payment_status text,
  order_id text,
  transaction_status text,
  payment_type text,
  wallet_earning_amount numeric,
  wallet_bucket text,
  requested_at timestamp with time zone,
  processed_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    r.id as refund_id,
    r.job_id,
    j.title as job_title,
    r.customer_id,
    coalesce(nullif(trim(c.fullname), ''), c.email, 'Customer') as customer_name,
    c.email as customer_email,
    j.mitra_id,
    coalesce(nullif(trim(m.fullname), ''), m.email, '') as mitra_name,
    r.amount,
    r.reason,
    r.status as refund_status,
    r.status_message,
    p.status::text as payment_status,
    p.order_id,
    p.transaction_status,
    p.payment_type,
    coalesce(w.amount, 0)::numeric as wallet_earning_amount,
    w.bucket as wallet_bucket,
    r.requested_at,
    r.processed_at,
    r.created_at,
    r.updated_at
  from public.refund_requests r
  join public.jobs j on j.id = r.job_id
  join public.users c on c.id = r.customer_id
  left join public.users m on m.id = j.mitra_id
  join public.payments p on p.id = r.payment_id
  left join lateral (
    select l.amount, l.bucket
    from public.mitra_wallet_ledger l
    where l.job_id = r.job_id
      and l.entry_type = 'job_earning'
      and l.state = 'posted'
    order by l.created_at asc
    limit 1
  ) w on true
  order by
    case
      when r.status = 'manual_review' then 0
      when r.status = 'failed' then 1
      when r.status = 'processing' then 2
      else 3
    end,
    r.requested_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 200));
end;
$$;

revoke all on function public.admin_list_refunds(integer) from public;
grant execute on function public.admin_list_refunds(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Wrapper aman untuk process_manual_refund dari aplikasi Admin.
--    Fungsi lama tetap tidak diberikan langsung ke authenticated.
-- ---------------------------------------------------------------------------
create or replace function public.admin_process_refund(
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
  v_action text := lower(trim(coalesce(p_action, '')));
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  if v_action not in ('refunded', 'reject') then
    raise exception 'Action refund admin harus refunded atau reject.';
  end if;

  perform public.process_manual_refund(
    p_refund_id,
    v_action,
    nullif(trim(coalesce(p_note, '')), '')
  );
end;
$$;

revoke all on function public.admin_process_refund(uuid, text, text) from public;
grant execute on function public.admin_process_refund(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Push/in-app notification ke semua admin aktif ketika refund membutuhkan
--    tindakan manual. Tidak mengirim notifikasi untuk refund otomatis sukses.
-- ---------------------------------------------------------------------------
create or replace function public.notify_admin_refund_review()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
  v_job_title text := 'pekerjaan';
  v_customer_name text := 'Customer';
  v_title text;
  v_body text;
begin
  if new.status not in ('manual_review', 'failed') then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  select
    coalesce(nullif(trim(j.title), ''), 'pekerjaan'),
    coalesce(nullif(trim(u.fullname), ''), u.email, 'Customer')
  into v_job_title, v_customer_name
  from public.jobs j
  join public.users u on u.id = new.customer_id
  where j.id = new.job_id;

  if new.status = 'failed' then
    v_title := 'Refund Gagal - Perlu Tindakan';
    v_body := v_customer_name || ' memiliki refund yang gagal diproses otomatis untuk "' ||
      v_job_title || '". Buka menu Operasi > Refund.';
  else
    v_title := 'Refund Perlu Ditinjau';
    v_body := v_customer_name || ' mengajukan refund manual untuk "' ||
      v_job_title || '". Buka menu Operasi > Refund.';
  end if;

  for v_admin in
    select a.user_id
    from public.admin_users a
    where a.is_active = true
  loop
    perform public.enqueue_notification(
      p_user_id => v_admin.user_id,
      p_title => v_title,
      p_body => v_body,
      p_type => 'admin_refund_review',
      p_job_id => new.job_id,
      p_data => jsonb_build_object(
        'refund_id', new.id,
        'refund_status', new.status
      )
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_admin_refund_review on public.refund_requests;
create trigger trg_notify_admin_refund_review
after insert or update of status on public.refund_requests
for each row execute function public.notify_admin_refund_review();

commit;
