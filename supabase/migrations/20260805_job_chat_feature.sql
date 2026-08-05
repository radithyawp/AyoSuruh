-- Ayo Suruh - Chat customer dan mitra per pekerjaan
-- Jalankan setelah migration job bidding/progress/review.

-- ---------------------------------------------------------------------------
-- 1. Struktur dan indeks
-- ---------------------------------------------------------------------------
alter table public.chat_rooms
  add column if not exists updated_at timestamp with time zone
  not null default timezone('utc'::text, now());

create index if not exists chat_rooms_customer_id_idx
  on public.chat_rooms (customer_id);

create index if not exists chat_rooms_mitra_id_idx
  on public.chat_rooms (mitra_id);

create index if not exists chat_rooms_updated_at_idx
  on public.chat_rooms (updated_at desc);

create index if not exists messages_room_created_idx
  on public.messages (room_id, created_at);

-- Satukan room duplikat jika migration pernah dijalankan pada data uji.
with ranked_rooms as (
  select
    id,
    job_id,
    first_value(id) over (
      partition by job_id
      order by created_at, id
    ) as keeper_id,
    row_number() over (
      partition by job_id
      order by created_at, id
    ) as room_number
  from public.chat_rooms
), duplicate_rooms as (
  select id as duplicate_id, keeper_id
  from ranked_rooms
  where room_number > 1
)
update public.messages m
set room_id = d.keeper_id
from duplicate_rooms d
where m.room_id = d.duplicate_id;

with ranked_rooms as (
  select
    id,
    row_number() over (
      partition by job_id
      order by created_at, id
    ) as room_number
  from public.chat_rooms
)
delete from public.chat_rooms cr
using ranked_rooms r
where cr.id = r.id
  and r.room_number > 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chat_rooms_job_unique'
      and conrelid = 'public.chat_rooms'::regclass
  ) then
    alter table public.chat_rooms
      add constraint chat_rooms_job_unique unique (job_id);
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- 2. Room otomatis saat mitra dipilih
-- ---------------------------------------------------------------------------
create or replace function public.ensure_job_chat_room()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.mitra_id is not null
     and new.status in (
       'accepted'::public.job_status,
       'on_progress'::public.job_status,
       'completed'::public.job_status,
       'cancelled'::public.job_status
     ) then
    insert into public.chat_rooms (
      job_id,
      customer_id,
      mitra_id,
      updated_at
    ) values (
      new.id,
      new.customer_id,
      new.mitra_id,
      timezone('utc'::text, now())
    )
    on conflict (job_id)
    do update set
      customer_id = excluded.customer_id,
      mitra_id = excluded.mitra_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_ensure_job_chat_room on public.jobs;
create trigger trg_ensure_job_chat_room
after insert or update of mitra_id, status
on public.jobs
for each row
execute function public.ensure_job_chat_room();

-- Backfill room untuk pekerjaan yang sudah mempunyai mitra.
insert into public.chat_rooms (
  job_id,
  customer_id,
  mitra_id,
  updated_at
)
select
  j.id,
  j.customer_id,
  j.mitra_id,
  coalesce(j.created_at, timezone('utc'::text, now()))
from public.jobs j
where j.mitra_id is not null
  and j.status in (
    'accepted'::public.job_status,
    'on_progress'::public.job_status,
    'completed'::public.job_status,
    'cancelled'::public.job_status
  )
on conflict (job_id)
do update set
  customer_id = excluded.customer_id,
  mitra_id = excluded.mitra_id;

-- Waktu room mengikuti pesan terbaru.
create or replace function public.touch_chat_room_after_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
  set updated_at = new.created_at
  where id = new.room_id;
  return new;
end;
$$;

drop trigger if exists trg_touch_chat_room_after_message
on public.messages;
create trigger trg_touch_chat_room_after_message
after insert on public.messages
for each row
execute function public.touch_chat_room_after_message();

-- ---------------------------------------------------------------------------
-- 3. RPC aman untuk room, daftar chat, dan pesan
-- ---------------------------------------------------------------------------
create or replace function public.get_or_create_job_chat_room(p_job_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid;
  v_mitra_id uuid;
  v_room_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select j.customer_id, j.mitra_id
  into v_customer_id, v_mitra_id
  from public.jobs j
  where j.id = p_job_id;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan.';
  end if;

  if v_mitra_id is null then
    raise exception 'Chat tersedia setelah customer memilih mitra.';
  end if;

  if auth.uid() <> v_customer_id and auth.uid() <> v_mitra_id then
    raise exception 'Kamu bukan peserta pekerjaan ini.';
  end if;

  insert into public.chat_rooms (
    job_id,
    customer_id,
    mitra_id,
    updated_at
  ) values (
    p_job_id,
    v_customer_id,
    v_mitra_id,
    timezone('utc'::text, now())
  )
  on conflict (job_id)
  do update set
    customer_id = excluded.customer_id,
    mitra_id = excluded.mitra_id
  returning id into v_room_id;

  return v_room_id;
end;
$$;

create or replace function public.get_my_chat_rooms()
returns table (
  room_id uuid,
  job_id uuid,
  job_title text,
  job_status text,
  partner_id uuid,
  partner_name text,
  partner_avatar_url text,
  last_message text,
  last_message_at timestamp with time zone,
  updated_at timestamp with time zone
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cr.id as room_id,
    cr.job_id,
    j.title as job_title,
    j.status::text as job_status,
    case
      when auth.uid() = cr.customer_id then cr.mitra_id
      else cr.customer_id
    end as partner_id,
    coalesce(
      nullif(trim(partner.fullname), ''),
      case
        when auth.uid() = cr.customer_id then 'Mitra Ayo Suruh'
        else 'Customer Ayo Suruh'
      end
    ) as partner_name,
    partner.avatar_url as partner_avatar_url,
    latest.message as last_message,
    latest.created_at as last_message_at,
    cr.updated_at
  from public.chat_rooms cr
  join public.jobs j
    on j.id = cr.job_id
  join public.users partner
    on partner.id = case
      when auth.uid() = cr.customer_id then cr.mitra_id
      else cr.customer_id
    end
  left join lateral (
    select m.message, m.created_at
    from public.messages m
    where m.room_id = cr.id
    order by m.created_at desc
    limit 1
  ) latest on true
  where auth.uid() is not null
    and auth.uid() in (cr.customer_id, cr.mitra_id)
  order by coalesce(latest.created_at, cr.updated_at) desc;
$$;

create or replace function public.get_chat_room_header(p_room_id uuid)
returns table (
  room_id uuid,
  job_id uuid,
  job_title text,
  job_status text,
  partner_id uuid,
  partner_name text,
  partner_avatar_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    cr.id as room_id,
    cr.job_id,
    j.title as job_title,
    j.status::text as job_status,
    case
      when auth.uid() = cr.customer_id then cr.mitra_id
      else cr.customer_id
    end as partner_id,
    coalesce(
      nullif(trim(partner.fullname), ''),
      case
        when auth.uid() = cr.customer_id then 'Mitra Ayo Suruh'
        else 'Customer Ayo Suruh'
      end
    ) as partner_name,
    partner.avatar_url as partner_avatar_url
  from public.chat_rooms cr
  join public.jobs j
    on j.id = cr.job_id
  join public.users partner
    on partner.id = case
      when auth.uid() = cr.customer_id then cr.mitra_id
      else cr.customer_id
    end
  where cr.id = p_room_id
    and auth.uid() is not null
    and auth.uid() in (cr.customer_id, cr.mitra_id);
$$;

create or replace function public.send_chat_message(
  p_room_id uuid,
  p_message text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message text;
  v_message_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  v_message := trim(coalesce(p_message, ''));

  if v_message = '' then
    raise exception 'Pesan tidak boleh kosong.';
  end if;

  if char_length(v_message) > 2000 then
    raise exception 'Pesan maksimal 2000 karakter.';
  end if;

  if not exists (
    select 1
    from public.chat_rooms cr
    where cr.id = p_room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  ) then
    raise exception 'Kamu tidak memiliki akses ke percakapan ini.';
  end if;

  insert into public.messages (
    room_id,
    sender_id,
    message,
    type
  ) values (
    p_room_id,
    auth.uid(),
    v_message,
    'text'::public.message_type
  )
  returning id into v_message_id;

  return v_message_id;
end;
$$;

revoke all on function public.get_or_create_job_chat_room(uuid) from public;
revoke all on function public.get_my_chat_rooms() from public;
revoke all on function public.get_chat_room_header(uuid) from public;
revoke all on function public.send_chat_message(uuid, text) from public;

grant execute on function public.get_or_create_job_chat_room(uuid) to authenticated;
grant execute on function public.get_my_chat_rooms() to authenticated;
grant execute on function public.get_chat_room_header(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Row Level Security
-- ---------------------------------------------------------------------------
alter table public.chat_rooms enable row level security;
alter table public.messages enable row level security;

grant select on table public.chat_rooms to authenticated;
grant select on table public.messages to authenticated;

drop policy if exists "chat participants can read rooms" on public.chat_rooms;
create policy "chat participants can read rooms"
on public.chat_rooms
for select
to authenticated
using (auth.uid() in (customer_id, mitra_id));

drop policy if exists "chat participants can read messages" on public.messages;
create policy "chat participants can read messages"
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.chat_rooms cr
    where cr.id = room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  )
);

-- Penulisan pesan melalui RPC send_chat_message agar sender_id tidak dapat dipalsukan.
drop policy if exists "chat participants can insert messages" on public.messages;

-- Aktifkan realtime untuk pesan bila belum masuk publication Supabase.
do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    execute 'alter publication supabase_realtime add table public.messages';
  end if;
end
$$;
