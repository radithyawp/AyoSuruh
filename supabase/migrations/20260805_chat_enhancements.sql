-- =============================================================================
-- AYO SURUH - CHAT ENHANCEMENTS
-- Urutan pesan, status Terkirim/Sampai/Dibaca, dan lampiran foto.
-- Jalankan setelah migration fitur chat sebelumnya.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Metadata status pesan dan lampiran
-- -----------------------------------------------------------------------------
alter table public.messages
  add column if not exists delivered_at timestamp with time zone,
  add column if not exists read_at timestamp with time zone,
  add column if not exists attachment_url text,
  add column if not exists attachment_name text,
  add column if not exists attachment_mime_type text,
  add column if not exists attachment_size bigint;

-- Pesan lama setidaknya dianggap sudah sampai. Status dibaca akan diperbarui
-- saat penerima membuka room chat.
update public.messages
set delivered_at = coalesce(delivered_at, created_at)
where delivered_at is null;

create index if not exists messages_room_created_at_idx
  on public.messages (room_id, created_at, id);

create index if not exists messages_room_unread_idx
  on public.messages (room_id, sender_id, read_at)
  where read_at is null;

-- -----------------------------------------------------------------------------
-- 2. Tandai pesan "Sampai" ketika penerima membuka daftar chat
-- -----------------------------------------------------------------------------
create or replace function public.mark_my_chat_messages_delivered()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  update public.messages m
  set delivered_at = timezone('utc'::text, now())
  from public.chat_rooms cr
  where cr.id = m.room_id
    and auth.uid() in (cr.customer_id, cr.mitra_id)
    and m.sender_id <> auth.uid()
    and m.delivered_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Tandai pesan "Dibaca" ketika penerima membuka percakapan
-- -----------------------------------------------------------------------------
create or replace function public.mark_chat_messages_read(p_room_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1
    from public.chat_rooms cr
    where cr.id = p_room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  ) then
    raise exception 'Kamu tidak memiliki akses ke percakapan ini.';
  end if;

  update public.messages
  set delivered_at = coalesce(delivered_at, timezone('utc'::text, now())),
      read_at = timezone('utc'::text, now())
  where room_id = p_room_id
    and sender_id <> auth.uid()
    and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. RPC kirim foto. Enum message_type tetap menggunakan text agar migration
--    kompatibel dengan enum database yang sekarang sudah tersedia.
-- -----------------------------------------------------------------------------
create or replace function public.send_chat_attachment(
  p_room_id uuid,
  p_attachment_url text,
  p_attachment_name text default null,
  p_attachment_mime_type text default 'image/jpeg',
  p_attachment_size bigint default null,
  p_caption text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_message_id uuid;
  v_url text;
  v_caption text;
  v_mime text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1
    from public.chat_rooms cr
    where cr.id = p_room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  ) then
    raise exception 'Kamu tidak memiliki akses ke percakapan ini.';
  end if;

  v_url := trim(coalesce(p_attachment_url, ''));
  v_caption := trim(coalesce(p_caption, ''));
  v_mime := lower(trim(coalesce(p_attachment_mime_type, 'image/jpeg')));

  if v_url = '' then
    raise exception 'URL lampiran tidak boleh kosong.';
  end if;

  if v_mime not in (
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ) then
    raise exception 'Format foto tidak didukung.';
  end if;

  if p_attachment_size is not null and p_attachment_size > 8388608 then
    raise exception 'Ukuran foto maksimal 8 MB.';
  end if;

  if char_length(v_caption) > 500 then
    raise exception 'Keterangan foto maksimal 500 karakter.';
  end if;

  insert into public.messages (
    room_id,
    sender_id,
    message,
    type,
    attachment_url,
    attachment_name,
    attachment_mime_type,
    attachment_size
  ) values (
    p_room_id,
    auth.uid(),
    case when v_caption = '' then 'Foto' else v_caption end,
    'text'::public.message_type,
    v_url,
    nullif(trim(coalesce(p_attachment_name, '')), ''),
    v_mime,
    p_attachment_size
  )
  returning id into v_message_id;

  return v_message_id;
end;
$$;

revoke all on function public.mark_my_chat_messages_delivered() from public;
revoke all on function public.mark_chat_messages_read(uuid) from public;
revoke all on function public.send_chat_attachment(
  uuid,
  text,
  text,
  text,
  bigint,
  text
) from public;

grant execute on function public.mark_my_chat_messages_delivered()
  to authenticated;
grant execute on function public.mark_chat_messages_read(uuid)
  to authenticated;
grant execute on function public.send_chat_attachment(
  uuid,
  text,
  text,
  text,
  bigint,
  text
) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Supabase Storage untuk foto chat
-- -----------------------------------------------------------------------------
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'chat-attachments',
  'chat-attachments',
  true,
  8388608,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "ayo_chat_attachments_read" on storage.objects;
create policy "ayo_chat_attachments_read"
on storage.objects for select
to authenticated
using (bucket_id = 'chat-attachments');

drop policy if exists "ayo_chat_attachments_insert_own" on storage.objects;
create policy "ayo_chat_attachments_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_chat_attachments_update_own" on storage.objects;
create policy "ayo_chat_attachments_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "ayo_chat_attachments_delete_own" on storage.objects;
create policy "ayo_chat_attachments_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'chat-attachments'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
