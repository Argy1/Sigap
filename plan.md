# Rencana: Aplikasi Panggilan Darurat Ambulans — Kota Bogor

## Context

Repo saat ini **kosong** — hanya berisi `CLAUDE.md`, `INITIAL_PROMPT.md`, `design-reference/` (6 mockup HTML + README), dan `docs/`. Tidak ada satu baris kode pun. Seluruh sistem dibangun dari nol.

Masalah yang diselesaikan: saat darurat medis, keluarga panik dan sulit menyebutkan lokasi lewat telepon. Aplikasi ini menyediakan SOS satu sentuh — lokasi GPS terkirim otomatis ke RS terdekat, ambulans diarahkan tanpa pasien perlu menyebut alamat.

Hasil akhir yang diharapkan: 3 platform + backend yang **benar-benar bisa dijalankan** (`flutter run` ×2, `npm run dev` untuk dashboard, backend lokal terhubung ke PostGIS di Railway), dengan golden path (SOS → RS terdekat → penugasan sopir → live tracking → selesai) berjalan end-to-end.

### Temuan riset yang membentuk rencana ini

**Toolchain terverifikasi:** Node v24.13.1 · npm 11.8.0 · Flutter 3.41.1 (Dart 3.11, Android SDK 36.1 ✓, Chrome ✓) · git 2.52 · Docker 29.4.1 · Railway CLI 4.40 · Railway MCP terautentikasi sebagai `argy1` (workspace `argy1's Projects`). Visual Studio C++ workload tidak lengkap → target Flutter = **Android + Chrome**, bukan Windows desktop.

**Design tokens** sudah diekstrak lengkap dari keenam mockup (base64 font di-strip, CSS terbaca penuh). Semua nilai presisi — warna, radius, shadow, font-size, letter-spacing — tercatat di §Design Tokens di bawah.

**Keputusan dari user:**
- Database: **buat project Railway baru sekarang** (PostGIS via image `postgis/postgis`, bukan Postgres default Railway yang tidak punya ekstensi PostGIS).
- Google Maps: **belum ada API key** → bangun abstraksi peta dengan fallback bergaya mockup; auto-switch ke Google Maps asli begitu key diisi di `.env`.

---

## Keputusan Arsitektur (mahal diubah — dikunci di sini)

### A. Struktur monorepo & Melos

Dart 3.11 mendukung **pub workspaces** native, dan Melos 7 dibangun di atasnya. Root `pubspec.yaml` jadi workspace root:

```yaml
# /pubspec.yaml
name: ambulans_workspace
publish_to: none
environment: { sdk: ^3.11.0 }
workspace: [apps/patient, apps/driver, packages/mobile-core]
dev_dependencies: { melos: ^7.0.0 }
```

Tiap member pakai `resolution: workspace`. Satu `flutter pub get` di root menyelesaikan ketiganya.

**Gotcha yang sudah diantisipasi:** nama package Dart **tidak boleh mengandung tanda hubung**. Direktori tetap `packages/mobile-core` (sesuai `CLAUDE.md`), tapi nama package-nya `mobile_core`. Apps: direktori `apps/patient` → package `patient_app`, `apps/driver` → package `driver_app`.

**Tidak ada `package.json` di root.** `backend/` dan `apps/web-dashboard/` jadi project npm independen. Alasan: npm workspaces + Next.js sering bikin masalah hoisting dan warning multiple-lockfile. Perintah dev didokumentasikan di `README.md` root.

### B. Skema database — 5 tabel inti + 1 tabel infrastruktur

Tetap setia pada 5 tabel di `CLAUDE.md`. Semua penyimpangan di bawah adalah **penambahan kolom**, bukan penambahan tabel domain — masing-masing dengan alasan yang terikat ke mockup atau ke fitur must-have.

| Tabel | Tambahan dari spec | Alasan |
|---|---|---|
| `profiles` | `email` (unique, null), `phone` (unique), `password_hash` | Auth dibangun manual (bukan BaaS) → kredensial harus tinggal di suatu tempat. Menambah kolom ≠ menambah tabel. Login pakai `identifier` (phone **atau** email) + password: pasien/sopir pakai HP (sesuai mockup), staff RS/admin pakai email. |
| `patient_profiles` | `profile_id` jadi **PRIMARY KEY** (1:1); `allergies` jadi `text[]`; `medical_history text` | Layar 07 menampilkan alergi sebagai **chip ganda** → array adalah model yang benar. `medical_history` = field "RIWAYAT PENYAKIT (OPSIONAL)" di mockup. |
| `hospitals` | `updated_at` | — |
| `drivers` | `location_updated_at`, `profile_id` UNIQUE | Tanpa timestamp, posisi sopir basi tidak bisa dibedakan dari yang segar — fatal untuk query "sopir terdekat". |
| `emergency_calls` | `call_code` (unique, dari sequence), `guest_name`, `guest_phone`, `medical_snapshot jsonb`, `en_route_at`, `cancelled_at`, `updated_at` | `call_code` = "SOS #A102" yang muncul di 3 layar mockup. `guest_*`: guest mode adalah must-have, tapi `patient_id` null → dashboard tidak punya nama/nomor untuk dihubungi balik. `medical_snapshot`: layar Sopir menampilkan "⚠ ALERGI PENISILIN · GOL. DARAH O+"; snapshot menjaga catatan riwayat tetap akurat walau pasien mengedit profilnya kemudian. |
| **`refresh_tokens`** *(baru)* | id, profile_id, token_hash, expires_at, revoked_at | Tabel **infrastruktur**, bukan domain. Refresh token rotation + revoke per-device mustahil kalau stateless. Ini bagian dari "belajar bangun auth dari nol". |

Semua kolom lokasi pakai `geography(Point,4326)` + **GiST index**. Semua kolom status pakai `CHECK` constraint. Tambahan index: `(hospital_id, availability_status)` di drivers, `(hospital_id, status)` dan `(patient_id, created_at DESC)` di emergency_calls.

`call_code` digenerate dari sequence: `'A' || lpad(nextval('emergency_call_code_seq')::text, 3, '0')` → `A102`.

### C. Query dua tahap (RS terdekat & sopir terdekat)

Tahap 1 — PostGIS KNN, persis seperti spec:
```sql
SELECT id, name, address, phone,
       ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng,
       ST_Distance(location, ST_SetSRID(ST_MakePoint($1,$2),4326)::geography) AS straight_m
FROM hospitals
WHERE verification_status = 'verified'
ORDER BY location <-> ST_SetSRID(ST_MakePoint($1,$2),4326)::geography
LIMIT 5;
```

Tahap 2 — refine dengan jarak tempuh jalan. **Penyimpangan yang disengaja:** pakai **Distance Matrix API**, bukan Directions API. Alasan: 1 origin → 5 destinations selesai dalam **satu** request, sedangkan Directions butuh 5 request untuk hasil yang sama. Intent spec (jarak tempuh jalan sebenarnya, dipanggil dari backend supaya API key aman) terpenuhi identik. Dibungkus di `RoutingService` — kalau nanti mau ganti ke Directions, cukup satu file.

Pola yang sama dipakai ulang untuk sopir terdekat (filter `hospital_id` + `availability_status='available'` + `location_updated_at > now() - interval '5 minutes'`).

### D. Strategi tanpa Google Maps API key

Satu abstraksi, dua implementasi, dipilih otomatis dari keberadaan env var:

| Kapabilitas | Dengan key | Tanpa key (fallback) |
|---|---|---|
| Peta Flutter | `google_maps_flutter` | `ConsoleMap` — `CustomPaint` yang mereplikasi `.map-dark` dari mockup (grid gradient + garis jalan diagonal + pin & userdot terposisi) |
| Peta web | `@vis.gl/react-google-maps` | `<ConsoleMap>` React, CSS identik dengan `.mappane` di mockup |
| Jarak/ETA | Distance Matrix | Haversine × faktor 1.35 (koreksi jalan kota) @ 32 km/j |
| Alamat | Geocoding API reverse | `"Lokasi GPS -6.5971, 106.8060"` |

Ini **bukan kompromi visual** — mockup memang menggambarkan peta bergaya konsol abstrak, bukan Google Maps. Fallback justru lebih setia ke design reference. `.env.example` mendokumentasikan 4 API yang perlu di-enable saat key tersedia: Maps SDK for Android, Maps JavaScript, Distance Matrix, Geocoding.

### E. Realtime & auth guest mode

Socket.io rooms:
- `hospital:{id}` — staff RS. Events: `sos:new`, `sos:updated`, `driver:location`
- `call:{id}` — pasien/tamu pemilik panggilan + sopir yang ditugaskan. Events: `call:status`, `driver:location`
- `driver:{id}` — sopir spesifik. Events: `assignment:new`, `assignment:cancelled`

**Masalah kunci:** guest mode tidak punya JWT, tapi harus bisa memantau live tracking. **Solusi:** saat guest membuat SOS, backend mengembalikan **call token** — JWT berumur pendek yang scope-nya hanya call id itu. Socket handshake menerimanya dan hanya mengizinkan join `call:{id}`. Bersih dan tidak bocor.

### F. Yang sengaja TIDAK dipakai

Tanpa ORM (pakai `pg` + query berparameter) dan tanpa library migration pihak ketiga (runner SQL ~60 baris buatan sendiri) — sesuai tujuan eksplisit "belajar membangun backend dari nol". Tidak ada Supabase/Firebase.

---

## Design Tokens (diekstrak presisi dari mockup)

**Font:** Unbounded 700/800/900 (judul, tombol, angka hero) · Inter 400–800 (body) · JetBrains Mono 500/600/700 (SEMUA angka & label kapital)

| Token | Dark | Light |
|---|---|---|
| bg utama | `#0A0E14` | `#F2F5F3` |
| surface/panel | `rgba(255,255,255,0.04)` + border `rgba(255,255,255,0.08)` | `#FFFFFF` + border `rgba(10,20,15,0.07)` + shadow `0 4px 14px rgba(10,20,15,0.04)` |
| bg peta | `#0D131E` | `#E4EDE9` |
| vital (hijau) | `#39E991` | `#0F9D6E` ← **di-deepen, bukan di-invert** |
| vital gradient | `linear-gradient(135deg,#39E991,#0EA972)` (sama di kedua mode) | idem |
| siren (SOS) | `radial-gradient(circle at 32% 28%, #FF6B85, #FF3355 45%, #C81E44 100%)` | idem |
| siren teks | `#FF3355` | `#E11D48` |
| amber | `#FFB020` | badge `#FFB020` tint, teks `#B45309` |
| teks utama | `#F4F6F8` | `#0A0E14` |
| teks sekunder | `rgba(244,246,248,0.4–0.55)` | `rgba(10,14,20,0.4–0.6)` |
| on-vital (teks di atas hijau) | `#04140C` | `#04140C` |
| admin accent | `#9333EA` → `#6D28D9`, aktif `#C084FC` | idem |

**Radius:** panel/card 15px · readout/input 12px · tombol 13px · chip 9px · status-chip 6px · navbar 16px · avatar 10-11px · datatable 14px

**Elemen tanda tangan:**
1. **Reticle bracket** — 4 siku 24×24px, border 2px `rgba(vital,0.5)`, radius sudut luar 8px. Mengelilingi tombol SOS (wrap 196×196) dan titik lokasi.
2. **SOS button** — Ø108px, ring1 Ø156 + ring2 Ø132 (`rgba(255,51,85,0.28/0.4)`), glow radial Ø156, shadow `0 14px 30px rgba(255,51,85,0.5)` + inset. Label "SOS" Unbounded 19px/800, sub "TAHAN" mono 7px letter-spacing 0.18em.
3. **Pulse-line stepper** — SVG path EKG literal, viewBox `0 0 240 40`:
   `M0,20 L22,20 L30,4 L38,34 L46,20 L88,20 L96,4 L104,34 L112,20 L154,20 L162,4 L170,34 L178,20 L220,20 L228,4 L236,34 L244,20 L240,20`
   Checkpoint = circle di puncak (cy=4): done `r=3.5 #39E991`, active `r=5 #FFB020`, pending `r=3.5 rgba(text,0.25)`. Label mono 6.5px di bawah.
4. **Readout mono** — card kecil: label mono 7.5px/700 letter-spacing 0.08em warna sekunder, nilai mono 12px/700 warna vital.

---

## Fase 0 — Setup monorepo

- `git init` + `.gitignore` (Node, Flutter, `.env`, `.dart_tool`, `build/`, `.next/`)
- Scaffold direktori sesuai `CLAUDE.md`
- Root `pubspec.yaml` (pub workspace) + `melos.yaml` (script: `analyze`, `format`, `get`, `run:patient`, `run:driver`)
- `flutter create` untuk `apps/patient`, `apps/driver`; `flutter create --template=package` untuk `packages/mobile-core` → lalu ubah ke `resolution: workspace`
- **Tulis `plan.md` di root proyek** (salinan rencana ini, sesuai permintaan)
- `README.md` root: cara menjalankan tiap bagian
- `.env.example` di `backend/`, `apps/web-dashboard/`, dan `apps/patient|driver/` (lewat `--dart-define-from-file`)
- Unduh & bundle font Unbounded / Inter / JetBrains Mono ke `packages/mobile-core/assets/fonts/` (dari repo `google/fonts`). Kalau unduhan gagal → fallback ke package `google_fonts`, dicatat di README.
- Commit awal (Conventional Commits)

## Fase 1 — Backend & Database

**1a. Provisioning Railway** (via MCP): project baru `ambulans-bogor` → service dari image `postgis/postgis:16-3.4` + volume + variabel `POSTGRES_*` → generate TCP proxy untuk akses dari lokal → ambil `DATABASE_URL` publik. Ditambah `docker-compose.yml` (PostGIS lokal) sebagai jaring pengaman kalau Railway bermasalah.

**1b. Struktur backend** (`backend/src/`):
```
config/env.ts            zod-validated env
db/pool.ts               pg.Pool
db/migrate.ts            runner SQL kustom + tabel schema_migrations
db/migrations/*.sql      001_extensions, 002_profiles+refresh_tokens,
                         003_hospitals, 004_drivers, 005_emergency_calls, 006_indexes
db/seed.ts               6 RS Kota Bogor (koordinat asli) + akun demo tiap role
middleware/auth.ts       verifikasi JWT → req.user  (+ optionalAuth untuk guest SOS)
middleware/rbac.ts       requireRole(...), scopeToHospital()
middleware/validate.ts   zod
middleware/error.ts      error handler terpusat
controllers/             auth, hospitals, drivers, emergency, admin
routes/                  per-resource + index
services/geo.service.ts       query PostGIS (nearestHospitals, nearestDrivers)
services/routing.service.ts   Distance Matrix + reverse geocode + fallback haversine
services/dispatch.service.ts  orkestrasi golden path
services/token.service.ts     access + refresh rotation + call token
sockets/index.ts, rooms.ts, handlers.ts
app.ts, server.ts
```

**1c. Endpoint inti:**

| Method | Path | Akses |
|---|---|---|
| POST | `/api/auth/register` | publik (role `patient`) |
| POST | `/api/auth/login` | publik (identifier = phone/email) |
| POST | `/api/auth/refresh` · `/logout` | token |
| GET | `/api/auth/me` | authed |
| GET/PUT | `/api/patients/me/medical` | patient |
| GET | `/api/hospitals/nearest?lat&lng` | **publik** (dipakai layar Peta & guest) |
| POST | `/api/hospitals/register` | publik → `verification_status='unverified'` (non-blocking) |
| GET/PATCH | `/api/hospitals/:id` | staff RS sendiri / admin |
| GET | `/api/admin/hospitals?status=unverified` | admin |
| PATCH | `/api/admin/hospitals/:id/verify` | admin |
| GET/POST/PATCH/DELETE | `/api/drivers` | staff RS (**scoped ke hospital_id sendiri**) / admin |
| PATCH | `/api/drivers/me/availability` · `/location` | driver |
| POST | `/api/emergency-calls` | **publik + optionalAuth** → guest dapat call token |
| GET | `/api/emergency-calls/:id` | pemilik / call-token / staff RS terkait / sopir ditugaskan / admin |
| GET | `/api/emergency-calls` | patient (miliknya) atau staff RS (RS-nya) |
| POST | `/api/emergency-calls/:id/assign` | staff RS pemilik panggilan |
| GET | `/api/emergency-calls/:id/suggested-drivers` | staff RS pemilik panggilan |
| PATCH | `/api/emergency-calls/:id/status` | sopir ditugaskan / staff RS / pasien (cancel saja) |

**Aturan RBAC yang tidak boleh bocor:** setiap query yang menyentuh data RS **wajib** membawa `WHERE hospital_id = $currentUserHospitalId` di level SQL — tidak cukup mengandalkan middleware saja. Diuji eksplisit di Fase 5.

**1d. Socket.io:** JWT/call-token di handshake, join room sesuai role, handler `driver:location` → simpan ke `drivers.current_location` + broadcast ke `call:{id}` dan `hospital:{id}`.

**Deliverable:** `npm run dev` di `backend/` jalan, `npm run migrate && npm run seed` sukses, golden path bisa dibuktikan lewat file `backend/requests.http`.

## Fase 2 — Dashboard Web (Next.js)

- `create-next-app` (App Router, TS, Tailwind) + shadcn/ui + `@fontsource/{unbounded,inter,jetbrains-mono}` + `next-themes` (default **dark**) + `socket.io-client`
- `globals.css`: CSS variable untuk seluruh token di §Design Tokens; `:root` = light, `.dark` = dark; `tailwind.config` memetakan `vital`, `siren`, `amber`, `ink`, `paper`, `admin`
- Komponen design system di `components/dispatch/`: `StatCard`, `SosCard`, `DataTable`, `StatusChip`, `VerifCard`, `ConsoleMap` (+ `GoogleMapPane`), `PulseStepper`, `ReticleBracket`, `Sidebar`, `TopBar`, `BtnTeal`
- Halaman: `/login` · `/register-hospital` · `/dashboard` (stats + peta + daftar SOS live) · `/sos/[id]` (detail + data medis + saran sopir + tombol tugaskan) · `/drivers` (CRUD) · `/history` · `/hospital` · `/admin/hospitals` (aksen ungu) · `/admin/stats`
- Auth: access token di memori + refresh token di httpOnly cookie via route handler; middleware proteksi rute per role
- Socket: `useSocket()` hook → `sos:new` menambah kartu + notifikasi suara, `sos:updated` mengubah status live

**Deliverable:** `npm run dev` jalan, login sebagai staff RS demo, SOS baru muncul realtime tanpa refresh.

## Fase 3 — `mobile-core` + App Pasien

**`packages/mobile-core/lib/src/`:**
- `theme/` — `DispatchColors` (dark & light), `DispatchTypography`, `DispatchRadii/Shadows`, `dispatchTheme(Brightness)`
- `models/` — `Profile`, `PatientProfile`, `Hospital`, `DriverModel`, `EmergencyCall`, enum `CallStatus`/`AvailabilityStatus` (freezed + json_serializable)
- `api/` — `ApiClient` (dio + interceptor auth & auto-refresh), API per resource, `TokenStorage` (flutter_secure_storage)
- `realtime/socket_service.dart`
- `widgets/` — **`ReticleBracket`**, **`SosHoldButton`** (tahan ~1.5s, ring meluas, haptic, progress), **`PulseStepper`** (CustomPainter dengan path EKG persis di atas), `ReadoutCard`, `DispatchPanel`, `DispatchButton` (primary/outline/danger), `StatusChip`, `DispatchNavBar`, `ConsoleMap`, `DispatchTextField`, `DispatchChip`, `EmptyState`, `PageHeader`, `BrandHeader`
- `providers/` — Riverpod: auth, location (geolocator), themeMode

**`apps/patient/` — 7 layar:** 01 Masuk & Registrasi (+ MODE TAMU) · 02 Beranda-SOS · 03 SOS Aktif live tracking · 04 Peta & RS Terdekat · 05 Riwayat · 06 Profil Hub · 07 Edit Profil Medis. Dark default, toggle terang di Profil → Tampilan.

## Fase 4 — App Sopir

**`apps/driver/` — 5 layar:** 01 Masuk Sopir · 02 Beranda + toggle Tersedia/Tidak · 03 Tugas Masuk (TOLAK/TERIMA + med-alert merah) · 04 Navigasi Aktif (pulse stepper + konfirmasi tiba) · 05 Riwayat Penjemputan. Plus layar **Akun** minimal — tab ini ada di navbar mockup tapi layarnya tidak digambar. Seluruh UI reuse `mobile_core`.

Broadcast lokasi: timer 5 detik mengirim posisi via socket selama tugas aktif.

## Fase 5 — Integrasi, RBAC audit & polish

1. Uji golden path lintas platform: SOS dari App Pasien → muncul di dashboard RS → tugaskan sopir → App Sopir terima → posisi sopir bergerak realtime di App Pasien & dashboard → `arrived` → `completed`
2. Ulangi seluruhnya dalam **mode tamu** (tanpa login) — verifikasi call token bekerja
3. **Audit kebocoran RBAC**: staff RS-A mencoba `GET /api/emergency-calls/:id` milik RS-B, `GET /api/drivers` RS-B, `POST /assign` panggilan RS-B → semua harus 403. Sopir mencoba mengubah status panggilan yang bukan miliknya → 403. Pasien mencoba endpoint admin → 403.
4. Verifikasi visual side-by-side terhadap mockup (dark & light, ketiga platform) — terutama reticle, pulse stepper, dan readout mono
5. `flutter analyze` bersih, `npm run build` di dashboard sukses, README final

---

## File Kritis

| File | Peran |
|---|---|
| `/pubspec.yaml`, `/melos.yaml` | Root pub workspace — mengunci resolusi ketiga package Flutter |
| `backend/src/db/migrations/*.sql` | Sumber kebenaran skema; PostGIS geography + GiST index |
| `backend/src/services/geo.service.ts` | Query KNN dua tahap — jantung fitur SIG |
| `backend/src/services/routing.service.ts` | Titik switch Google Maps ↔ fallback haversine |
| `backend/src/middleware/rbac.ts` | Satu-satunya tempat aturan akses per role didefinisikan |
| `backend/src/sockets/rooms.ts` | Penamaan room — menentukan siapa menerima event apa |
| `packages/mobile-core/lib/src/theme/dispatch_colors.dart` | Token warna dark & light untuk kedua app Flutter |
| `packages/mobile-core/lib/src/widgets/pulse_stepper.dart` | Path EKG — elemen tanda tangan, jangan diganti motif lain |
| `packages/mobile-core/lib/src/widgets/sos_hold_button.dart` | Reticle + ring + tahan-untuk-trigger |
| `apps/web-dashboard/src/app/globals.css` | CSS variable design system untuk web |

## Verifikasi

```bash
# Backend
cd backend && npm run migrate && npm run seed && npm run dev
curl "http://localhost:3000/api/hospitals/nearest?lat=-6.5971&lng=106.8060"   # 5 RS Bogor terurut

# Dashboard
cd apps/web-dashboard && npm run dev        # login staff RS demo → dashboard live

# Flutter
flutter pub get                              # dari root workspace
cd apps/patient && flutter run               # Android emulator / Chrome
cd apps/driver  && flutter run

# Golden path & RBAC
# dijalankan manual lintas 3 platform + skrip uji 403 di Fase 5
```

Kriteria selesai: golden path lengkap berjalan end-to-end (login & guest), live tracking benar-benar bergerak realtime, tidak ada endpoint yang bocor antar-RS/antar-role, dan visual ketiga platform cocok dengan mockup di kedua mode warna.
