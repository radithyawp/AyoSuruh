-- Ayo Suruh - P1 Admin Operational Monitor
-- Adds read-only operational monitoring for jobs and payments inside the Flutter admin.
-- Run after 20260808_batch11_stability_admin.sql.

begin;

create or replace function public.admin_operational_summary()
returns table (
  active_jobs bigint,
  waiting_jobs bigint,
  in_progress_jobs bigint,
  pending_payments bigint,
  paid_payments bigint,
  refunded_payments bigint,
  cancelled_payments bigint,
  pending_payouts bigint
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
    (
      select count(*)
      from public.jobs j
      where j.status::text in ('posted', 'waiting_bid', 'accepted', 'on_progress')
    )::bigint,
    (
      select count(*)
      from public.jobs j
      where j.status::text in ('posted', 'waiting_bid')
    )::bigint,
    (
      select count(*)
      from public.jobs j
      where j.status::text = 'on_progress'
    )::bigint,
    (
      select count(*)
      from public.payments p
      where p.status::text = 'pending'
    )::bigint,
    (
      select count(*)
      from public.payments p
      where p.status::text = 'paid'
    )::bigint,
    (
      select count(*)
      from public.payments p
      where p.status::text = 'refunded'
    )::bigint,
    (
      select count(*)
      from public.payments p
      where p.status::text = 'cancelled'
    )::bigint,
    (
      select count(*)
      from public.payout_requests pr
      where pr.status in ('requested', 'under_review', 'approved', 'processing')
    )::bigint;
end;
$$;

revoke all on function public.admin_operational_summary() from public;
grant execute on function public.admin_operational_summary() to authenticated;

create or replace function public.admin_list_jobs(p_limit integer default 100)
returns table (
  job_id uuid,
  title text,
  status text,
  progress_stage text,
  budget numeric,
  customer_id uuid,
  customer_name text,
  mitra_id uuid,
  mitra_name text,
  preferred_mitra_id uuid,
  created_at timestamp with time zone,
  schedule_date date,
  schedule_time time without time zone,
  bid_count bigint,
  payment_status text
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
    j.id,
    j.title,
    j.status::text,
    j.progress_stage::text,
    j.budget,
    j.customer_id,
    coalesce(nullif(trim(customer.fullname), ''), customer.email, 'Customer Ayo Suruh'),
    j.mitra_id,
    case
      when j.mitra_id is null then null
      else coalesce(nullif(trim(mitra.fullname), ''), mitra.email, 'Mitra Ayo Suruh')
    end,
    j.preferred_mitra_id,
    j.created_at,
    j.schedule_date,
    j.schedule_time,
    coalesce(bids.total, 0)::bigint,
    payment.status::text
  from public.jobs j
  join public.users customer on customer.id = j.customer_id
  left join public.users mitra on mitra.id = j.mitra_id
  left join lateral (
    select count(*)::bigint as total
    from public.bids b
    where b.job_id = j.id
  ) bids on true
  left join public.payments payment on payment.job_id = j.id
  order by
    case
      when j.status::text in ('posted', 'waiting_bid', 'accepted', 'on_progress') then 0
      else 1
    end,
    j.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
end;
$$;

revoke all on function public.admin_list_jobs(integer) from public;
grant execute on function public.admin_list_jobs(integer) to authenticated;

create or replace function public.admin_list_payments(p_limit integer default 100)
returns table (
  payment_id uuid,
  job_id uuid,
  job_title text,
  customer_name text,
  mitra_name text,
  amount numeric,
  platform_fee_amount numeric,
  mitra_net_amount numeric,
  status text,
  provider text,
  payment_required boolean,
  transaction_status text,
  payment_type text,
  order_id text,
  paid_at timestamp with time zone,
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
    p.id,
    p.job_id,
    j.title,
    coalesce(nullif(trim(customer.fullname), ''), customer.email, 'Customer Ayo Suruh'),
    case
      when j.mitra_id is null then null
      else coalesce(nullif(trim(mitra.fullname), ''), mitra.email, 'Mitra Ayo Suruh')
    end,
    p.amount,
    coalesce(p.platform_fee_amount, 0),
    coalesce(p.mitra_net_amount, 0),
    p.status::text,
    p.provider,
    p.payment_required,
    p.transaction_status,
    p.payment_type,
    p.order_id,
    p.paid_at,
    p.created_at,
    p.updated_at
  from public.payments p
  join public.jobs j on j.id = p.job_id
  join public.users customer on customer.id = j.customer_id
  left join public.users mitra on mitra.id = j.mitra_id
  order by
    case
      when p.status::text = 'pending' then 0
      else 1
    end,
    p.updated_at desc nulls last,
    p.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 300));
end;
$$;

revoke all on function public.admin_list_payments(integer) from public;
grant execute on function public.admin_list_payments(integer) to authenticated;

commit;
