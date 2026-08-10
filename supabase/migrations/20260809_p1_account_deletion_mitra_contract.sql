-- =============================================================================
-- AYO SURUH - P1 ACCOUNT DELETION / EXIT SURVEY + MITRA CONTRACT VERSIONING
-- =============================================================================
-- Catatan desain:
-- 1. Data transaksi historis tetap memakai UUID public.users sebagai tombstone.
-- 2. Auth identity dihapus oleh Edge Function setelah data personal dianonimkan.
-- 3. Karena itu FK public.users -> auth.users dilepas, sedangkan relasi bisnis ke
--    public.users tetap dipertahankan agar riwayat transaksi tidak rusak.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Lifecycle akun dan exit survey
-- -----------------------------------------------------------------------------
alter table public.users
  add column if not exists account_state text not null default 'active'
    check (account_state in ('active', 'deactivated', 'deleted')),
  add column if not exists deactivated_at timestamp with time zone,
  add column if not exists deleted_at timestamp with time zone;

-- public.users berfungsi sebagai profil/tombstone transaksi. Auth identity dapat
-- dihapus tanpa menghapus row historis public.users.
alter table public.users
  drop constraint if exists users_id_fkey;

create table if not exists public.account_exit_surveys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  action text not null check (action in ('deactivate', 'delete')),
  reason_code text,
  reason_label text,
  note text,
  role_snapshot text not null default 'customer',
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create index if not exists account_exit_surveys_user_idx
  on public.account_exit_surveys(user_id, created_at desc);

alter table public.account_exit_surveys enable row level security;

drop policy if exists "ayo_exit_survey_read_own" on public.account_exit_surveys;
create policy "ayo_exit_survey_read_own"
on public.account_exit_surveys for select
to authenticated
using (user_id = auth.uid());

grant select on public.account_exit_surveys to authenticated;

create or replace function public.get_account_deletion_readiness()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_is_admin boolean := false;
  v_is_mitra boolean := false;
  v_active_jobs integer := 0;
  v_active_refunds integer := 0;
  v_active_payouts integer := 0;
  v_pending numeric := 0;
  v_available numeric := 0;
  v_held numeric := 0;
  v_can_deactivate boolean;
  v_can_delete boolean;
  v_blockers text[] := array[]::text[];
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  select exists (
    select 1 from public.admin_users a
    where a.user_id = v_user_id and coalesce(a.is_active, false) = true
  ) into v_is_admin;

  select exists (
    select 1 from public.mitras m where m.id = v_user_id
  ) into v_is_mitra;

  select count(*)::integer
  into v_active_jobs
  from public.jobs j
  where (j.customer_id = v_user_id or j.mitra_id = v_user_id)
    and j.status::text in ('posted', 'waiting_bid', 'accepted', 'on_progress');

  select count(*)::integer
  into v_active_refunds
  from public.refund_requests r
  where (
      r.customer_id = v_user_id
      or exists (
        select 1 from public.jobs j
        where j.id = r.job_id and j.mitra_id = v_user_id
      )
    )
    and r.status in ('requested', 'processing', 'manual_review', 'failed');

  if v_is_mitra then
    select count(*)::integer
    into v_active_payouts
    from public.payout_requests p
    where p.mitra_id = v_user_id
      and p.status in ('requested', 'under_review', 'approved', 'processing');

    select
      coalesce(sum(l.amount) filter (
        where l.bucket = 'pending' and l.state = 'posted'
      ), 0),
      coalesce(sum(l.amount) filter (
        where l.bucket = 'available' and l.state = 'posted'
      ), 0),
      coalesce(sum(l.amount) filter (
        where l.bucket = 'held' and l.state = 'posted'
      ), 0)
    into v_pending, v_available, v_held
    from public.mitra_wallet_ledger l
    where l.mitra_id = v_user_id;
  end if;

  if v_is_admin then
    v_blockers := array_append(v_blockers, 'Akun admin aktif tidak dapat dihapus dari aplikasi.');
  end if;
  if v_active_jobs > 0 then
    v_blockers := array_append(v_blockers, 'Masih ada pekerjaan aktif yang harus diselesaikan atau dibatalkan.');
  end if;
  if v_active_refunds > 0 then
    v_blockers := array_append(v_blockers, 'Masih ada refund/dispute yang belum selesai.');
  end if;
  if v_active_payouts > 0 then
    v_blockers := array_append(v_blockers, 'Masih ada pencairan Mitra yang sedang diproses.');
  end if;

  v_can_deactivate := not v_is_admin
    and v_active_jobs = 0
    and v_active_refunds = 0
    and v_active_payouts = 0;

  if abs(v_pending) > 0.005 or abs(v_available) > 0.005 or abs(v_held) > 0.005 then
    v_blockers := array_append(
      v_blockers,
      'Saldo Mitra harus Rp0 sebelum akun dapat dihapus permanen.'
    );
  end if;

  v_can_delete := v_can_deactivate
    and abs(v_pending) <= 0.005
    and abs(v_available) <= 0.005
    and abs(v_held) <= 0.005;

  return jsonb_build_object(
    'can_deactivate', v_can_deactivate,
    'can_delete', v_can_delete,
    'is_admin', v_is_admin,
    'is_mitra', v_is_mitra,
    'active_jobs', v_active_jobs,
    'active_refunds', v_active_refunds,
    'active_payouts', v_active_payouts,
    'wallet_pending', v_pending,
    'wallet_available', v_available,
    'wallet_held', v_held,
    'blockers', to_jsonb(v_blockers)
  );
end;
$$;

revoke all on function public.get_account_deletion_readiness() from public, anon;
grant execute on function public.get_account_deletion_readiness() to authenticated;

create or replace function public.deactivate_my_account(
  p_reason_code text default null,
  p_reason_label text default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_readiness jsonb;
  v_role text := 'customer';
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  v_readiness := public.get_account_deletion_readiness();
  if not coalesce((v_readiness ->> 'can_deactivate')::boolean, false) then
    raise exception 'Akun belum dapat dinonaktifkan. Selesaikan aktivitas yang masih berjalan terlebih dahulu.';
  end if;

  if exists (select 1 from public.mitras m where m.id = v_user_id) then
    v_role := 'mitra';
  end if;

  insert into public.account_exit_surveys(
    user_id, action, reason_code, reason_label, note, role_snapshot
  ) values (
    v_user_id,
    'deactivate',
    nullif(trim(coalesce(p_reason_code, '')), ''),
    nullif(trim(coalesce(p_reason_label, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_role
  );

  update public.users
  set account_state = 'deactivated',
      deactivated_at = timezone('utc'::text, now())
  where id = v_user_id;

  update public.mitras
  set is_active = false
  where id = v_user_id;

  delete from public.device_tokens where user_id = v_user_id;
end;
$$;

revoke all on function public.deactivate_my_account(text, text, text) from public, anon;
grant execute on function public.deactivate_my_account(text, text, text) to authenticated;

create or replace function public.reactivate_my_account()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_state text;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  select u.account_state into v_state
  from public.users u
  where u.id = v_user_id;

  if v_state = 'deleted' then
    raise exception 'Akun ini sudah dihapus.';
  end if;

  if v_state = 'deactivated' then
    update public.users
    set account_state = 'active', deactivated_at = null
    where id = v_user_id;

    if exists (
      select 1
      from public.mitra_applications a
      where a.user_id = v_user_id
        and a.status = 'approved'::public.application_status
    ) then
      update public.mitras set is_active = true where id = v_user_id;
    end if;
    return true;
  end if;

  return false;
end;
$$;

revoke all on function public.reactivate_my_account() from public, anon;
grant execute on function public.reactivate_my_account() to authenticated;

-- Dipanggil hanya dari Edge Function dengan JWT user yang sedang login.
create or replace function public.prepare_my_account_deletion(
  p_reason_code text default null,
  p_reason_label text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_readiness jsonb;
  v_role text := 'customer';
  v_paths jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  v_readiness := public.get_account_deletion_readiness();
  if not coalesce((v_readiness ->> 'can_delete')::boolean, false) then
    raise exception 'Akun belum dapat dihapus. Selesaikan pekerjaan, refund, pencairan, dan saldo terlebih dahulu.';
  end if;

  if exists (select 1 from public.mitras m where m.id = v_user_id) then
    v_role := 'mitra';
  end if;

  select coalesce(jsonb_agg(path), '[]'::jsonb)
  into v_paths
  from (
    select d.ktm as path
    from public.mitra_documents d
    join public.mitra_applications a on a.id = d.application_id
    where a.user_id = v_user_id and nullif(trim(coalesce(d.ktm, '')), '') is not null
    union all
    select d.selfie as path
    from public.mitra_documents d
    join public.mitra_applications a on a.id = d.application_id
    where a.user_id = v_user_id and nullif(trim(coalesce(d.selfie, '')), '') is not null
  ) paths;

  insert into public.account_exit_surveys(
    user_id, action, reason_code, reason_label, note, role_snapshot
  ) values (
    v_user_id,
    'delete',
    nullif(trim(coalesce(p_reason_code, '')), ''),
    nullif(trim(coalesce(p_reason_label, '')), ''),
    nullif(trim(coalesce(p_note, '')), ''),
    v_role
  );

  delete from public.device_tokens where user_id = v_user_id;
  delete from public.notifications where user_id = v_user_id;

  update public.addresses
  set label = 'Alamat dihapus',
      address = 'Data alamat telah dihapus oleh pengguna',
      latitude = null,
      longitude = null,
      is_default = false
  where user_id = v_user_id;

  update public.mitra_documents d
  set ktm = null,
      selfie = null,
      verified = false,
      updated_at = timezone('utc'::text, now())
  from public.mitra_applications a
  where d.application_id = a.id
    and a.user_id = v_user_id;

  update public.mitra_applications
  set address = 'Data alamat telah dihapus oleh pengguna',
      bank_name = null,
      account_number = null,
      updated_at = timezone('utc'::text, now())
  where user_id = v_user_id;

  delete from public.mitra_bank_accounts where mitra_id = v_user_id;
  update public.mitra_services set is_active = false where mitra_id = v_user_id;
  update public.mitras set is_active = false where id = v_user_id;

  update public.users
  set email = null,
      fullname = 'Pengguna Dihapus',
      phone = null,
      avatar_url = null,
      alamat = null,
      account_state = 'deleted',
      deleted_at = timezone('utc'::text, now()),
      deactivated_at = null
  where id = v_user_id;

  return jsonb_build_object(
    'ok', true,
    'user_id', v_user_id,
    'mitra_document_paths', v_paths
  );
end;
$$;

revoke all on function public.prepare_my_account_deletion(text, text, text) from public, anon;
grant execute on function public.prepare_my_account_deletion(text, text, text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Kontrak / MoU Mitra berversi
-- -----------------------------------------------------------------------------
create table if not exists public.mitra_contract_versions (
  version text primary key,
  title text not null,
  content text not null,
  is_active boolean not null default false,
  effective_at timestamp with time zone not null,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create unique index if not exists mitra_contract_one_active_idx
  on public.mitra_contract_versions(is_active)
  where is_active = true;

create table if not exists public.mitra_contract_acceptances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  contract_version text not null references public.mitra_contract_versions(version),
  accepted_at timestamp with time zone not null default timezone('utc'::text, now()),
  client_platform text,
  unique(user_id, contract_version)
);

create index if not exists mitra_contract_acceptance_user_idx
  on public.mitra_contract_acceptances(user_id, accepted_at desc);

alter table public.mitra_contract_versions enable row level security;
alter table public.mitra_contract_acceptances enable row level security;

drop policy if exists "ayo_mitra_contract_read_active" on public.mitra_contract_versions;
create policy "ayo_mitra_contract_read_active"
on public.mitra_contract_versions for select
to authenticated
using (is_active = true);

drop policy if exists "ayo_mitra_contract_acceptance_read_own" on public.mitra_contract_acceptances;
create policy "ayo_mitra_contract_acceptance_read_own"
on public.mitra_contract_acceptances for select
to authenticated
using (user_id = auth.uid());

grant select on public.mitra_contract_versions to authenticated;
grant select on public.mitra_contract_acceptances to authenticated;

insert into public.mitra_contract_versions(
  version, title, content, is_active, effective_at
) values (
  '1.0',
  'Kontrak Kemitraan Ayo Suruh',
  $contract$
KONTRAK KEMITRAAN AYO SURUH — VERSI 1.0

1. Status Kemitraan
Mitra adalah pengguna independen yang menawarkan keterampilan/jasa melalui platform Ayo Suruh. Persetujuan ini tidak membentuk hubungan kerja, kepegawaian, atau agensi antara Mitra dan Ayo Suruh.

2. Kebenaran Data dan Verifikasi
Mitra wajib memberikan identitas, KTM, selfie, lokasi, dan informasi rekening yang benar serta masih berlaku. Pemalsuan data dapat menyebabkan penolakan, pembekuan, atau penghentian akses Mitra.

3. Standar Layanan
Mitra wajib menjalankan pekerjaan sesuai deskripsi yang disepakati, menjaga komunikasi yang sopan, hadir sesuai kesepakatan, menjaga keamanan, serta tidak melakukan tindakan yang melanggar hukum atau merugikan Customer.

4. Harga, Pembayaran, dan Biaya Platform
Harga pekerjaan mengikuti penawaran/kesepakatan pada aplikasi. Untuk transaksi yang menggunakan pembayaran platform, Ayo Suruh dapat mengenakan biaya platform sesuai informasi yang ditampilkan pada aplikasi. Pada versi layanan saat ini, acuan biaya platform adalah 6% dan dapat diperbarui secara transparan pada versi ketentuan berikutnya.

5. Pencairan dan Dana Tertahan
Pendapatan Mitra dapat melalui status pending, tersedia, ditahan, atau dicairkan. Dana dapat ditahan sementara jika terdapat pekerjaan aktif, refund/dispute, pemeriksaan transaksi, atau proses pencairan yang belum selesai.

6. Pembatalan, Refund, dan Dispute
Mitra memahami bahwa transaksi tertentu dapat dibatalkan atau direfund sesuai status pekerjaan, bukti transaksi, dan hasil peninjauan. Jika pendapatan sudah tercatat lalu transaksi direfund, penyesuaian ledger dapat dilakukan sesuai alur yang tampil pada aplikasi.

7. Data Customer dan Kerahasiaan
Mitra hanya boleh menggunakan alamat, nomor kontak, chat, dan data Customer untuk menyelesaikan pekerjaan terkait. Data tersebut tidak boleh disebarkan, dijual, atau digunakan untuk tujuan lain tanpa izin yang sah.

8. Perilaku yang Dilarang
Mitra dilarang melakukan penipuan, intimidasi, transaksi fiktif, manipulasi rating, penyalahgunaan data pribadi, pengalihan pembayaran yang melanggar kebijakan platform, atau tindakan lain yang membahayakan pengguna maupun reputasi layanan.

9. Penangguhan dan Pengakhiran Kemitraan
Ayo Suruh dapat menangguhkan akses Mitra ketika terdapat dugaan pelanggaran, kewajiban transaksi yang belum selesai, atau kebutuhan pemeriksaan. Mitra dapat menghapus akun setelah pekerjaan aktif, refund/dispute, pencairan, dan saldo yang diwajibkan telah diselesaikan.

10. Persetujuan Elektronik dan Perubahan Versi
Dengan mencentang persetujuan dan mengirim pengajuan, Mitra menyatakan telah membaca serta menyetujui kontrak versi yang tampil. Waktu persetujuan dicatat oleh sistem. Jika kontrak berubah secara material, Ayo Suruh dapat meminta persetujuan terhadap versi baru.

Catatan: dokumen elektronik ini merupakan persetujuan operasional penggunaan platform Ayo Suruh dan bukan pengganti konsultasi hukum atau dokumen e-signature formal apabila di kemudian hari dibutuhkan untuk penggunaan komersial penuh.
  $contract$,
  false,
  timezone('utc'::text, now())
)
on conflict (version) do update
set title = excluded.title,
    content = excluded.content,
    effective_at = excluded.effective_at;

update public.mitra_contract_versions
set is_active = false
where is_active = true;

update public.mitra_contract_versions
set is_active = true
where version = '1.0';

create or replace function public.get_active_mitra_contract()
returns table (
  version text,
  title text,
  content text,
  effective_at timestamp with time zone
)
language sql
security definer
set search_path = public
as $$
  select c.version, c.title, c.content, c.effective_at
  from public.mitra_contract_versions c
  where c.is_active = true
  order by c.effective_at desc
  limit 1;
$$;

revoke all on function public.get_active_mitra_contract() from public, anon;
grant execute on function public.get_active_mitra_contract() to authenticated;

create or replace function public.accept_active_mitra_contract(
  p_contract_version text,
  p_client_platform text default null
)
returns timestamp with time zone
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_accepted_at timestamp with time zone;
begin
  if v_user_id is null then
    raise exception 'Pengguna belum login.';
  end if;

  if not exists (
    select 1 from public.mitra_contract_versions c
    where c.version = trim(p_contract_version)
      and c.is_active = true
  ) then
    raise exception 'Versi kontrak Mitra tidak aktif atau tidak ditemukan.';
  end if;

  insert into public.mitra_contract_acceptances(
    user_id, contract_version, accepted_at, client_platform
  ) values (
    v_user_id,
    trim(p_contract_version),
    timezone('utc'::text, now()),
    nullif(trim(coalesce(p_client_platform, '')), '')
  )
  on conflict (user_id, contract_version) do update
  set accepted_at = excluded.accepted_at,
      client_platform = excluded.client_platform
  returning accepted_at into v_accepted_at;

  return v_accepted_at;
end;
$$;

revoke all on function public.accept_active_mitra_contract(text, text) from public, anon;
grant execute on function public.accept_active_mitra_contract(text, text) to authenticated;

create or replace function public.get_my_active_mitra_contract_acceptance()
returns table (
  contract_version text,
  accepted_at timestamp with time zone
)
language sql
security definer
set search_path = public
as $$
  select a.contract_version, a.accepted_at
  from public.mitra_contract_acceptances a
  join public.mitra_contract_versions c on c.version = a.contract_version
  where a.user_id = auth.uid() and c.is_active = true
  order by a.accepted_at desc
  limit 1;
$$;

revoke all on function public.get_my_active_mitra_contract_acceptance() from public, anon;
grant execute on function public.get_my_active_mitra_contract_acceptance() to authenticated;

create or replace function public.enforce_mitra_contract_on_application()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_should_check boolean := false;
begin
  if new.status = 'applied'::public.application_status then
    if tg_op = 'INSERT' then
      v_should_check := true;
    elsif tg_op = 'UPDATE' then
      v_should_check := old.status is distinct from new.status;
    end if;
  end if;

  if v_should_check and not exists (
    select 1
    from public.mitra_contract_acceptances a
    join public.mitra_contract_versions c on c.version = a.contract_version
    where a.user_id = new.user_id
      and c.is_active = true
  ) then
    raise exception 'Kontrak/MoU Mitra aktif wajib disetujui sebelum pengajuan dikirim.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_mitra_contract_on_application
on public.mitra_applications;
create trigger trg_enforce_mitra_contract_on_application
before insert or update of status on public.mitra_applications
for each row execute function public.enforce_mitra_contract_on_application();

-- Admin dapat melihat bukti versi dan waktu persetujuan kontrak pada antrean Mitra.
drop function if exists public.admin_list_mitra_applications();
create function public.admin_list_mitra_applications()
returns table (
  application_id uuid,
  user_id uuid,
  fullname text,
  email text,
  phone text,
  address text,
  description text,
  bank_name text,
  account_number text,
  status text,
  created_at timestamp with time zone,
  ktm_url text,
  selfie_url text,
  contract_version text,
  contract_accepted_at timestamp with time zone
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_current_user_admin() then
    raise exception 'Akses admin ditolak.';
  end if;

  return query
  select
    a.id,
    a.user_id,
    u.fullname,
    u.email,
    u.phone,
    a.address,
    a.description,
    a.bank_name,
    a.account_number,
    a.status::text,
    a.created_at,
    d.ktm,
    d.selfie,
    ca.contract_version,
    ca.accepted_at
  from public.mitra_applications a
  join public.users u on u.id = a.user_id
  left join lateral (
    select docs.ktm, docs.selfie
    from public.mitra_documents docs
    where docs.application_id = a.id
    order by docs.created_at desc
    limit 1
  ) d on true
  left join lateral (
    select acceptance.contract_version, acceptance.accepted_at
    from public.mitra_contract_acceptances acceptance
    where acceptance.user_id = a.user_id
    order by acceptance.accepted_at desc
    limit 1
  ) ca on true
  order by
    case when a.status = 'applied'::public.application_status then 0 else 1 end,
    a.created_at desc;
end;
$$;

revoke all on function public.admin_list_mitra_applications() from public;
grant execute on function public.admin_list_mitra_applications() to authenticated;

commit;
