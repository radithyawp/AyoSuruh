-- =============================================================================
-- AYO SURUH - IN-APP VOICE CALL (LIVEKIT)
-- Customer <-> Mitra audio call for active jobs. No native dialer and no phone
-- number exposure is required by the call flow.
-- =============================================================================

begin;

create table if not exists public.voice_calls (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.chat_rooms(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  caller_id uuid not null references public.users(id) on delete cascade,
  callee_id uuid not null references public.users(id) on delete cascade,
  livekit_room_name text not null unique,
  caller_name_snapshot text not null,
  callee_name_snapshot text not null,
  status text not null default 'ringing',
  created_at timestamptz not null default timezone('utc'::text, now()),
  expires_at timestamptz not null default (timezone('utc'::text, now()) + interval '45 seconds'),
  answered_at timestamptz,
  connected_at timestamptz,
  ended_at timestamptz,
  ended_by uuid references public.users(id) on delete set null,
  end_reason text,
  constraint voice_calls_distinct_participants check (caller_id <> callee_id),
  constraint voice_calls_status_check check (
    status in ('ringing', 'accepted', 'ongoing', 'declined', 'cancelled', 'ended', 'missed')
  )
);

create index if not exists voice_calls_room_created_idx
  on public.voice_calls (room_id, created_at desc);

create index if not exists voice_calls_callee_status_idx
  on public.voice_calls (callee_id, status, created_at desc);

create index if not exists voice_calls_caller_status_idx
  on public.voice_calls (caller_id, status, created_at desc);

alter table public.voice_calls enable row level security;

drop policy if exists "voice call participants can read" on public.voice_calls;
create policy "voice call participants can read"
on public.voice_calls
for select
to authenticated
using (auth.uid() in (caller_id, callee_id));

grant select on table public.voice_calls to authenticated, service_role;

-- Keep direct writes disabled. All state transitions go through security-definer
-- RPCs so clients cannot impersonate another caller/callee or skip validation.
revoke insert, update, delete on table public.voice_calls from authenticated, anon;

create or replace function public._expire_stale_voice_calls()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer := 0;
  v_added integer := 0;
begin
  update public.voice_calls
  set status = 'missed',
      ended_at = coalesce(ended_at, timezone('utc'::text, now())),
      end_reason = coalesce(end_reason, 'no_answer')
  where status = 'ringing'
    and expires_at <= timezone('utc'::text, now());

  get diagnostics v_count = row_count;

  update public.voice_calls
  set status = 'ended',
      ended_at = coalesce(ended_at, timezone('utc'::text, now())),
      end_reason = coalesce(end_reason, 'connection_timeout')
  where status = 'accepted'
    and connected_at is null
    and answered_at <= timezone('utc'::text, now()) - interval '2 minutes';

  get diagnostics v_added = row_count;
  v_count := v_count + v_added;

  -- Safety valve for orphaned sessions after both apps/processes disappear.
  -- Normal calls are ended immediately by either participant; this prevents a
  -- crashed client from keeping both accounts permanently "busy".
  update public.voice_calls
  set status = 'ended',
      ended_at = coalesce(ended_at, timezone('utc'::text, now())),
      end_reason = coalesce(end_reason, 'safety_timeout')
  where status = 'ongoing'
    and connected_at <= timezone('utc'::text, now()) - interval '4 hours';

  get diagnostics v_added = row_count;
  v_count := v_count + v_added;
  return v_count;
end;
$$;

revoke all on function public._expire_stale_voice_calls() from public, anon, authenticated;

create or replace function public.get_voice_call(p_call_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._expire_stale_voice_calls();

  select
    to_jsonb(vc) || jsonb_build_object(
      'is_caller', auth.uid() = vc.caller_id,
      'partner_id', case when auth.uid() = vc.caller_id then vc.callee_id else vc.caller_id end,
      'partner_name', case
        when auth.uid() = vc.caller_id then coalesce(nullif(trim(callee.fullname), ''), vc.callee_name_snapshot)
        else coalesce(nullif(trim(caller.fullname), ''), vc.caller_name_snapshot)
      end,
      'partner_avatar_url', case
        when auth.uid() = vc.caller_id then callee.avatar_url
        else caller.avatar_url
      end,
      'job_title', j.title,
      'job_status', j.status::text
    )
  into v_result
  from public.voice_calls vc
  join public.jobs j on j.id = vc.job_id
  left join public.users caller on caller.id = vc.caller_id
  left join public.users callee on callee.id = vc.callee_id
  where vc.id = p_call_id
    and auth.uid() in (vc.caller_id, vc.callee_id);

  if v_result is null then
    raise exception 'Panggilan tidak ditemukan atau tidak dapat diakses.';
  end if;

  return v_result;
end;
$$;

revoke all on function public.get_voice_call(uuid) from public;
grant execute on function public.get_voice_call(uuid) to authenticated, service_role;

create or replace function public.get_pending_incoming_voice_call()
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_call_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._expire_stale_voice_calls();

  select vc.id
  into v_call_id
  from public.voice_calls vc
  where vc.callee_id = auth.uid()
    and vc.status = 'ringing'
    and vc.expires_at > timezone('utc'::text, now())
  order by vc.created_at desc
  limit 1;

  if v_call_id is null then
    return null;
  end if;

  return public.get_voice_call(v_call_id);
end;
$$;

revoke all on function public.get_pending_incoming_voice_call() from public;
grant execute on function public.get_pending_incoming_voice_call() to authenticated;

create or replace function public.create_voice_call(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_call_id uuid := gen_random_uuid();
  v_job_id uuid;
  v_job_status text;
  v_customer_id uuid;
  v_mitra_id uuid;
  v_callee_id uuid;
  v_caller_name text;
  v_callee_name text;
  v_busy boolean;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._expire_stale_voice_calls();

  select cr.job_id, j.status::text, cr.customer_id, cr.mitra_id
  into v_job_id, v_job_status, v_customer_id, v_mitra_id
  from public.chat_rooms cr
  join public.jobs j on j.id = cr.job_id
  where cr.id = p_room_id
    and auth.uid() in (cr.customer_id, cr.mitra_id);

  if v_job_id is null then
    raise exception 'Percakapan tidak ditemukan atau tidak dapat diakses.';
  end if;

  if v_job_status not in ('accepted', 'on_progress') then
    raise exception 'Panggilan hanya tersedia untuk pekerjaan yang masih aktif.';
  end if;

  v_callee_id := case
    when auth.uid() = v_customer_id then v_mitra_id
    else v_customer_id
  end;

  -- Serialize call creation for this participant pair and prevent two parallel
  -- calls from racing past the busy check.
  perform pg_advisory_xact_lock(
    hashtextextended(
      'ayo:voice-call:' || least(auth.uid()::text, v_callee_id::text) || ':' || greatest(auth.uid()::text, v_callee_id::text),
      0
    )
  );

  select exists (
    select 1
    from public.voice_calls vc
    where vc.status in ('ringing', 'accepted', 'ongoing')
      and (
        auth.uid() in (vc.caller_id, vc.callee_id)
        or v_callee_id in (vc.caller_id, vc.callee_id)
      )
  ) into v_busy;

  if v_busy then
    raise exception 'Salah satu pengguna sedang berada dalam panggilan lain.';
  end if;

  select coalesce(nullif(trim(fullname), ''), 'Pengguna Ayo Suruh')
  into v_caller_name
  from public.users
  where id = auth.uid();

  select coalesce(nullif(trim(fullname), ''), 'Pengguna Ayo Suruh')
  into v_callee_name
  from public.users
  where id = v_callee_id;

  insert into public.voice_calls (
    id,
    room_id,
    job_id,
    caller_id,
    callee_id,
    livekit_room_name,
    caller_name_snapshot,
    callee_name_snapshot,
    status,
    expires_at
  ) values (
    v_call_id,
    p_room_id,
    v_job_id,
    auth.uid(),
    v_callee_id,
    'ayo-call-' || replace(v_call_id::text, '-', ''),
    coalesce(v_caller_name, 'Pengguna Ayo Suruh'),
    coalesce(v_callee_name, 'Pengguna Ayo Suruh'),
    'ringing',
    timezone('utc'::text, now()) + interval '45 seconds'
  );

  perform public.enqueue_notification(
    v_callee_id,
    'Panggilan masuk',
    coalesce(v_caller_name, 'Pengguna Ayo Suruh') || ' menelepon melalui Ayo Suruh.',
    'voice_call_incoming',
    v_job_id,
    p_room_id,
    auth.uid(),
    jsonb_build_object('call_id', v_call_id)
  );

  return public.get_voice_call(v_call_id);
end;
$$;

revoke all on function public.create_voice_call(uuid) from public;
grant execute on function public.create_voice_call(uuid) to authenticated;

create or replace function public.respond_voice_call(
  p_call_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_call public.voice_calls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  perform public._expire_stale_voice_calls();

  select * into v_call
  from public.voice_calls
  where id = p_call_id
  for update;

  if v_call.id is null or v_call.callee_id <> auth.uid() then
    raise exception 'Kamu tidak dapat merespons panggilan ini.';
  end if;

  if v_call.status <> 'ringing' then
    return public.get_voice_call(p_call_id);
  end if;

  if p_accept then
    update public.voice_calls
    set status = 'accepted',
        answered_at = coalesce(answered_at, timezone('utc'::text, now()))
    where id = p_call_id;
  else
    update public.voice_calls
    set status = 'declined',
        ended_at = coalesce(ended_at, timezone('utc'::text, now())),
        ended_by = auth.uid(),
        end_reason = 'declined'
    where id = p_call_id;
  end if;

  return public.get_voice_call(p_call_id);
end;
$$;

revoke all on function public.respond_voice_call(uuid, boolean) from public;
grant execute on function public.respond_voice_call(uuid, boolean) to authenticated;

create or replace function public.cancel_voice_call(p_call_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_call public.voice_calls%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select * into v_call
  from public.voice_calls
  where id = p_call_id
  for update;

  if v_call.id is null or v_call.caller_id <> auth.uid() then
    raise exception 'Kamu tidak dapat membatalkan panggilan ini.';
  end if;

  if v_call.status = 'ringing' then
    update public.voice_calls
    set status = 'cancelled',
        ended_at = coalesce(ended_at, timezone('utc'::text, now())),
        ended_by = auth.uid(),
        end_reason = 'caller_cancelled'
    where id = p_call_id;
  end if;

  return public.get_voice_call(p_call_id);
end;
$$;

revoke all on function public.cancel_voice_call(uuid) from public;
grant execute on function public.cancel_voice_call(uuid) to authenticated;

create or replace function public.mark_voice_call_connected(p_call_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  update public.voice_calls
  set status = 'ongoing',
      connected_at = coalesce(connected_at, timezone('utc'::text, now()))
  where id = p_call_id
    and auth.uid() in (caller_id, callee_id)
    and status in ('accepted', 'ongoing');

  if not found then
    return public.get_voice_call(p_call_id);
  end if;

  return public.get_voice_call(p_call_id);
end;
$$;

revoke all on function public.mark_voice_call_connected(uuid) from public;
grant execute on function public.mark_voice_call_connected(uuid) to authenticated;

create or replace function public.end_voice_call(p_call_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_call public.voice_calls%rowtype;
  v_next_status text;
  v_reason text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select * into v_call
  from public.voice_calls
  where id = p_call_id
  for update;

  if v_call.id is null or auth.uid() not in (v_call.caller_id, v_call.callee_id) then
    raise exception 'Kamu tidak dapat mengakhiri panggilan ini.';
  end if;

  if v_call.status in ('declined', 'cancelled', 'ended', 'missed') then
    return public.get_voice_call(p_call_id);
  end if;

  if v_call.status = 'ringing' then
    if auth.uid() = v_call.caller_id then
      v_next_status := 'cancelled';
      v_reason := 'caller_cancelled';
    else
      v_next_status := 'declined';
      v_reason := 'declined';
    end if;
  else
    v_next_status := 'ended';
    v_reason := 'hangup';
  end if;

  update public.voice_calls
  set status = v_next_status,
      ended_at = coalesce(ended_at, timezone('utc'::text, now())),
      ended_by = auth.uid(),
      end_reason = coalesce(end_reason, v_reason)
  where id = p_call_id;

  return public.get_voice_call(p_call_id);
end;
$$;

revoke all on function public.end_voice_call(uuid) from public;
grant execute on function public.end_voice_call(uuid) to authenticated;

-- Stop exposing the partner phone number from chat headers. Calls are now
-- authenticated in-app voice sessions and only depend on active job status.
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
    null::text as partner_phone,
    (j.status::text in ('accepted', 'on_progress')) as can_call
  from public.chat_rooms cr
  join public.jobs j on j.id = cr.job_id
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
grant execute on function public.get_chat_room_header(uuid) to authenticated, service_role;

-- Realtime is used only for signaling call state. Audio itself travels through
-- LiveKit's WebRTC transport and is not stored in Supabase.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'voice_calls'
  ) then
    execute 'alter publication supabase_realtime add table public.voice_calls';
  end if;
end;
$$;

commit;
