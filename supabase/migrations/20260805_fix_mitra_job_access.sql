-- Memastikan hak akses pekerjaan mitra berdasarkan auth.uid(),
-- bukan semata-mata perbandingan ID di sisi Flutter.

create or replace function public.get_my_job_access(p_job_id uuid)
returns table (
  job_id uuid,
  job_status public.job_status,
  selected_mitra_id uuid,
  is_selected_mitra boolean,
  my_bid_status public.bid_status
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    j.id as job_id,
    j.status as job_status,
    j.mitra_id as selected_mitra_id,
    coalesce(j.mitra_id = auth.uid(), false) as is_selected_mitra,
    (
      select b.status
      from public.bids b
      where b.job_id = j.id
        and b.mitra_id = auth.uid()
      order by b.created_at desc
      limit 1
    ) as my_bid_status
  from public.jobs j
  where j.id = p_job_id
    and exists (
      select 1
      from public.mitras m
      where m.id = auth.uid()
    );
$$;

revoke all on function public.get_my_job_access(uuid) from public;
grant execute on function public.get_my_job_access(uuid) to authenticated;
