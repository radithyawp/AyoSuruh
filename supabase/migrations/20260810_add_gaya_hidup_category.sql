-- Ayo Suruh - Tambah kategori Gaya Hidup
-- Idempotent: aman dijalankan ulang.

begin;

update public.categories
set
  icon = 'self_improvement',
  is_active = true,
  sort_order = 75
where lower(name) = lower('Gaya Hidup');

insert into public.categories (name, icon, is_active, sort_order)
select 'Gaya Hidup', 'self_improvement', true, 75
where not exists (
  select 1
  from public.categories
  where lower(name) = lower('Gaya Hidup')
);

commit;
