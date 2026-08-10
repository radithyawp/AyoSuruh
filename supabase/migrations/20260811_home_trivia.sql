begin;

create table if not exists public.home_trivia (
  id uuid primary key default gen_random_uuid(),
  content text not null check (char_length(trim(content)) between 10 and 500),
  kind text not null default 'fact' check (kind in ('fact', 'trend')),
  source_url text,
  is_active boolean not null default true,
  sort_order integer not null default 100,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint home_trivia_expiry_check
    check (expires_at is null or expires_at > starts_at),
  constraint home_trivia_trend_source_check
    check (kind <> 'trend' or nullif(trim(source_url), '') is not null),
  constraint home_trivia_trend_expiry_check
    check (kind <> 'trend' or expires_at is not null)
);

create index if not exists home_trivia_active_order_idx
  on public.home_trivia (is_active, sort_order, created_at desc);

alter table public.home_trivia enable row level security;

drop policy if exists "authenticated users can read active home trivia"
  on public.home_trivia;
create policy "authenticated users can read active home trivia"
  on public.home_trivia
  for select
  to authenticated
  using (
    is_active = true
    and starts_at <= now()
    and (expires_at is null or expires_at > now())
  );

grant select on public.home_trivia to authenticated;

insert into public.home_trivia
  (id, content, kind, source_url, sort_order)
values
  (
    '0d88d620-33a8-4e50-9b5b-663426a1b201',
    'Fun fact: di Venus, satu hari justru lebih panjang daripada satu tahun. Planet ini butuh sekitar 243 hari Bumi untuk sekali berputar, sementara satu tahunnya sekitar 225 hari. Kalendernya saja bikin mikir dua kali.',
    'fact',
    'https://science.nasa.gov/venus/venus-facts/',
    10
  ),
  (
    '7f18db53-6dd8-40f7-a6ae-9fa763ee7d35',
    'Gurita punya tiga jantung dan darah berwarna biru. Hidupnya memang kelihatan santai, urusan sirkulasi ternyata niat banget.',
    'fact',
    'https://ocean.si.edu/ocean-life/invertebrates/octopuses-squids-and-relatives',
    20
  ),
  (
    'e5563fb2-69ea-4ab6-a73c-949f666c1502',
    'Hiu sudah berkeliaran di Bumi sebelum pohon modern muncul. Garis keturunannya sudah ada ratusan juta tahun—veteran banget kalau urusan bertahan hidup.',
    'fact',
    'https://www.smithsonianmag.com/smart-news/respect-sharks-are-older-than-trees-3818/',
    30
  ),
  (
    '991eb22e-2695-4f1f-b9c5-2715194218c8',
    'Sehari di Mars berlangsung sekitar 24 jam 39 menit. Nggak beda jauh dari Bumi, jadi kalau suatu hari pindah ke sana, jam tidurmu mungkin masih bisa dinego.',
    'fact',
    'https://science.nasa.gov/mars/facts/',
    40
  ),
  (
    '8297814f-b2b1-49ea-b58a-865a4ec35b7c',
    'Paus dan lumba-lumba nggak bisa benar-benar mematikan seluruh otaknya saat tidur karena mereka tetap harus naik ke permukaan untuk bernapas. Tidur pun tetap sambil kerja shift.',
    'fact',
    'https://ocean.si.edu/ocean-life/marine-mammals/whales',
    50
  )
on conflict (id) do update set
  content = excluded.content,
  kind = excluded.kind,
  source_url = excluded.source_url,
  sort_order = excluded.sort_order,
  updated_at = now();

commit;
