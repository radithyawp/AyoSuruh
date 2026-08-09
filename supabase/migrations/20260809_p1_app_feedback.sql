-- AYO SURUH - In-app feedback / kritik & saran
-- Stores structured user feedback and exposes admin-only insight RPCs.

create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  role text not null check (role in ('customer', 'mitra', 'both')),
  ease_rating smallint not null check (ease_rating between 1 and 5),
  discoverability_rating smallint not null check (discoverability_rating between 1 and 5),
  ui_rating smallint not null check (ui_rating between 1 and 5),
  performance text not null check (
    performance in ('very_smooth', 'smooth', 'fair', 'slow', 'very_slow')
  ),
  trust_rating smallint not null check (trust_rating between 1 and 5),
  useful_features text[] not null default '{}'::text[],
  found_bug boolean not null default false,
  bug_details text,
  liked text,
  improvement text,
  nps smallint not null check (nps between 0 and 10),
  allow_followup boolean not null default false,
  contact text,
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists app_feedback_created_idx
  on public.app_feedback(created_at desc);
create index if not exists app_feedback_user_idx
  on public.app_feedback(user_id, created_at desc);
create index if not exists app_feedback_bug_idx
  on public.app_feedback(found_bug, created_at desc);

alter table public.app_feedback enable row level security;

drop policy if exists "ayo_feedback_read_own" on public.app_feedback;
create policy "ayo_feedback_read_own"
on public.app_feedback for select
to authenticated
using (auth.uid() = user_id);

grant select on public.app_feedback to authenticated;

create or replace function public.submit_app_feedback(
  p_role text,
  p_ease_rating integer,
  p_discoverability_rating integer,
  p_ui_rating integer,
  p_performance text,
  p_trust_rating integer,
  p_useful_features text[],
  p_found_bug boolean,
  p_bug_details text,
  p_liked text,
  p_improvement text,
  p_nps integer,
  p_allow_followup boolean,
  p_contact text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_id uuid;
  v_features text[];
begin
  if v_user_id is null then
    raise exception 'Silakan login kembali sebelum mengirim masukan.';
  end if;

  if p_role not in ('customer', 'mitra', 'both') then
    raise exception 'Role feedback tidak valid.';
  end if;

  if p_ease_rating not between 1 and 5
     or p_discoverability_rating not between 1 and 5
     or p_ui_rating not between 1 and 5
     or p_trust_rating not between 1 and 5 then
    raise exception 'Nilai rating harus berada pada rentang 1 sampai 5.';
  end if;

  if p_nps not between 0 and 10 then
    raise exception 'Nilai rekomendasi harus berada pada rentang 0 sampai 10.';
  end if;

  if p_performance not in ('very_smooth', 'smooth', 'fair', 'slow', 'very_slow') then
    raise exception 'Pilihan performa tidak valid.';
  end if;

  v_features := coalesce(
    array(
      select distinct left(trim(value), 80)
      from unnest(coalesce(p_useful_features, '{}'::text[])) value
      where trim(value) <> ''
      limit 12
    ),
    '{}'::text[]
  );

  if cardinality(v_features) = 0 then
    raise exception 'Pilih minimal satu fitur yang paling berguna.';
  end if;

  if coalesce(p_found_bug, false)
     and nullif(trim(coalesce(p_bug_details, '')), '') is null then
    raise exception 'Ceritakan bug yang kamu temukan.';
  end if;

  if nullif(trim(coalesce(p_liked, '')), '') is null
     or nullif(trim(coalesce(p_improvement, '')), '') is null then
    raise exception 'Isi bagian yang disukai dan yang perlu diperbaiki.';
  end if;

  if coalesce(p_allow_followup, false)
     and nullif(trim(coalesce(p_contact, '')), '') is null then
    raise exception 'Isi kontak jika kamu bersedia dihubungi.';
  end if;

  insert into public.app_feedback (
    user_id,
    role,
    ease_rating,
    discoverability_rating,
    ui_rating,
    performance,
    trust_rating,
    useful_features,
    found_bug,
    bug_details,
    liked,
    improvement,
    nps,
    allow_followup,
    contact
  ) values (
    v_user_id,
    p_role,
    p_ease_rating,
    p_discoverability_rating,
    p_ui_rating,
    p_performance,
    p_trust_rating,
    v_features,
    coalesce(p_found_bug, false),
    case
      when coalesce(p_found_bug, false)
        then left(nullif(trim(coalesce(p_bug_details, '')), ''), 700)
      else null
    end,
    left(trim(p_liked), 600),
    left(trim(p_improvement), 800),
    p_nps,
    coalesce(p_allow_followup, false),
    case
      when coalesce(p_allow_followup, false)
        then left(nullif(trim(coalesce(p_contact, '')), ''), 120)
      else null
    end
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_app_feedback(
  text, integer, integer, integer, text, integer, text[], boolean,
  text, text, text, integer, boolean, text
) from public;
grant execute on function public.submit_app_feedback(
  text, integer, integer, integer, text, integer, text[], boolean,
  text, text, text, integer, boolean, text
) to authenticated;

create or replace function public.admin_feedback_summary()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total bigint := 0;
  v_avg_ease numeric := 0;
  v_avg_discoverability numeric := 0;
  v_avg_ui numeric := 0;
  v_avg_trust numeric := 0;
  v_bug_reports bigint := 0;
  v_followup bigint := 0;
  v_promoters bigint := 0;
  v_detractors bigint := 0;
  v_top_feature text;
  v_recent_30d bigint := 0;
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin diperlukan.';
  end if;

  select
    count(*),
    coalesce(round(avg(ease_rating)::numeric, 2), 0),
    coalesce(round(avg(discoverability_rating)::numeric, 2), 0),
    coalesce(round(avg(ui_rating)::numeric, 2), 0),
    coalesce(round(avg(trust_rating)::numeric, 2), 0),
    count(*) filter (where found_bug),
    count(*) filter (where allow_followup),
    count(*) filter (where nps >= 9),
    count(*) filter (where nps <= 6),
    count(*) filter (where created_at >= now() - interval '30 days')
  into
    v_total,
    v_avg_ease,
    v_avg_discoverability,
    v_avg_ui,
    v_avg_trust,
    v_bug_reports,
    v_followup,
    v_promoters,
    v_detractors,
    v_recent_30d
  from public.app_feedback;

  select feature
  into v_top_feature
  from (
    select unnest(useful_features) as feature, count(*) as usage_count
    from public.app_feedback
    group by 1
    order by usage_count desc, feature asc
    limit 1
  ) ranked_features;

  return jsonb_build_object(
    'total_feedback', v_total,
    'recent_30d', v_recent_30d,
    'avg_ease', v_avg_ease,
    'avg_discoverability', v_avg_discoverability,
    'avg_ui', v_avg_ui,
    'avg_trust', v_avg_trust,
    'bug_reports', v_bug_reports,
    'followup_ok', v_followup,
    'nps_score', case
      when v_total = 0 then 0
      else round(100.0 * (v_promoters - v_detractors)::numeric / v_total, 1)
    end,
    'top_feature', v_top_feature
  );
end;
$$;

revoke all on function public.admin_feedback_summary() from public;
grant execute on function public.admin_feedback_summary() to authenticated;

create or replace function public.admin_list_feedback(p_limit integer default 100)
returns table (
  id uuid,
  user_id uuid,
  fullname text,
  email text,
  role text,
  ease_rating smallint,
  discoverability_rating smallint,
  ui_rating smallint,
  performance text,
  trust_rating smallint,
  useful_features text[],
  found_bug boolean,
  bug_details text,
  liked text,
  improvement text,
  nps smallint,
  allow_followup boolean,
  contact text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin diperlukan.';
  end if;

  return query
  select
    f.id,
    f.user_id,
    coalesce(u.fullname, 'Pengguna Dihapus') as fullname,
    coalesce(u.email, '-') as email,
    f.role,
    f.ease_rating,
    f.discoverability_rating,
    f.ui_rating,
    f.performance,
    f.trust_rating,
    f.useful_features,
    f.found_bug,
    f.bug_details,
    f.liked,
    f.improvement,
    f.nps,
    f.allow_followup,
    f.contact,
    f.created_at
  from public.app_feedback f
  left join public.users u on u.id = f.user_id
  order by f.created_at desc
  limit greatest(1, least(coalesce(p_limit, 100), 500));
end;
$$;

revoke all on function public.admin_list_feedback(integer) from public;
grant execute on function public.admin_list_feedback(integer) to authenticated;
