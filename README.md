# Aplikasi Panggilan Darurat Ambulans — Kota Bogor

Tugas akhir Sistem Informasi Geografis · D4 Teknologi Rekayasa Perangkat Lunak
· Sekolah Vokasi IPB University.

Saat kondisi darurat medis, keluarga sering panik dan sulit menyebutkan lokasi
akurat lewat telepon. Aplikasi ini menyediakan tombol panggilan darurat satu
sentuh: lokasi terkirim otomatis ke rumah sakit terdekat, dan ambulans diarahkan
tanpa pasien perlu menyebutkan alamat sama sekali.

---

## Isi repositori

```
apps/
  patient/          Flutter — App Pasien (7 layar)
  driver/           Flutter — App Sopir Ambulans (5 layar + Akun)
  web-dashboard/    Next.js — Dashboard RS & Panel Admin
packages/
  mobile-core/      Package Flutter bersama: sistem desain, model, API, realtime
backend/            Node.js + Express — REST API + Socket.io
design-reference/   Mockup HTML statis (referensi visual, bukan bagian aplikasi)
docs/               Project charter
```

---

## Menjalankan proyek

Prasyarat: **Node.js ≥ 20**, **Flutter ≥ 3.41** (Dart 3.11), dan Git.

### 1. Backend

```bash
cd backend
npm install
cp .env.example .env      # lalu isi DATABASE_URL
npm run migrate           # buat 6 tabel + index GiST
npm run seed              # 6 RS Kota Bogor + akun demo
npm run dev               # http://localhost:4000
```

Cek berjalan:

```bash
curl "http://localhost:4000/api/hospitals/nearest?lat=-6.5971&lng=106.8060"
```

### 2. Dashboard Web

```bash
cd apps/web-dashboard
npm install
cp .env.example .env.local
npm run dev               # http://localhost:3000
```

### 3. App Pasien & App Sopir

Dependensi ketiga package Flutter diselesaikan sekali dari root (pub workspace):

```bash
flutter pub get
```

Lalu:

```bash
cd apps/patient && flutter run --dart-define-from-file=env.json
cd apps/driver  && flutter run --dart-define-from-file=env.json
```

Sesuaikan `API_URL` di `env.json` masing-masing app:

| Target | Nilai `API_URL` |
|---|---|
| Emulator Android | `http://10.0.2.2:4000` (10.0.2.2 = localhost host) |
| Perangkat Android fisik | `http://<IP-LAN-komputer>:4000` |
| Chrome / desktop | `http://localhost:4000` |

Tersedia juga skrip Melos:

```bash
dart run melos run analyze     # analisis seluruh package Flutter
dart run melos run run:patient
dart run melos run run:driver
```

---

## Akun demo

Seluruh akun memakai kata sandi **`password123`**.

| Peran | Masuk lewat | Identitas |
|---|---|---|
| Pasien | App Pasien | `081234567890` (Budi Santoso) |
| Sopir | App Sopir | `081211110001` (Ahmad Ridwan, RSUD Kota Bogor) |
| Staff RS | Dashboard Web | `staff@rsudbogor.id` |
| Staff RS lain | Dashboard Web | `staff@rspmibogor.id` (untuk menguji isolasi antar-RS) |
| Admin platform | Dashboard Web | `admin@ambulans.id` |

Mode tamu tidak butuh akun sama sekali — tombol "MASUK MODE TAMU" di layar
pertama App Pasien.

---

## Alur inti (golden path)

1. Pasien menekan & **menahan** tombol SOS → lokasi GPS + reverse geocoding
2. Backend mencari RS terdekat (PostGIS KNN → refine jarak tempuh jalan) dan
   membuat baris `emergency_calls`
3. RS terpilih menerima notifikasi realtime di dashboard (Socket.io)
4. Backend menyarankan sopir terdekat yang tersedia → **staff RS memutuskan**
5. Sopir menerima notifikasi tugas + rute ke lokasi pasien
6. Pasien memantau posisi sopir bergerak secara langsung
7. Status berjalan: `pending → confirmed → en_route → arrived → completed`

---

## Verifikasi

```bash
# Backend: alur SOS lengkap lintas socket, termasuk mode tamu
cd backend && npm run test:goldenpath     # 30 pemeriksaan

# Backend: audit kebocoran akses antar RS / antar role
cd backend && npm run test:rbac           # 33 pemeriksaan

# Flutter: uji golden sistem desain + perilaku tombol SOS
cd packages/mobile-core && flutter test   # 13 uji, 8 di antaranya golden

# Dashboard
cd apps/web-dashboard && npm run build
```

Uji golden di `packages/mobile-core/test/goldens/` mengunci tampilan elemen
tanda tangan (bracket reticle, pulse stepper EKG, readout mono) di kedua mode
warna. Kalau tampilannya berubah, uji gagal — bukan lolos diam-diam. Perbarui
dengan sengaja lewat `flutter test --update-goldens`.

---

## Google Maps (opsional)

**Proyek ini berjalan penuh tanpa Google Maps API key.** Tanpa key:

| Kapabilitas | Perilaku tanpa key |
|---|---|
| Peta | `ConsoleMap` — peta skematik bergaya mockup, posisi pin tetap dari koordinat asli |
| Jarak & ETA | Haversine × 1.35 (koreksi jalan kota) @ 32 km/jam |
| Alamat pasien | `"Lokasi GPS -6.5971, 106.8060"` |

Ini bukan penurunan kualitas visual: mockup di `design-reference/` memang
menggambarkan peta bergaya konsol abstrak, bukan Google Maps.

Untuk mengaktifkan Google Maps sungguhan, aktifkan API berikut di Google Cloud
Console lalu isi key-nya — tidak ada kode yang perlu diubah:

| API | Dipakai di | Variabel |
|---|---|---|
| Distance Matrix | backend (refine RS/sopir terdekat) | `backend/.env` → `GOOGLE_MAPS_API_KEY` |
| Geocoding | backend (alamat pasien) | idem |
| Maps JavaScript | dashboard web | `.env.local` → `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` |
| Maps SDK for Android | kedua app Flutter | `env.json` → `GOOGLE_MAPS_API_KEY` + meta-data di `AndroidManifest.xml` |

---

## Database

PostgreSQL 16 + **PostGIS 3.4**, di-host di Railway. Semua kolom lokasi memakai
tipe `geography(Point,4326)` dengan index **GiST** — bukan sepasang kolom
lat/lng terpisah.

Butuh database lokal (offline / Railway bermasalah)? Tersedia PostGIS lokal:

```bash
docker compose up -d
# lalu di backend/.env:
# DATABASE_URL=postgresql://ambulans:ambulans@localhost:5433/ambulans
npm run migrate && npm run seed
```

Perhatikan image-nya `postgis/postgis`, bukan `postgres` biasa — image Postgres
standar tidak punya ekstensi PostGIS dan migration pertama akan langsung gagal.

---

## Sistem desain "Dispatch Console"

Baca `design-reference/README.md` sebelum menyentuh UI apa pun.

Tiga elemen tanda tangan yang tidak boleh diganti motif lain:

1. **Bracket reticle** — empat siku ala bracket fokus kamera, mewakili
   penguncian lokasi GPS. Mengelilingi tombol SOS dan titik lokasi.
2. **Pulse-line stepper** — alur status digambar sebagai garis EKG literal,
   dengan checkpoint di puncak gelombang. Bukan stepper titik-garis biasa.
3. **Readout mono** — setiap angka penting (ETA, jarak, koordinat) memakai
   JetBrains Mono dengan label huruf kapital di atasnya.

Dua aturan warna yang mengikat:

- Merah (`siren`) **hanya** untuk SOS, pembatalan, dan status darurat. Kalau
  merah dipakai untuk CTA biasa, ia berhenti berarti "darurat".
- Hijau mode terang **di-deepen**, bukan di-invert: `#39E991` → `#0F9D6E`.
  Hijau terang tidak terbaca di atas latar terang.

Mode gelap adalah default di ketiga platform.
