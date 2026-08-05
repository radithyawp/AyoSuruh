-- AYO SURUH - IN-APP NOTIFICATION FEATURE
-- Jalankan setelah seluruh migration job, progress, review, dan chat.

begin;

-- -----------------------------------------------------------------------------
-- 1. Tambahan tujuan navigasi notifikasi
-- -----------------------------------------------------------------------------
alter table public.notifications
  add column if not exists job_id uuid references public.jobs(id) on delete cascade,
  add column if not exists room_id uuid references public.chat_rooms(id) on delete cascade,
  add column if not exists actor_id uuid references public.users(id) on delete set null,
  add column if not exists data jsonb not null default '{}'::jsonb;

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id, is_read, created_at desc);

create index if not exists notifications_room_idx
  on public.notifications (room_id)
  where room_id is not null;

create index if not exists notifications_job_idx
  on public.notifications (job_id)
  where job_id is not null;

-- -----------------------------------------------------------------------------
-- 2. Row Level Security: user hanya melihat dan mengubah notifikasinya sendiri
-- -----------------------------------------------------------------------------
alter table public.notifications enable row level security;

drop policy if exists "ayo_notifications_read_own" on public.notifications;
create policy "ayo_notifications_read_own"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "ayo_notifications_update_own" on public.notifications;
create policy "ayo_notifications_update_own"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "ayo_notifications_delete_own" on public.notifications;
create policy "ayo_notifications_delete_own"
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());

grant select, update, delete on public.notifications to authenticated;

-- -----------------------------------------------------------------------------
-- 3. Helper internal pembuat notifikasi
-- -----------------------------------------------------------------------------
create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text default null,
  p_job_id uuid default null,
  p_room_id uuid default null,
  p_actor_id uuid default null,
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_notification_id uuid;
begin
  if p_user_id is null then
    return null;
  end if;

  insert into public.notifications (
    user_id,
    title,
    body,
    type,
    job_id,
    room_id,
    actor_id,
    data,
    is_read
  ) values (
    p_user_id,
    left(coalesce(nullif(trim(p_title), ''), 'Notifikasi'), 120),
    left(coalesce(trim(p_body), ''), 500),
    nullif(trim(coalesce(p_type, '')), ''),
    p_job_id,
    p_room_id,
    p_actor_id,
    coalesce(p_data, '{}'::jsonb),
    false
  )
  returning id into v_notification_id;

  return v_notification_id;
end;
$$;

revoke all on function public.enqueue_notification(
  uuid, text, text, text, uuid, uuid, uuid, jsonb
) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 4. Notifikasi penawaran baru, diterima, dan ditolak
-- -----------------------------------------------------------------------------
create or replace function public.notify_bid_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_job_title text;
  v_mitra_name text;
begin
  select
    j.customer_id,
    j.title,
    coalesce(nullif(trim(u.fullname), ''), 'Seorang mitra')
  into v_customer_id, v_job_title, v_mitra_name
  from public.jobs j
  left join public.users u on u.id = new.mitra_id
  where j.id = new.job_id;

  if tg_op = 'INSERT' then
    perform public.enqueue_notification(
      v_customer_id,
      'Penawaran Baru',
      format('%s mengajukan penawaran untuk pekerjaan "%s".', v_mitra_name, v_job_title),
      'bid_new',
      new.job_id,
      null,
      new.mitra_id,
      jsonb_build_object('bid_id', new.id, 'price', new.price)
    );
  elsif tg_op = 'UPDATE' and old.status is distinct from new.status then
    if new.status::text = 'accepted' then
      perform public.enqueue_notification(
        new.mitra_id,
        'Penawaran Diterima',
        format('Penawaranmu untuk pekerjaan "%s" telah diterima customer.', v_job_title),
        'bid_accepted',
        new.job_id,
        null,
        v_customer_id,
        jsonb_build_object('bid_id', new.id, 'price', new.price)
      );
    elsif new.status::text = 'rejected' then
      perform public.enqueue_notification(
        new.mitra_id,
        'Penawaran Belum Dipilih',
        format('Penawaranmu untuk pekerjaan "%s" belum dipilih customer.', v_job_title),
        'bid_rejected',
        new.job_id,
        null,
        v_customer_id,
        jsonb_build_object('bid_id', new.id)
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_bid_event on public.bids;
create trigger trg_notify_bid_event
after insert or update of status on public.bids
for each row execute function public.notify_bid_event();

-- -----------------------------------------------------------------------------
-- 5. Notifikasi perubahan progres dan penyelesaian pekerjaan
-- -----------------------------------------------------------------------------
create or replace function public.notify_job_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_body text;
  v_progress_title text;
begin
  v_title := coalesce(new.title, 'Pekerjaan');

  if old.progress_stage is distinct from new.progress_stage
     and new.progress_stage is not null then
    case new.progress_stage::text
      when 'heading_to_location' then
        v_progress_title := 'Mitra Menuju Lokasi';
        v_body := format('Mitra sedang menuju lokasi pekerjaan "%s".', v_title);
      when 'arrived' then
        v_progress_title := 'Mitra Tiba di Lokasi';
        v_body := format('Mitra sudah tiba untuk mengerjakan "%s".', v_title);
      when 'working' then
        v_progress_title := 'Pekerjaan Dimulai';
        v_body := format('Mitra mulai mengerjakan "%s".', v_title);
      when 'completion_submitted' then
        v_progress_title := 'Menunggu Konfirmasi Selesai';
        v_body := format('Mitra menyatakan pekerjaan "%s" selesai. Periksa hasil pekerjaannya.', v_title);
      else
        v_progress_title := null;
        v_body := null;
    end case;

    if v_progress_title is not null then
      perform public.enqueue_notification(
        new.customer_id,
        v_progress_title,
        v_body,
        'job_progress',
        new.id,
        null,
        new.mitra_id,
        jsonb_build_object('progress_stage', new.progress_stage::text)
      );
    end if;
  end if;

  if old.status is distinct from new.status then
    if new.status::text = 'completed' and new.mitra_id is not null then
      perform public.enqueue_notification(
        new.mitra_id,
        'Pekerjaan Dikonfirmasi Selesai',
        format('Customer telah mengonfirmasi pekerjaan "%s" selesai.', v_title),
        'job_completed',
        new.id,
        null,
        new.customer_id,
        '{}'::jsonb
      );
    elsif new.status::text = 'cancelled' and new.mitra_id is not null then
      perform public.enqueue_notification(
        new.mitra_id,
        'Pekerjaan Dibatalkan',
        format('Pekerjaan "%s" telah dibatalkan oleh customer.', v_title),
        'job_cancelled',
        new.id,
        null,
        new.customer_id,
        '{}'::jsonb
      );
    elsif new.status::text = 'on_progress'
          and new.progress_stage is null then
      perform public.enqueue_notification(
        new.customer_id,
        'Pekerjaan Dimulai',
        format('Mitra mulai menangani pekerjaan "%s".', v_title),
        'job_progress',
        new.id,
        null,
        new.mitra_id,
        '{}'::jsonb
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notify_job_event on public.jobs;
create trigger trg_notify_job_event
after update of status, progress_stage on public.jobs
for each row execute function public.notify_job_event();

-- -----------------------------------------------------------------------------
-- 6. Notifikasi pesan chat baru
-- -----------------------------------------------------------------------------
create or replace function public.notify_chat_message_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_mitra_id uuid;
  v_job_id uuid;
  v_job_title text;
  v_recipient_id uuid;
  v_sender_name text;
  v_preview text;
begin
  select
    cr.customer_id,
    cr.mitra_id,
    cr.job_id,
    j.title
  into v_customer_id, v_mitra_id, v_job_id, v_job_title
  from public.chat_rooms cr
  join public.jobs j on j.id = cr.job_id
  where cr.id = new.room_id;

  if new.sender_id = v_customer_id then
    v_recipient_id := v_mitra_id;
  else
    v_recipient_id := v_customer_id;
  end if;

  if v_recipient_id is null or v_recipient_id = new.sender_id then
    return new;
  end if;

  select coalesce(nullif(trim(u.fullname), ''), 'Pengguna Ayo Suruh')
  into v_sender_name
  from public.users u
  where u.id = new.sender_id;

  if new.attachment_url is not null then
    v_preview := case
      when coalesce(trim(new.message), '') in ('', 'Foto')
        then format('%s mengirim sebuah foto.', v_sender_name)
      else format('%s mengirim foto: %s', v_sender_name, left(new.message, 90))
    end;
  else
    v_preview := format('%s: %s', v_sender_name, left(coalesce(new.message, ''), 100));
  end if;

  perform public.enqueue_notification(
    v_recipient_id,
    format('Pesan Baru dari %s', v_sender_name),
    v_preview,
    'chat_message',
    v_job_id,
    new.room_id,
    new.sender_id,
    jsonb_build_object('message_id', new.id, 'job_title', v_job_title)
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_chat_message_event on public.messages;
create trigger trg_notify_chat_message_event
after insert on public.messages
for each row execute function public.notify_chat_message_event();

-- -----------------------------------------------------------------------------
-- 7. Notifikasi rating baru untuk mitra
-- -----------------------------------------------------------------------------
create or replace function public.notify_review_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_job_title text;
  v_customer_name text;
begin
  select
    j.title,
    coalesce(nullif(trim(u.fullname), ''), 'Customer')
  into v_job_title, v_customer_name
  from public.jobs j
  left join public.users u on u.id = new.customer_id
  where j.id = new.job_id;

  perform public.enqueue_notification(
    new.mitra_id,
    'Penilaian Baru',
    format('%s memberikan rating %s/5 untuk pekerjaan "%s".', v_customer_name, new.rating, v_job_title),
    'review_received',
    new.job_id,
    null,
    new.customer_id,
    jsonb_build_object('review_id', new.id, 'rating', new.rating)
  );

  return new;
end;
$$;

drop trigger if exists trg_notify_review_event on public.reviews;
create trigger trg_notify_review_event
after insert on public.reviews
for each row execute function public.notify_review_event();

-- -----------------------------------------------------------------------------
-- 8. RPC status baca berdasarkan room/job
-- -----------------------------------------------------------------------------
create or replace function public.mark_room_notifications_read(p_room_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  update public.notifications
  set is_read = true
  where user_id = auth.uid()
    and room_id = p_room_id
    and is_read = false;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.mark_job_notifications_read(p_job_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  update public.notifications
  set is_read = true
  where user_id = auth.uid()
    and job_id = p_job_id
    and is_read = false;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_room_notifications_read(uuid) from public;
revoke all on function public.mark_job_notifications_read(uuid) from public;
grant execute on function public.mark_room_notifications_read(uuid) to authenticated;
grant execute on function public.mark_job_notifications_read(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 9. Aktifkan Realtime untuk tabel notifications bila belum aktif
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end;
$$;

commit;
