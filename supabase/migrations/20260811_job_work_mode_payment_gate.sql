-- Ayo Suruh - Work Mode aware progress + mandatory payment selection gate
-- Fixes two business-logic issues:
-- 1) remote/digital jobs must not pass through physical-location progress stages;
-- 2) Mitra must not start or advance work before Customer selects payment.

begin;

-- ---------------------------------------------------------------------------
-- 1. Persist how the job is fulfilled.
--    text + CHECK is intentionally used instead of a new enum to keep client
--    compatibility and migrations simple.
-- ---------------------------------------------------------------------------
alter table public.jobs
  add column if not exists work_mode text;

-- Backfill only rows that do not have an explicit mode yet.
update public.jobs j
set work_mode = case
  when lower(c.name) in (lower('Design & Coding'), lower('Administrasi'))
    then 'remote'
  when lower(c.name) in (
    lower('Antar-Jemput'),
    lower('Jasa Titip'),
    lower('Survey & Informasi Kost'),
    lower('Kurir')
  ) then 'mobile'
  else 'onsite'
end
from public.categories c
where c.id = j.category_id
  and j.work_mode is null;

update public.jobs
set work_mode = 'onsite'
where work_mode is null;

alter table public.jobs
  alter column work_mode set default 'onsite',
  alter column work_mode set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'jobs_work_mode_check'
      and conrelid = 'public.jobs'::regclass
  ) then
    alter table public.jobs
      add constraint jobs_work_mode_check
      check (work_mode in ('remote', 'onsite', 'mobile'));
  end if;
end
$$;

-- Historical remote jobs that were already started using the old physical
-- workflow are normalized to the first valid remote stage.
with corrected as (
  update public.jobs j
  set progress_stage = 'working'::public.job_progress_stage
  where j.work_mode = 'remote'
    and j.status = 'on_progress'::public.job_status
    and (
      j.progress_stage is null
      or j.progress_stage in (
        'heading_to_location'::public.job_progress_stage,
        'arrived'::public.job_progress_stage
      )
    )
  returning j.id
)
insert into public.job_timelines (
  job_id,
  status,
  progress_stage,
  description
)
select
  c.id,
  'on_progress'::public.job_status,
  'working'::public.job_progress_stage,
  'Progres disesuaikan ke pengerjaan online / jarak jauh.'
from corrected c;

-- ---------------------------------------------------------------------------
-- 2. Internal payment gate shared by start + progress RPCs.
--
-- Selection rule:
--   payment row exists AND payment_required = true.
--
-- Fulfillment rule:
--   Cash     : may work while pending, because payment happens after work.
--   Non-cash : must already be paid.
-- ---------------------------------------------------------------------------
create or replace function public._assert_job_payment_ready_for_mitra(
  p_job_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_required boolean;
  v_payment_status public.payment_status;
  v_provider text;
begin
  select
    p.payment_required,
    p.status,
    nullif(trim(coalesce(p.provider, '')), '')
  into
    v_payment_required,
    v_payment_status,
    v_provider
  from public.payments p
  where p.job_id = p_job_id;

  if not found or coalesce(v_payment_required, false) = false then
    raise exception 'Customer belum memilih metode pembayaran.';
  end if;

  if v_provider is null then
    raise exception 'Metode pembayaran pekerjaan belum valid.';
  end if;

  if lower(v_provider) = 'cash' then
    if v_payment_status not in (
      'pending'::public.payment_status,
      'paid'::public.payment_status
    ) then
      raise exception 'Pembayaran Cash tidak lagi aktif untuk pekerjaan ini.';
    end if;
    return;
  end if;

  if v_payment_status <> 'paid'::public.payment_status then
    raise exception 'Customer belum menyelesaikan pembayaran.';
  end if;
end;
$$;

revoke all on function public._assert_job_payment_ready_for_mitra(uuid)
from public, anon, authenticated;
grant execute on function public._assert_job_payment_ready_for_mitra(uuid)
to service_role;

-- ---------------------------------------------------------------------------
-- 3. Start job: payment selection is mandatory and initial progress depends
--    on work_mode.
-- ---------------------------------------------------------------------------
create or replace function public.start_assigned_job(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.job_status;
  v_work_mode text;
  v_initial_stage public.job_progress_stage;
  v_description text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select j.status, j.work_mode
    into v_status, v_work_mode
  from public.jobs j
  where j.id = p_job_id
    and j.mitra_id = auth.uid()
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan atau bukan milik Mitra ini.';
  end if;

  if v_status <> 'accepted'::public.job_status then
    raise exception 'Pekerjaan belum dapat dimulai dari status saat ini.';
  end if;

  perform public._assert_job_payment_ready_for_mitra(p_job_id);

  if coalesce(v_work_mode, 'onsite') = 'remote' then
    v_initial_stage := 'working'::public.job_progress_stage;
    v_description := 'Mitra mulai mengerjakan pekerjaan secara online / jarak jauh.';
  elsif v_work_mode = 'mobile' then
    v_initial_stage := 'heading_to_location'::public.job_progress_stage;
    v_description := 'Mitra mulai menuju titik awal pekerjaan.';
  else
    v_initial_stage := 'heading_to_location'::public.job_progress_stage;
    v_description := 'Mitra sedang menuju lokasi pekerjaan.';
  end if;

  update public.jobs
  set status = 'on_progress'::public.job_status,
      progress_stage = v_initial_stage
  where id = p_job_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description
  ) values (
    p_job_id,
    'on_progress'::public.job_status,
    v_initial_stage,
    v_description
  );
end;
$$;

revoke all on function public.start_assigned_job(uuid) from public;
grant execute on function public.start_assigned_job(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Advance progress: enforce both payment gate and work-mode state machine.
-- ---------------------------------------------------------------------------
create or replace function public.advance_job_progress(
  p_job_id uuid,
  p_progress_stage public.job_progress_stage,
  p_note text default null,
  p_evidence_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.job_status;
  v_current public.job_progress_stage;
  v_work_mode text;
  v_default_description text;
begin
  if auth.uid() is null then
    raise exception 'Pengguna belum login.';
  end if;

  select
    j.status,
    j.progress_stage,
    coalesce(j.work_mode, 'onsite')
  into
    v_status,
    v_current,
    v_work_mode
  from public.jobs j
  where j.id = p_job_id
    and j.mitra_id = auth.uid()
  for update;

  if not found then
    raise exception 'Pekerjaan tidak ditemukan atau bukan milik Mitra ini.';
  end if;

  if v_status <> 'on_progress'::public.job_status then
    raise exception 'Pekerjaan belum dalam status sedang dikerjakan.';
  end if;

  perform public._assert_job_payment_ready_for_mitra(p_job_id);

  if v_work_mode = 'remote' then
    v_current := coalesce(
      v_current,
      'working'::public.job_progress_stage
    );

    if v_current = 'working'::public.job_progress_stage
       and p_progress_stage <> 'completion_submitted'::public.job_progress_stage then
      raise exception 'Pekerjaan online berikutnya harus diajukan selesai.';
    elsif v_current = 'completion_submitted'::public.job_progress_stage then
      raise exception 'Pekerjaan sudah diajukan selesai dan menunggu konfirmasi Customer.';
    elsif v_current <> 'working'::public.job_progress_stage then
      raise exception 'Tahap progres tidak sesuai untuk pekerjaan online.';
    end if;
  else
    v_current := coalesce(
      v_current,
      'heading_to_location'::public.job_progress_stage
    );

    if v_current = 'heading_to_location'::public.job_progress_stage
       and p_progress_stage <> 'arrived'::public.job_progress_stage then
      raise exception 'Tahap berikutnya harus menandai Mitra sudah tiba / mencapai titik awal.';
    elsif v_current = 'arrived'::public.job_progress_stage
       and p_progress_stage <> 'working'::public.job_progress_stage then
      raise exception 'Tahap berikutnya harus memulai pengerjaan.';
    elsif v_current = 'working'::public.job_progress_stage
       and p_progress_stage <> 'completion_submitted'::public.job_progress_stage then
      raise exception 'Tahap berikutnya harus mengajukan pekerjaan selesai.';
    elsif v_current = 'completion_submitted'::public.job_progress_stage then
      raise exception 'Pekerjaan sudah diajukan selesai dan menunggu konfirmasi Customer.';
    end if;
  end if;

  v_default_description := case p_progress_stage
    when 'arrived'::public.job_progress_stage then
      case
        when v_work_mode = 'mobile'
          then 'Mitra sudah mencapai titik awal pekerjaan.'
        else 'Mitra sudah tiba di lokasi pekerjaan.'
      end
    when 'working'::public.job_progress_stage then
      case
        when v_work_mode = 'remote'
          then 'Mitra sedang mengerjakan pekerjaan secara online / jarak jauh.'
        when v_work_mode = 'mobile'
          then 'Pekerjaan mobilitas / perjalanan sedang berlangsung.'
        else 'Mitra mulai melaksanakan pekerjaan.'
      end
    when 'completion_submitted'::public.job_progress_stage then
      'Mitra telah menyelesaikan pekerjaan dan menunggu konfirmasi Customer.'
    else 'Progres pekerjaan diperbarui.'
  end;

  update public.jobs
  set progress_stage = p_progress_stage
  where id = p_job_id;

  insert into public.job_timelines (
    job_id,
    status,
    progress_stage,
    description,
    evidence_url
  ) values (
    p_job_id,
    'on_progress'::public.job_status,
    p_progress_stage,
    coalesce(nullif(trim(p_note), ''), v_default_description),
    nullif(trim(p_evidence_url), '')
  );
end;
$$;

revoke all on function public.advance_job_progress(
  uuid,
  public.job_progress_stage,
  text,
  text
) from public;
grant execute on function public.advance_job_progress(
  uuid,
  public.job_progress_stage,
  text,
  text
) to authenticated;


-- ---------------------------------------------------------------------------
-- 5. Keep Auto Complete aligned with the new mandatory-payment rule.
--    The cron worker must ignore jobs whose payment method is not selected or
--    whose payment has not been finalized yet.
-- ---------------------------------------------------------------------------
alter table public.business_settings
  add column if not exists auto_complete_hours integer not null default 24;

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
      s.submitted_at,
      p.provider,
      p.cash_confirmed_at,
      p.paid_at,
      case
        when coalesce(p.provider, '') = 'cash' then
          greatest(
            s.submitted_at,
            coalesce(p.cash_confirmed_at, p.paid_at, s.submitted_at)
          )
        else s.submitted_at
      end as eligible_since
    from public.jobs j
    join lateral (
      select max(t.created_at) as submitted_at
      from public.job_timelines t
      where t.job_id = j.id
        and t.progress_stage = 'completion_submitted'::public.job_progress_stage
    ) s on s.submitted_at is not null
    join public.payments p
      on p.job_id = j.id
    where j.status = 'on_progress'::public.job_status
      and j.progress_stage = 'completion_submitted'::public.job_progress_stage
      and coalesce(p.payment_required, false) = true
      and p.status = 'paid'::public.payment_status
      and (
        case
          when coalesce(p.provider, '') = 'cash' then
            greatest(
              s.submitted_at,
              coalesce(p.cash_confirmed_at, p.paid_at, s.submitted_at)
            )
          else s.submitted_at
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

    perform public.ensure_completed_job_earning(v_job.id);
    v_completed := v_completed + 1;
  end loop;

  return v_completed;
end;
$$;

revoke all on function public.auto_complete_stale_jobs()
from public, anon, authenticated;
grant execute on function public.auto_complete_stale_jobs() to service_role;

-- ---------------------------------------------------------------------------
-- 6. Completion guard. A job can never become completed without a selected
--    and finalized payment. This also repairs the old loophole where a Mitra
--    could submit completion before Customer picked any payment method.
-- ---------------------------------------------------------------------------
create or replace function public.guard_job_completion_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_required boolean;
  v_payment_status public.payment_status;
begin
  if new.status = 'completed'::public.job_status
     and old.status is distinct from new.status then
    select p.payment_required, p.status
      into v_payment_required, v_payment_status
    from public.payments p
    where p.job_id = new.id;

    if not found or coalesce(v_payment_required, false) = false then
      raise exception 'Pilih metode pembayaran sebelum menyelesaikan pekerjaan.';
    end if;

    if v_payment_status <> 'paid'::public.payment_status then
      raise exception 'Pembayaran harus selesai sebelum pekerjaan dapat dikonfirmasi selesai.';
    end if;
  end if;

  return new;
end;
$$;

-- Supersedes the Cash-only guard from the previous migration.
drop trigger if exists trg_guard_cash_job_completion on public.jobs;
drop trigger if exists trg_guard_job_completion_payment on public.jobs;
create trigger trg_guard_job_completion_payment
before update of status on public.jobs
for each row execute function public.guard_job_completion_payment();

commit;
