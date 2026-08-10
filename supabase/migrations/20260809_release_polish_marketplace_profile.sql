-- Ayo Suruh release polish: public marketplace profile metadata.
-- Hanya mengekspos lokasi area (bukan alamat detail) + rating Mitra.

begin;

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
  if p_address is null or trim(p_address) = '' then
    return null;
  end if;

  v_parts := string_to_array(p_address, ',');
  v_count := coalesce(array_length(v_parts, 1), 0);

  -- Segmen pertama sering berisi alamat rumah/jalan. Jangan diekspos pada katalog.
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

drop function if exists public.get_public_mitra_services();

create function public.get_public_mitra_services()
returns table (
  id uuid,
  mitra_id uuid,
  category_id uuid,
  title text,
  description text,
  starting_price numeric,
  created_at timestamp with time zone,
  category_name text,
  category_icon text,
  mitra_fullname text,
  mitra_avatar_url text,
  mitra_rating numeric,
  mitra_location text
)
language sql
security definer
set search_path = public
as $$
  select
    s.id,
    s.mitra_id,
    s.category_id,
    s.title,
    s.description,
    s.starting_price,
    s.created_at,
    c.name,
    c.icon,
    coalesce(nullif(trim(u.fullname), ''), 'Mitra Ayo Suruh'),
    u.avatar_url,
    coalesce(m.rating, 0),
    public.marketplace_location_label(
      coalesce(nullif(trim(a.address), ''), nullif(trim(u.alamat), ''))
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

commit;
