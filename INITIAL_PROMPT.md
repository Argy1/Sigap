Kamu akan membangun aplikasi full-stack ini dari nol: aplikasi panggilan darurat ambulans (3 platform: App Pasien & App Sopir di Flutter, Dashboard RS/Admin di Next.js, plus backend Node.js/Express + PostgreSQL/PostGIS di Railway). Sebelum menulis kode apa pun:

1. Baca `CLAUDE.md` di root proyek ini secara penuh — itu spesifikasi teknis lengkap (tech stack, skema database, alur inti, prioritas fitur, konvensi kode).
2. Buka dan pelajari keenam file di `/design-reference/` (patient-app-dark.html, patient-app-light.html, driver-app-dark.html, driver-app-light.html, web-dashboard-dark.html, web-dashboard-light.html) beserta `/design-reference/README.md`. File-file ini adalah referensi visual presisi piksel — bukan bagian dari aplikasi, tapi kamu harus mereplikasi warna, tipografi, spacing, dan terutama elemen tanda tangan (bracket reticle di sekitar tombol SOS/titik lokasi, stepper status berbentuk garis EKG, readout data mono font) secara akurat ke widget Flutter dan komponen Next.js. Jangan gunakan Material Design default polos atau desain generikmu sendiri.

Setelah paham konteks lengkap, masuk ke **Plan Mode** dan susun rencana kerja terstruktur (gunakan ultrathink untuk bagian arsitektur database dan struktur monorepo — ini keputusan yang mahal untuk diubah belakangan). Rencana harus mencakup tahapan berikut, secara berurutan:

**Fase 0 — Setup**: scaffold struktur monorepo sesuai `CLAUDE.md`, setup Melos untuk workspace Flutter, inisialisasi git, buat `.env.example` di tiap app/backend.

**Fase 1 — Backend & Database**: setup project Railway (PostgreSQL + ekstensi PostGIS), migration untuk 5 tabel di `CLAUDE.md`, endpoint REST inti (auth register/login JWT, CRUD hospitals, CRUD drivers, create/update emergency_calls, endpoint pencarian RS terdekat pakai query PostGIS), middleware RBAC per role, setup Socket.io untuk broadcast lokasi live.

**Fase 2 — Dashboard Web (Next.js)**: setup project, install font (`@fontsource/unbounded`, `@fontsource/inter`, `@fontsource/jetbrains-mono`), bangun design system Tailwind (warna, komponen kartu/bracket/pulse-stepper reusable) berdasarkan `/design-reference/web-dashboard-*.html`, implementasikan 4 halaman (Dashboard Utama, Detail SOS & Penugasan Sopir, Kelola Sopir, Panel Admin Verifikasi RS), integrasi ke backend + Socket.io untuk update SOS real-time.

**Fase 3 — Flutter shared package + App Pasien**: bangun `packages/mobile-core` (model data, API client, tema warna/font sesuai design reference, widget reusable seperti tombol SOS dan pulse-stepper), lalu App Pasien lengkap 7 layar sesuai `/design-reference/patient-app-*.html`, termasuk mode gelap/terang.

**Fase 4 — App Sopir**: 5 layar sesuai `/design-reference/driver-app-*.html`, reuse `packages/mobile-core`.

**Fase 5 — Integrasi & polish**: pastikan alur inti (golden path di `CLAUDE.md`) berjalan end-to-end antar ketiga platform, live tracking via Socket.io benar-benar real-time, cek RLS/RBAC tidak bocor antar role.

Setelah rencana ini kamu susun, tulis ke `plan.md` di root proyek, lalu lanjutkan langsung ke eksekusi Fase 0 dan seterusnya tanpa menunggu konfirmasi ulang di setiap fase kecuali kamu menemukan sesuatu yang benar-benar ambigu atau butuh keputusan yang tidak bisa diambil sendiri (misalnya kredensial akun Railway yang perlu saya buat manual) — dalam hal itu, tanyakan satu pertanyaan singkat dan lanjutkan ke bagian lain sambil menunggu.

Kerjakan secara mandiri dan menyeluruh. Saya ingin proyek ini benar-benar bisa dijalankan (`flutter run` untuk kedua app, `npm run dev` untuk dashboard, backend jalan lokal dengan koneksi ke database Railway) di akhir sesi ini, bukan cuma kerangka kosong.
