-- AYO SURUH - FINAL SECURITY HARDENING
-- Audit trail untuk lifecycle akun dan perubahan membership Admin.

begin;

create table if not exists public.security_audit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  actor_id uuid,
  event_type text not null check (
    event_type in (
      'account_deactivated',
      'account_reactivated',
      'account_deleted',
      'admin_access_granted',
      'admin_access_updated',
      'admin_access_revoked'
    )
  ),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists security_audit_events_created_idx
  on public.security_audit_events(created_at desc);
create index if not exists security_audit_events_user_idx
  on public.security_audit_events(user_id, created_at desc);

alter table public.security_audit_events enable row level security;

drop policy if exists "ayo_security_audit_admin_read" on public.security_audit_events;
create policy "ayo_security_audit_admin_read"
on public.security_audit_events for select
to authenticated
using (public.is_current_user_admin());

grant select on public.security_audit_events to authenticated;
revoke insert, update, delete on public.security_audit_events from authenticated, anon;

create or replace function public.audit_account_state_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event text;
begin
  if old.account_state is not distinct from new.account_state then
    return new;
  end if;

  v_event := case new.account_state
    when 'deactivated' then 'account_deactivated'
    when 'deleted' then 'account_deleted'
    when 'active' then 'account_reactivated'
    else null
  end;

  if v_event is not null then
    insert into public.security_audit_events(
      user_id,
      actor_id,
      event_type,
      metadata
    ) values (
      new.id,
      auth.uid(),
      v_event,
      jsonb_build_object(
        'previous_state', old.account_state,
        'new_state', new.account_state
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function public.audit_account_state_change() from public, anon, authenticated;

drop trigger if exists trg_audit_account_state_change on public.users;
create trigger trg_audit_account_state_change
after update of account_state on public.users
for each row execute function public.audit_account_state_change();

create or replace function public.audit_admin_membership_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_event text;
  v_metadata jsonb;
begin
  if tg_op = 'INSERT' then
    v_user_id := new.user_id;
    v_event := 'admin_access_granted';
    v_metadata := jsonb_build_object(
      'admin_role', new.admin_role,
      'is_active', new.is_active
    );
  elsif tg_op = 'DELETE' then
    v_user_id := old.user_id;
    v_event := 'admin_access_revoked';
    v_metadata := jsonb_build_object(
      'admin_role', old.admin_role,
      'is_active', old.is_active
    );
  else
    if old.admin_role is not distinct from new.admin_role
       and old.is_active is not distinct from new.is_active then
      return new;
    end if;
    v_user_id := new.user_id;
    v_event := 'admin_access_updated';
    v_metadata := jsonb_build_object(
      'previous_role', old.admin_role,
      'new_role', new.admin_role,
      'previous_active', old.is_active,
      'new_active', new.is_active
    );
  end if;

  insert into public.security_audit_events(
    user_id,
    actor_id,
    event_type,
    metadata
  ) values (
    v_user_id,
    auth.uid(),
    v_event,
    v_metadata
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.audit_admin_membership_change() from public, anon, authenticated;

drop trigger if exists trg_audit_admin_membership_change on public.admin_users;
create trigger trg_audit_admin_membership_change
after insert or update of admin_role, is_active or delete on public.admin_users
for each row execute function public.audit_admin_membership_change();

commit;
