-- Ayo Suruh - Active Job Phone Call
-- Exposes the other participant's registered phone number only while the
-- caller is a participant in an active accepted/on_progress job.
--
-- The mobile app uses this result only to open the native phone dialer.
-- The phone value is intentionally returned as NULL outside active jobs.

begin;

drop function if exists public.get_chat_room_header(uuid);

create function public.get_chat_room_header(p_room_id uuid)
returns table (
  room_id uuid,
  job_id uuid,
  job_title text,
  job_status text,
  partner_id uuid,
  partner_name text,
  partner_avatar_url text,
  partner_phone text,
  can_call boolean
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
    case
      when j.status::text in ('accepted', 'on_progress')
        and nullif(trim(coalesce(partner.phone, '')), '') is not null
      then trim(partner.phone)
      else null
    end as partner_phone,
    (
      j.status::text in ('accepted', 'on_progress')
      and nullif(trim(coalesce(partner.phone, '')), '') is not null
    ) as can_call
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

revoke all on function public.get_chat_room_header(uuid) from public;
grant execute on function public.get_chat_room_header(uuid) to authenticated;
grant execute on function public.get_chat_room_header(uuid) to service_role;

commit;
