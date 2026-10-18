-- ============================================================
-- Klien 01 — Website Personal Agen Properti (Senten)
-- Migrasi 001: skema awal (11 tabel)
-- Cara pakai: tempel seluruh isi file ini ke Supabase Dashboard
-- > SQL Editor > New query > Run
-- ============================================================

-- 1. Agen
create table if not exists agents (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  foto_url text,
  tagline text,
  bio text,
  wa_numbers text[] not null default '{}',
  tiktok_url text,
  instagram_url text,
  facebook_url text,
  jam_operasional text,
  statistik jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- 2. Produk perumahan
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references agents(id) on delete cascade,
  nama text not null,
  slug text not null unique,
  lokasi text,
  alamat text,
  maps_url text,
  harga_mulai numeric,
  angsuran_mulai numeric,
  tipe text not null default 'subsidi' check (tipe in ('subsidi','komersil')),
  status text not null default 'ready' check (status in ('ready','indent','coming_soon','sold_out')),
  badge_promo text,
  deskripsi text,
  featured boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists products_agent_idx on products(agent_id);
create index if not exists products_featured_idx on products(featured) where featured;

-- 3. Galeri produk
create table if not exists product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  url text not null,
  caption text,
  urutan int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists product_images_product_idx on product_images(product_id, urutan);

-- 4. Spesifikasi produk (fleksibel per produk)
create table if not exists product_specs (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  kategori text,
  nama text not null,
  nilai text not null,
  urutan int not null default 0
);
create index if not exists product_specs_product_idx on product_specs(product_id, urutan);

-- 5. Fasilitas (kawasan & sekitar)
create table if not exists product_facilities (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  nama text not null,
  kategori text not null default 'kawasan' check (kategori in ('kawasan','sekitar')),
  jarak_menit int,
  urutan int not null default 0
);
create index if not exists product_facilities_product_idx on product_facilities(product_id, urutan);

-- 6. Promo per produk
create table if not exists product_promos (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  judul text not null,
  deskripsi text,
  syarat_ketentuan text,
  berlaku_sampai date,
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

-- 7. Testimoni
create table if not exists testimonials (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references agents(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  nama text not null,
  foto_url text,
  kutipan text not null,
  rating int check (rating between 1 and 5),
  tampil boolean not null default false,
  created_at timestamptz not null default now()
);

-- 8. Artikel
create table if not exists articles (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  judul text not null,
  cover_url text,
  isi text,
  published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now()
);

-- 9. FAQ (umum atau per produk)
create table if not exists faqs (
  id uuid primary key default gen_random_uuid(),
  product_id uuid references products(id) on delete cascade,
  pertanyaan text not null,
  jawaban text not null,
  urutan int not null default 0
);
create index if not exists faqs_product_idx on faqs(product_id, urutan);

-- 10. Leads (dari form cek kelayakan / kontak)
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  no_wa text not null,
  kebutuhan text not null default 'konsultasi' check (kebutuhan in ('beli','konsultasi','survei')),
  product_id uuid references products(id) on delete set null,
  pesan text,
  status text not null default 'baru' check (status in ('baru','dihubungi','deal','batal')),
  created_at timestamptz not null default now()
);
create index if not exists leads_status_idx on leads(status, created_at desc);

-- 11. Pengaturan situs
create table if not exists site_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

-- ============================================================
-- RLS: baca publik untuk konten, tulis hanya service role
-- (kunci anon hanya bisa SELECT; INSERT leads dibuka khusus)
-- ============================================================
alter table agents enable row level security;
alter table products enable row level security;
alter table product_images enable row level security;
alter table product_specs enable row level security;
alter table product_facilities enable row level security;
alter table product_promos enable row level security;
alter table testimonials enable row level security;
alter table articles enable row level security;
alter table faqs enable row level security;
alter table leads enable row level security;
alter table site_settings enable row level security;

-- Kebijakan baca publik
create policy "baca publik" on agents for select using (true);
create policy "baca publik" on products for select using (true);
create policy "baca publik" on product_images for select using (true);
create policy "baca publik" on product_specs for select using (true);
create policy "baca publik" on product_facilities for select using (true);
create policy "baca publik" on product_promos for select using (true);
create policy "baca publik" on testimonials for select using (tampil = true);
create policy "baca publik" on articles for select using (published = true);
create policy "baca publik" on faqs for select using (true);
create policy "baca publik" on site_settings for select using (true);

-- Form publik boleh INSERT leads (tanpa baca data leads lain)
create policy "insert leads publik" on leads for insert with check (true);

-- ============================================================
-- DATA AWAL: agen + 2 produk
-- ============================================================
insert into agents (nama, tagline, bio, wa_numbers, tiktok_url, instagram_url, facebook_url, jam_operasional, statistik)
values (
  'Senten Febrari Kadir Massa',
  'Bantu Anda punya rumah pertama di Kendari',
  'Agen properti di Kendari, fokus membantu keluarga muda, ASN, POLRI/TNI, dan karyawan memiliki rumah subsidi pertama dengan proses KPR yang dibantu sampai akad.',
  array['6282344319965','6285148223727'],
  'https://www.tiktok.com/@sentendi',
  'https://www.instagram.com/sentenfebrarikadirmassa',
  'https://www.facebook.com/share/1LmF5QMbNh/',
  'Senin–Sabtu, 08.00–20.00 WITA',
  '{"unit_terjual": 0, "pembeli_terbantu": 0, "tahun_pengalaman": 0}'::jsonb
) on conflict do nothing;
