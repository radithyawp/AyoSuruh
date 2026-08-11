-- Ayo Suruh - Auto Complete Stale Jobs
-- Default grace period: 24 hours after completion is eligible for confirmation.
-- Cash jobs only become eligible after cash is confirmed paid.

begin;

-- ---------------------------------------------------------------------------
-- 1. Configurable timeout + audit marker.
-- ---------------------------------------------------------------------------
alter table public.business_settings
  add column if not exists auto_complete_hours integer not null default 24;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'business_settings_auto_complete_hours_check'
      and conrelid = 'public.business_settings'::regclass
  ) then
    alter table public.business_settings
      add constraint business_settings_auto_complete_hours_check
      check (auto_complete_hours between 1 and 168);
  end if;
end
$$;

alter table public.jobs
  add column if not exists auto_completed_at timestamptz;

create or replace function public.current_auto_complete_hours()
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select bs.auto_complete_hours
      from public.business_settings bs
      where bs.id = 1
    ),
    24
  );
$$;

revoke all on function public.current_auto_complete_hours() from public;
grant execute on function public.current_auto_complete_hours() to authenticated;
grant execute on function public.current_auto_complete_hours() to service_role;

-- ---------------------------------------------------------------------------
-- 2. Keep job notifications accurate for manual vs automatic completion.
--    Also inform Customer about the automatic-completion grace period when
--    Mitra submits completion.
-- ---------------------------------------------------------------------------
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
  v_auto_hours integer := public.current_auto_complete_hours();
  v_is_auto_completed boolean := false;
begin
  v_title := coalesce(new.title, 'Pekerjaan');

  if old.progress_stage is distinct from new.progress_stage
     and new.progress_stage is not null then
    case new.progress_stage::text
      when 'heading_to_location' then
        v_progress_title := 'Mitra Menuju Lokasi';
        v_body := format(
          'Mitra sedang menuju lokasi pekerjaan "%s".',
          v_title
        );
      when 'arrived' then
        v_progress_title := 'Mitra Tiba di Lokasi';
        v_body := format(
          'Mitra sudah tiba untuk mengerjakan "%s".',
          v_title
        );
      when 'working' then
        v_progress_title := 'Pekerjaan Dimulai';
        v_body := format(
          'Mitra mulai mengerjakan "%s".',
          v_title
        );
      when 'completion_submitted' then
        v_progress_title := 'Menunggu Konfirmasi Selesai';
        v_body := format(
          'Mitra menyatakan pekerjaan "%s" selesai. Periksa hasilnya. Jika tidak ada tindakan, pekerjaan akan otomatis selesai dalam %s jam setelah syarat pembayaran terpenuhi.',
          v_title,
          v_auto_hours
        );
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
        jsonb_build_object(
          'progress_stage', new.progress_stage::text,
          'auto_complete_hours', v_auto_hours
        )
      );
    end if;
  end if;

  if old.status is distinct from new.status then
    if new.status::text = 'completed' and new.mitra_id is not null then
      v_is_auto_completed :=
        new.auto_completed_at is not null
        and old.auto_completed_at is distinct from new.auto_completed_at;

      if v_is_auto_completed then
        perform public.enqueue_notification(
          new.mitra_id,
          'Pekerjaan Selesai Otomatis',
          format(
            'Pekerjaan "%s" otomatis ditandai selesai karena batas konfirmasi Customer telah berakhir.',
            v_title
          ),
          'job_completed',
          new.id,
          null,
          null,
          jsonb_build_object(
            'auto_completed', true,
            'auto_completed_at', new.auto_completed_at,
            'auto_complete_hours', v_auto_hours
          )
        );

        perform public.enqueue_notification(
          new.customer_id,
          'Pekerjaan Selesai Otomatis',
          format(
            'Batas konfirmasi untuk pekerjaan "%s" telah berakhir dan pekerjaan otomatis ditandai selesai. Kamu masih dapat memberikan rating dan ulasan.',
            v_title
          ),
          'job_completed',
          new.id,
          null,
          null,
          jsonb_build_object(
            'auto_completed', true,
            'auto_completed_at', new.auto_completed_at,
            'auto_complete_hours', v_auto_hours
          )
        );
      else
        perform public.enqueue_notification(
          new.mitra_id,
          'Pekerjaan Dikonfirmasi Selesai',
          format(
            'Customer telah mengonfirmasi pekerjaan "%s" selesai.',
            v_title
          ),
          'job_completed',
          new.id,
          null,
          new.customer_id,
          '{}'::jsonb
        );
      end if;
    elsif new.status::text = 'cancelled' and new.mitra_id is not null then
      perform public.enqueue_notification(
        new.mitra_id,
        'Pekerjaan Dibatalkan',
        format(
          'Pekerjaan "%s" telah dibatalkan oleh customer.',
          v_title
        ),
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
        format(
          'Mitra mulai menangani pekerjaan "%s".',
          v_title
        ),
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

-- Trigger already exists in the notification migration, but recreate it so
-- this migration is self-contained/idempotent.
drop trigger if exists trg_notify_job_event on public.jobs;
create trigger trg_notify_job_event
after update of status, progress_stage on public.jobs
for each row execute function public.notify_job_event();

-- ---------------------------------------------------------------------------
-- 3. Worker function.
--
-- Eligible:
--   * status on_progress
--   * progress_stage completion_submitted
--   * payment is absent/not required OR payment status is paid
--   * for Cash, paid confirmation must already exist
--   * grace period has elapsed
--
-- Cash deadline starts from the later of:
--   completion submitted OR cash confirmation.
-- ---------------------------------------------------------------------------
create or replace function public.auto_complete_stale_jobs()
returns integer
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  v_job record;
  v_completed integer := 0;
  v_hours integer := public.current_auto_complete_hours();
  v_now timestamptz := timezone('utc'::text, now());
begin
  for v_job in
    select
      j.id,
      j.customer_id,
      j.mitra_id,
      j.title,
      s.submitted_at,
      p.id as payment_id,
      p.provider,
      p.status as payment_status,
      p.payment_required,
      p.paid_at,
      p.cash_confirmed_at,
      case
        when coalesce(p.provider, '') = 'cash' then
          greatest(
            s.submitted_at,
            coalesce(p.cash_confirmed_at, p.paid_at, s.submitted_at)
          )
        else
          s.submitted_at
      end as eligible_since
    from public.jobs j
    join lateral (
      select max(t.created_at) as submitted_at
      from public.job_timelines t
      where t.job_id = j.id
        and t.progress_stage = 'completion_submitted'::public.job_progress_stage
    ) s on s.submitted_at is not null
    left join public.payments p
      on p.job_id = j.id
    where j.status = 'on_progress'::public.job_status
      and j.progress_stage = 'completion_submitted'::public.job_progress_stage
      and (
        p.id is null
        or coalesce(p.payment_required, false) = false
        or p.status = 'paid'::public.payment_status
      )
      and not (
        coalesce(p.provider, '') = 'cash'
        and coalesce(p.status <> 'paid'::public.payment_status, true)
      )
      and (
        case
          when coalesce(p.provider, '') = 'cash' then
            greatest(
              s.submitted_at,
              coalesce(p.cash_confirmed_at, p.paid_at, s.submitted_at)
            )
          else
            s.submitted_at
        end
      ) <= v_now - make_interval(hours => v_hours)
    for update of j skip locked
  loop
    update public.jobs
    set
      status = 'completed'::public.job_status,
      auto_completed_at = v_now
    where id = v_job.id
      and status = 'on_progress'::public.job_status
      and progress_stage = 'completion_submitted'::public.job_progress_stage;

    if not found then
      continue;
    end if;

    insert into public.job_timelines (
      job_id,
      status,
      progress_stage,
      description
    ) values (
      v_job.id,
      'completed'::public.job_status,
      'completion_submitted'::public.job_progress_stage,
      format(
        'Sistem otomatis menyelesaikan pekerjaan setelah batas konfirmasi %s jam berakhir.',
        v_hours
      )
    );

    -- Preserve the existing economics/wallet behavior.
    perform public.ensure_completed_job_earning(v_job.id);

    v_completed := v_completed + 1;
  end loop;

  return v_completed;
end;
$$;

revoke all on function public.auto_complete_stale_jobs() from public, anon, authenticated;
grant execute on function public.auto_complete_stale_jobs() to service_role;

commit;

-- ---------------------------------------------------------------------------
-- 4. Supabase Cron.
-- Supabase Cron uses pg_cron. Reusing the same job name overwrites the
-- existing job, keeping this migration safe to rerun.
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;

select cron.schedule(
  'ayo-auto-complete-stale-jobs',
  '*/10 * * * *',
  'select public.auto_complete_stale_jobs();'
);
