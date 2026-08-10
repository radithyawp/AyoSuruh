-- Ayo Suruh - Chat presence + marketplace depth
-- Adds online/last-seen + typing indicators, service tags/bookmarks,
-- and safe public Mitra profile RPCs for the release marketplace.

begin;

-- ---------------------------------------------------------------------------
-- 1. Chat presence
-- ---------------------------------------------------------------------------
create table if not exists public.user_presence (
  user_id uuid primary key references public.users(id) on delete cascade,
  is_online boolean not null default false,
  last_seen timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

alter table public.user_presence enable row level security;
grant select, insert, update on public.user_presence to authenticated;

drop policy if exists "presence authenticated read" on public.user_presence;
create policy "presence authenticated read"
on public.user_presence for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.chat_rooms cr
    where auth.uid() in (cr.customer_id, cr.mitra_id)
      and user_presence.user_id in (cr.customer_id, cr.mitra_id)
  )
);

drop policy if exists "presence own insert" on public.user_presence;
create policy "presence own insert"
on public.user_presence for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "presence own update" on public.user_presence;
create policy "presence own update"
on public.user_presence for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 2. Typing state per room
-- ---------------------------------------------------------------------------
create table if not exists public.chat_typing (
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  is_typing boolean not null default false,
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  primary key (room_id, user_id)
);

create index if not exists chat_typing_room_updated_idx
  on public.chat_typing(room_id, updated_at desc);

alter table public.chat_typing enable row level security;
grant select, insert, update, delete on public.chat_typing to authenticated;

drop policy if exists "chat participants read typing" on public.chat_typing;
create policy "chat participants read typing"
on public.chat_typing for select
to authenticated
using (
  exists (
    select 1 from public.chat_rooms cr
    where cr.id = chat_typing.room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  )
);

drop policy if exists "chat participants write own typing" on public.chat_typing;
create policy "chat participants write own typing"
on public.chat_typing for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.chat_rooms cr
    where cr.id = chat_typing.room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  )
);

drop policy if exists "chat participants update own typing" on public.chat_typing;
create policy "chat participants update own typing"
on public.chat_typing for update
to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1 from public.chat_rooms cr
    where cr.id = chat_typing.room_id
      and auth.uid() in (cr.customer_id, cr.mitra_id)
  )
)
with check (user_id = auth.uid());

drop policy if exists "chat participants delete own typing" on public.chat_typing;
create policy "chat participants delete own typing"
on public.chat_typing for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 3. Marketplace tags + bookmarks
-- ---------------------------------------------------------------------------
alter table public.mitra_services
  add column if not exists tags text[] not null default '{}'::text[];

create table if not exists public.mitra_service_bookmarks (
  user_id uuid not null references public.users(id) on delete cascade,
  service_id uuid not null references public.mitra_services(id) on delete cascade,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  primary key (user_id, service_id)
);

create index if not exists mitra_service_bookmarks_service_idx
  on public.mitra_service_bookmarks(service_id, created_at desc);

alter table public.mitra_service_bookmarks enable row level security;
grant select, insert, delete on public.mitra_service_bookmarks to authenticated;

drop policy if exists "bookmark own read" on public.mitra_service_bookmarks;
create policy "bookmark own read"
on public.mitra_service_bookmarks for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "bookmark own insert" on public.mitra_service_bookmarks;
create policy "bookmark own insert"
on public.mitra_service_bookmarks for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.mitra_services s
    join public.mitras m on m.id = s.mitra_id
    where s.id = service_id
      and s.is_active = true
      and coalesce(m.is_active, false) = true
  )
);

drop policy if exists "bookmark own delete" on public.mitra_service_bookmarks;
create policy "bookmark own delete"
on public.mitra_service_bookmarks for delete
to authenticated
using (user_id = auth.uid());

-- Public area helper is repeated here so this migration stays safe even when
-- a development database skipped the earlier visual-polish migration.
create or replace function public.marketplace_location_label(p_address text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_parts text[];
  v_count integer;
begin
  if p_address is null or trim(p_address) = '' then return null; end if;
  v_parts := string_to_array(p_address, ',');
  v_count := coalesce(array_length(v_parts, 1), 0);
  if v_count >= 3 then
    return trim(v_parts[2]) || ', ' || trim(v_parts[3]);
  elsif v_count = 2 then
    return trim(v_parts[2]);
  end if;
  return null;
end;
$$;

revoke all on function public.marketplace_location_label(text) from public;
grant execute on function public.marketplace_location_label(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Public service RPC enriched with tags/bookmark state
-- ---------------------------------------------------------------------------
drop function if exists public.get_public_mitra_services();

create function public.get_public_mitra_services()
returns table (
  id uuid,
  mitra_id uuid,
  category_id uuid,
  title text,
  description text,
  starting_price numeric,
  tags text[],
  created_at timestamp with time zone,
  category_name text,
  category_icon text,
  mitra_fullname text,
  mitra_avatar_url text,
  mitra_rating numeric,
  mitra_location text,
  is_bookmarked boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.id,
    s.mitra_id,
    s.category_id,
    s.title,
    s.description,
    s.starting_price,
    coalesce(s.tags, '{}'::text[]),
    s.created_at,
    c.name,
    c.icon,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh'),
    u.avatar_url,
    coalesce(m.rating, 0),
    public.marketplace_location_label(
      coalesce(nullif(trim(a.address), ''), nullif(trim(u.alamat), ''))
    ),
    exists (
      select 1 from public.mitra_service_bookmarks b
      where b.service_id = s.id
        and b.user_id = auth.uid()
    )
  from public.mitra_services s
  join public.mitras m
    on m.id = s.mitra_id
   and coalesce(m.is_active, false) = true
  join public.users u on u.id = s.mitra_id
  join public.categories c on c.id = s.category_id
  left join lateral (
    select ad.address
    from public.addresses ad
    where ad.user_id = s.mitra_id
    order by coalesce(ad.is_default, false) desc, ad.created_at desc
    limit 1
  ) a on true
  where s.is_active = true
  order by s.created_at desc;
$$;

revoke all on function public.get_public_mitra_services() from public;
grant execute on function public.get_public_mitra_services() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Safe public Mitra profile + reviews
-- ---------------------------------------------------------------------------
drop function if exists public.get_public_mitra_profile(uuid);
create function public.get_public_mitra_profile(p_mitra_id uuid)
returns table (
  mitra_id uuid,
  fullname text,
  avatar_url text,
  rating numeric,
  location text,
  joined_at timestamp with time zone,
  completed_jobs bigint,
  review_count bigint,
  active_services bigint,
  categories text[]
)
language sql
security definer
set search_path = public
stable
as $$
  select
    m.id,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh'),
    u.avatar_url,
    coalesce(m.rating, 0),
    public.marketplace_location_label(
      coalesce(nullif(trim(a.address), ''), nullif(trim(u.alamat), ''))
    ),
    m.created_at,
    (
      select count(*)
      from public.jobs j
      where j.mitra_id = m.id
        and j.status = 'completed'::public.job_status
    ),
    (
      select count(*)
      from public.reviews r
      where r.mitra_id = m.id
    ),
    (
      select count(*)
      from public.mitra_services s
      where s.mitra_id = m.id and s.is_active = true
    ),
    coalesce((
      select array_agg(distinct c.name order by c.name)
      from public.mitra_services s
      join public.categories c on c.id = s.category_id
      where s.mitra_id = m.id and s.is_active = true
    ), '{}'::text[])
  from public.mitras m
  join public.users u on u.id = m.id
  left join lateral (
    select ad.address
    from public.addresses ad
    where ad.user_id = m.id
    order by coalesce(ad.is_default, false) desc, ad.created_at desc
    limit 1
  ) a on true
  where m.id = p_mitra_id
    and coalesce(m.is_active, false) = true;
$$;

revoke all on function public.get_public_mitra_profile(uuid) from public;
grant execute on function public.get_public_mitra_profile(uuid) to authenticated;

drop function if exists public.get_public_mitra_reviews(uuid, integer);
create function public.get_public_mitra_reviews(
  p_mitra_id uuid,
  p_limit integer default 5
)
returns table (
  rating integer,
  review text,
  tags text[],
  created_at timestamp with time zone
)
language sql
security definer
set search_path = public
stable
as $$
  select
    r.rating,
    r.review,
    coalesce(r.tags, '{}'::text[]),
    r.created_at
  from public.reviews r
  join public.mitras m on m.id = r.mitra_id
  where r.mitra_id = p_mitra_id
    and coalesce(m.is_active, false) = true
  order by r.created_at desc
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;

revoke all on function public.get_public_mitra_reviews(uuid, integer) from public;
grant execute on function public.get_public_mitra_reviews(uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Realtime publication
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'user_presence'
    ) then
      execute 'alter publication supabase_realtime add table public.user_presence';
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'chat_typing'
    ) then
      execute 'alter publication supabase_realtime add table public.chat_typing';
    end if;
  end if;
end
$$;

commit;
