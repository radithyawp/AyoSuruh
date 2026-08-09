-- AYO SURUH - P1 ADMIN ACTION NOTIFICATIONS
-- Notifikasi admin untuk event yang membutuhkan tindakan operasional.
-- Scope: pengajuan Mitra baru/resubmit dan permintaan pencairan baru.

begin;

-- -----------------------------------------------------------------------------
-- 1. Helper internal: kirim satu notifikasi ke seluruh admin aktif.
-- -----------------------------------------------------------------------------
create or replace function public.enqueue_admin_notification(
  p_title text,
  p_body text,
  p_type text,
  p_actor_id uuid default null,
  p_data jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
  v_sent integer := 0;
begin
  for v_admin in
    select a.user_id
    from public.admin_users a
    where a.is_active = true
  loop
    perform public.enqueue_notification(
      p_user_id => v_admin.user_id,
      p_title => p_title,
      p_body => p_body,
      p_type => p_type,
      p_actor_id => p_actor_id,
      p_data => coalesce(p_data, '{}'::jsonb)
    );

    v_sent := v_sent + 1;
  end loop;

  return v_sent;
end;
$$;

revoke all on function public.enqueue_admin_notification(
  text, text, text, uuid, jsonb
) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2. Pengajuan Mitra baru / pengajuan ulang setelah sebelumnya ditolak.
-- -----------------------------------------------------------------------------
create or replace function public.notify_admin_mitra_application_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if new.status <> 'applied'::public.application_status then
    return new;
  end if;

  -- UPDATE applied -> applied tidak perlu menghasilkan notifikasi ganda.
  if tg_op = 'UPDATE' then
    if old.status is not distinct from new.status then
      return new;
    end if;
  end if;

  select coalesce(nullif(trim(u.fullname), ''), nullif(trim(u.email), ''), 'Pengguna')
  into v_name
  from public.users u
  where u.id = new.user_id;

  perform public.enqueue_admin_notification(
    p_title => 'Pengajuan Mitra Baru',
    p_body => coalesce(v_name, 'Pengguna') || ' mengajukan verifikasi Mitra. Buka menu Mitra untuk meninjau dokumen.',
    p_type => 'admin_mitra_application_new',
    p_actor_id => new.user_id,
    p_data => jsonb_build_object(
      'application_id', new.id,
      'user_id', new.user_id,
      'admin_target', 'mitra_verification'
    )
  );

  return new;
end;
$$;

revoke all on function public.notify_admin_mitra_application_event()
  from public, anon, authenticated;

drop trigger if exists trg_notify_admin_mitra_application
  on public.mitra_applications;
create trigger trg_notify_admin_mitra_application
after insert or update of status on public.mitra_applications
for each row execute function public.notify_admin_mitra_application_event();

-- -----------------------------------------------------------------------------
-- 3. Permintaan pencairan saldo Mitra baru.
-- -----------------------------------------------------------------------------
create or replace function public.notify_admin_payout_request_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  if new.status <> 'requested' then
    return new;
  end if;

  select coalesce(nullif(trim(u.fullname), ''), nullif(trim(u.email), ''), 'Mitra')
  into v_name
  from public.users u
  where u.id = new.mitra_id;

  perform public.enqueue_admin_notification(
    p_title => 'Permintaan Pencairan Baru',
    p_body => coalesce(v_name, 'Mitra') || ' mengajukan pencairan Rp' ||
      trim(to_char(new.amount, 'FM999999999999990')) || '. Buka menu Mitra untuk memprosesnya.',
    p_type => 'admin_payout_requested',
    p_actor_id => new.mitra_id,
    p_data => jsonb_build_object(
      'payout_request_id', new.id,
      'mitra_id', new.mitra_id,
      'amount', new.amount,
      'admin_target', 'payout_review'
    )
  );

  return new;
end;
$$;

revoke all on function public.notify_admin_payout_request_event()
  from public, anon, authenticated;

drop trigger if exists trg_notify_admin_payout_request
  on public.payout_requests;
create trigger trg_notify_admin_payout_request
after insert on public.payout_requests
for each row execute function public.notify_admin_payout_request_event();

commit;
