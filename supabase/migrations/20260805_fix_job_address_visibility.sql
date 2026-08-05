-- AyoSuruh: memperbaiki alamat pekerjaan yang tidak terlihat oleh mitra.
-- Penyebab: policy lama public.addresses hanya mengizinkan pemilik alamat
-- membaca row alamatnya sendiri. Nested relation jobs -> addresses akhirnya
-- dikembalikan null untuk akun mitra meskipun job dan koordinat dapat dibaca.

alter table public.addresses enable row level security;

-- Pertahankan policy pemilik alamat yang sudah ada. Policy berikut menambah
-- akses baca hanya untuk alamat yang memang terkait dengan job relevan.
drop policy if exists "ayo_addresses_read_job_relevant" on public.addresses;
create policy "ayo_addresses_read_job_relevant"
on public.addresses
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.jobs j
    where j.address_id = addresses.id
      and (
        -- Customer pemilik job.
        j.customer_id = auth.uid()

        -- Mitra yang sudah dipilih tetap dapat melihat alamat sampai riwayat.
        or j.mitra_id = auth.uid()

        -- Mitra aktif dapat melihat alamat job yang masih terbuka.
        or (
          j.status in (
            'posted'::public.job_status,
            'waiting_bid'::public.job_status
          )
          and exists (
            select 1
            from public.mitras m
            where m.id = auth.uid()
              and m.is_active = true
          )
        )
      )
  )
);

comment on policy "ayo_addresses_read_job_relevant" on public.addresses is
  'Customer, mitra terpilih, dan mitra aktif pada job terbuka dapat membaca alamat job terkait.';
