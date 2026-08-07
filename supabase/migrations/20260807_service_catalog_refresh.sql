-- Ayo Suruh - Refresh Katalog Layanan
-- Kategori lama tidak dihapus agar job historis tetap valid. Kategori yang tidak
-- lagi ditampilkan cukup dinonaktifkan melalui is_active.

begin;

alter table public.categories
  add column if not exists is_active boolean not null default true,
  add column if not exists sort_order integer not null default 100;

-- Kategori yang secara eksplisit tidak lagi menjadi kategori utama.
update public.categories
set is_active = false
where lower(name) in (lower('Kebersihan'), lower('Perbaikan AC'));

-- Upsert berdasarkan nama secara case-insensitive dengan menjaga id kategori lama.
-- Karena schema awal belum memiliki unique lower(name), gunakan pola update + insert.
update public.categories set icon = 'electrical_services', is_active = true, sort_order = 10
where lower(name) = lower('Elektronik');
insert into public.categories (name, icon, is_active, sort_order)
select 'Elektronik', 'electrical_services', true, 10
where not exists (select 1 from public.categories where lower(name) = lower('Elektronik'));

update public.categories set icon = 'commute', is_active = true, sort_order = 20
where lower(name) = lower('Antar-Jemput');
insert into public.categories (name, icon, is_active, sort_order)
select 'Antar-Jemput', 'commute', true, 20
where not exists (select 1 from public.categories where lower(name) = lower('Antar-Jemput'));

update public.categories set icon = 'shopping_bag', is_active = true, sort_order = 30
where lower(name) = lower('Jasa Titip');
insert into public.categories (name, icon, is_active, sort_order)
select 'Jasa Titip', 'shopping_bag', true, 30
where not exists (select 1 from public.categories where lower(name) = lower('Jasa Titip'));

update public.categories set icon = 'apartment', is_active = true, sort_order = 40
where lower(name) = lower('Survey & Informasi Kost');
insert into public.categories (name, icon, is_active, sort_order)
select 'Survey & Informasi Kost', 'apartment', true, 40
where not exists (select 1 from public.categories where lower(name) = lower('Survey & Informasi Kost'));

update public.categories set icon = 'description', is_active = true, sort_order = 50
where lower(name) = lower('Administrasi');
insert into public.categories (name, icon, is_active, sort_order)
select 'Administrasi', 'description', true, 50
where not exists (select 1 from public.categories where lower(name) = lower('Administrasi'));

update public.categories set icon = 'code', is_active = true, sort_order = 60
where lower(name) = lower('Design & Coding');
insert into public.categories (name, icon, is_active, sort_order)
select 'Design & Coding', 'code', true, 60
where not exists (select 1 from public.categories where lower(name) = lower('Design & Coding'));

update public.categories set icon = 'home_repair_service', is_active = true, sort_order = 70
where lower(name) = lower('Rumah Tangga');
insert into public.categories (name, icon, is_active, sort_order)
select 'Rumah Tangga', 'home_repair_service', true, 70
where not exists (select 1 from public.categories where lower(name) = lower('Rumah Tangga'));

update public.categories set icon = 'two_wheeler', is_active = true, sort_order = 80
where lower(name) = lower('Otomotif');
insert into public.categories (name, icon, is_active, sort_order)
select 'Otomotif', 'two_wheeler', true, 80
where not exists (select 1 from public.categories where lower(name) = lower('Otomotif'));

-- Kategori lama yang masih berguna tetap aktif.
update public.categories
set is_active = true, sort_order = 90
where lower(name) = lower('Kurir');

update public.categories
set is_active = true, sort_order = 100
where lower(name) = lower('Tukang');

update public.categories
set is_active = true, sort_order = 999
where lower(name) = lower('Lainnya');

commit;
