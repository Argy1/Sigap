# Proyek: Aplikasi Panggilan Darurat Ambulans — Studi Kasus Kota Bogor

Tugas akhir mata kuliah Sistem Informasi Geografis, D4 Teknologi Rekayasa Perangkat Lunak, Sekolah Vokasi IPB University. Dikerjakan dengan pendekatan production-grade karena ada rencana pengembangan lanjutan pasca-kuliah.

## Masalah yang diselesaikan

Saat kondisi darurat medis, keluarga sering panik dan sulit menyebutkan lokasi akurat lewat telepon. Aplikasi ini menyediakan tombol panggilan darurat satu sentuh: lokasi terkirim otomatis ke rumah sakit terdekat, ambulans diarahkan tanpa pasien perlu menyebutkan alamat.

## Cakupan wilayah

Kota Bogor (scope awal).

## Arsitektur — Monorepo

```
/
├── apps/
│   ├── patient/          # Flutter — App Pasien
│   ├── driver/           # Flutter — App Sopir Ambulans
│   └── web-dashboard/    # Next.js — Dashboard RS & Admin
├── packages/
│   └── mobile-core/      # Flutter package bersama: model data, API client, tema, widget umum (dipakai oleh apps/patient dan apps/driver)
├── backend/              # Node.js + Express — REST API + WebSocket
├── design-reference/     # Referensi visual statis — BACA SEBELUM bikin UI apa pun
└── docs/
    └── project-charter.md
```

Gunakan **Melos** untuk mengelola workspace Flutter multi-package (`apps/patient`, `apps/driver`, `packages/mobile-core`).

## Tech Stack (SUDAH DIPUTUSKAN — jangan ganti tanpa alasan kuat)

| Bagian | Pilihan |
|---|---|
| Mobile (Pasien & Sopir) | Flutter, state management **Riverpod** |
| Web Dashboard | Next.js (App Router) + Tailwind CSS + shadcn/ui |
| Backend | Node.js + Express (TypeScript) |
| Database | PostgreSQL + ekstensi **PostGIS** |
| Hosting Backend & DB | Railway |
| Hosting Web | Vercel |
| Peta | Google Maps (`google_maps_flutter` di Flutter, `@vis.gl/react-google-maps` di web) |
| Realtime | Socket.io |
| Auth | JWT (access + refresh token) + bcrypt untuk password |

**Alasan pakai Railway + backend custom (bukan Supabase/Firebase)**: keputusan sadar untuk belajar membangun backend dari nol — autentikasi, RBAC, dan realtime dibangun manual, bukan pakai BaaS siap pakai.

## Desain — WAJIB baca `/design-reference/README.md` sebelum membuat komponen UI apa pun

Sistem desain bernama **"Dispatch Console"** — identitas visual khusus (bracket reticle lokasi + pulse-line EKG untuk status), BUKAN template UI generik. Semua keputusan warna, tipografi (Unbounded + Inter + JetBrains Mono), dan komponen kunci (tombol SOS, stepper status, readout data) sudah didesain dan dicontohkan sebagai file HTML statis di `/design-reference/`. Replikasi presisi visualnya ke Flutter widget dan komponen Next.js — jangan re-desain dari nol atau pakai Material Design default polos.

Kedua mode (gelap & terang) harus diimplementasikan di ketiga platform, dengan gelap sebagai default.

## Aktor & Role-Based Access Control

4 role: `patient`, `hospital_staff`, `driver`, `admin`. Tabel `profiles` (extend dari sistem auth) punya kolom `role` yang menentukan akses. RS dan Sopir keduanya terikat ke satu `hospital_id`.

## Skema Database (PostgreSQL + PostGIS)

Gunakan tipe `geography` (bukan sekadar kolom lat/long terpisah) untuk semua kolom lokasi, dan buat GiST index di atasnya.

```sql
-- profiles: extend auth, role-based
profiles (id uuid PK, role text, full_name text, phone text, created_at timestamptz)

-- patient_profiles: data medis, terpisah dari profiles
patient_profiles (profile_id uuid FK->profiles, blood_type text, allergies text, emergency_contact_name text, emergency_contact_phone text)

-- hospitals
hospitals (id uuid PK, name text, address text, location geography(Point,4326), phone text,
           verification_status text DEFAULT 'unverified', -- 'unverified' | 'verified'
           created_by uuid FK->profiles, created_at timestamptz)
-- index: create index hospitals_location_idx on hospitals using gist (location);

-- drivers: sopir, terikat ke satu RS
drivers (id uuid PK, profile_id uuid FK->profiles, hospital_id uuid FK->hospitals,
         availability_status text DEFAULT 'offline', -- 'available' | 'busy' | 'offline'
         current_location geography(Point,4326), vehicle_plate text)

-- emergency_calls: jantung sistem
emergency_calls (id uuid PK,
  patient_id uuid FK->profiles NULL,        -- nullable: guest mode SOS tanpa login
  hospital_id uuid FK->hospitals NULL,
  driver_id uuid FK->drivers NULL,
  patient_location geography(Point,4326) NOT NULL,  -- snapshot lokasi SAAT kejadian, bukan alamat rumah
  patient_address text,                     -- hasil reverse geocoding
  status text DEFAULT 'pending',            -- pending | confirmed | en_route | arrived | completed | cancelled
  condition_note text,
  created_at timestamptz, confirmed_at timestamptz, arrived_at timestamptz, completed_at timestamptz)
```

### Query inti: cari RS terdekat (strategi 2 tahap)

1. Filter cepat pakai PostGIS (`ORDER BY location <-> ST_MakePoint(:lng,:lat)::geography LIMIT 5`, hanya `verification_status = 'verified'`)
2. Refine 5 kandidat itu pakai Google Directions API (jarak tempuh jalan sebenarnya, bukan garis lurus) — dipanggil dari **Edge/serverless function di backend**, bukan langsung dari client (supaya API key aman & guest-mode SOS tetap bisa insert data tanpa auth).

Pola yang sama dipakai ulang untuk "cari sopir terdekat dalam satu RS" (filter `hospital_id` + `availability_status = 'available'`).

## Alur Inti (Golden Path) — implementasikan ini duluan sebelum fitur lain

1. Pasien tekan SOS (tahan tombol, bukan tap sekali — cegah trigger tidak sengaja) → lokasi GPS + reverse geocoding otomatis
2. Backend cari RS terdekat (algoritma di atas) → buat row `emergency_calls`
3. RS terpilih terima notifikasi realtime (Socket.io), lihat lokasi pasien di peta dashboard
4. Backend sarankan sopir terdekat/available di RS itu → staff RS konfirmasi (hybrid assignment, BUKAN full-otomatis atau full-manual)
5. Sopir terima notifikasi + rute ke lokasi pasien
6. Pasien pantau posisi live driver + ETA (Socket.io broadcast posisi)
7. Status berjalan: `pending → confirmed → en_route → arrived → completed`

## Fitur — Prioritas

**Must-have (implementasikan dulu, ini yang didemokan)**: alur SOS end-to-end di atas, guest mode (SOS tanpa login), profil medis pasien, registrasi mandiri RS + verifikasi admin ringan (non-blocking), 4 role dengan akses berbeda.

**Backlog (jangan dikerjakan dulu kecuali diminta eksplisit)**: riwayat panggilan detail, toggle status sopir granular, fallback RS kedua otomatis, notifikasi kontak darurat, statistik response time, heatmap cakupan layanan (buffer/isochrone analysis).

**Sengaja tidak dikerjakan**: chat real-time pasien-sopir, sistem pembayaran, multi-bahasa, rating/review RS, fitur "daftar ke RS tertentu" ala BPJS/Mobile JKN (bertentangan dengan prinsip "selalu cari RS terdekat").

## Konvensi Kode

- Identifier kode (variabel, fungsi, nama tabel/kolom) dalam **Bahasa Inggris**. Teks UI yang dilihat pengguna dalam **Bahasa Indonesia** (sesuai mockup di `/design-reference/`).
- Commit message: Conventional Commits (`feat:`, `fix:`, `chore:`, dll).
- Environment variables lewat `.env` (jangan pernah hardcode API key/secret), sediakan `.env.example` di tiap app/backend.
- Backend: struktur folder `src/routes/`, `src/middleware/` (auth.ts, rbac.ts), `src/controllers/`, `src/db/`, `src/sockets/`.

## Dokumen referensi lain

`/docs/project-charter.md` — tanggal, tim, budget (isi placeholder, tidak relevan untuk pengembangan teknis, boleh diabaikan Claude Code).
