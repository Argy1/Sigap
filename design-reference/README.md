# Design Reference — Baca Ini Dulu

Folder ini berisi 6 file HTML statis (bukan bagian dari aplikasi, murni referensi visual). Tiap file berisi semua layar untuk satu platform, side-by-side, dalam 2 mode warna.

| File | Isi |
|---|---|
| `patient-app-dark.html` / `patient-app-light.html` | 7 layar App Pasien (Flutter) |
| `driver-app-dark.html` / `driver-app-light.html` | 5 layar App Sopir Ambulans (Flutter) |
| `web-dashboard-dark.html` / `web-dashboard-light.html` | 4 layar Dashboard Web RS & Admin (Next.js) |

## Cara pakai file ini

Buka tiap file di browser buat lihat hasil visualnya. Untuk ambil nilai desain yang presisi (warna, spacing, radius, ukuran font), baca langsung isi HTML/CSS-nya (`view-source:` atau buka di editor teks) — semua token desain ada di situ sebagai CSS biasa, bukan gambar.

## Sistem Desain: "Dispatch Console"

**Konsep**: lahir dari dua elemen inti aplikasi — penguncian lokasi GPS (elemen bracket/reticle ala alat pelacak) dan monitor vital tanda kehidupan (garis EKG rumah sakit). Bukan "app kesehatan teal" generik.

### Tipografi
- **Unbounded** (700/800/900) — judul, tombol besar, angka hero
- **Inter** (400–800) — body text
- **JetBrains Mono** (500–700) — SEMUA angka & data: ETA, jarak, koordinat, timestamp, status code, label huruf kapital kecil. Ini yang ngasih kesan "readout konsol".
- Ketiga font di-embed sebagai base64 langsung di file HTML (biar file mockup ini bisa dibuka offline). **Untuk aplikasi sungguhan, install via package resmi**: `@fontsource/unbounded`, `@fontsource/inter`, `@fontsource/jetbrains-mono` (npm) untuk web, dan cari font family yang sama di [Google Fonts](https://fonts.google.com) untuk di-bundle ke Flutter (taruh di `assets/fonts/`, daftarkan di `pubspec.yaml`).

### Warna — Mode Gelap (dasar/signature)
| Token | Hex | Peran |
|---|---|---|
| `ink` | `#0A0E14` | Background utama |
| `ink-2` | `#0D131E` | Background peta/elemen sekunder |
| `vital` | `#39E991` | Hijau aksen utama — status aktif, sukses, readout angka |
| `vital-deep` | `#0EA972` / `#0F9D6E` | Gradient partner / varian lebih gelap |
| `siren` | `#FF3355` → `#C81E44` (gradient) | KHUSUS tombol SOS & status darurat/batal. Jangan dipakai di luar konteks itu. |
| `amber` | `#FFB020` | Status pending/menunggu |
| `text-primary` | `#F4F6F8` | Teks utama di atas dasar gelap |
| `text-secondary` | `rgba(244,246,248,0.4–0.55)` | Teks sekunder, berbagai opacity |

### Warna — Mode Terang
| Token | Hex | Peran |
|---|---|---|
| `paper` | `#F2F5F3` | Background utama |
| `surface` | `#FFFFFF` | Kartu/panel (solid, bukan overlay transparan) |
| `vital` | `#0F9D6E` | Hijau aksen (di-*deepen* dari versi gelap `#39E991` biar tetap kontras di atas terang) |
| `siren` | Sama seperti mode gelap | Gradient merah SOS tetap sama di kedua mode |
| `amber-text` | `#B45309` | Versi lebih gelap dari amber, khusus teks (badge tetap pakai `#FFB020` di background tint) |
| `text-primary` | `#0A0E14` | Teks utama |
| `text-secondary` | `rgba(10,14,20,0.4–0.6)` | Teks sekunder |

**PENTING**: warna hijau/teks TIDAK boleh sekadar di-invert antar mode. Nilai di mode terang sengaja di-*deepen* (`#39E991` → `#0F9D6E`) biar tetap kontras & legible di atas latar terang. Jangan reuse nilai mode gelap mentah-mentah di mode terang.

### Elemen Tanda Tangan (WAJIB dipertahankan, jangan diganti motif lain)
1. **Reticle bracket** — 4 siku (seperti bracket fokus kamera) mengelilingi tombol SOS dan titik lokasi pengguna. Representasi visual dari "penguncian lokasi GPS".
2. **Pulse-line stepper** — status flow (SOS Aktif, Navigasi Aktif) digambar sebagai garis EKG/heartbeat literal (SVG path dengan puncak di tiap checkpoint), BUKAN stepper titik-garis biasa. Lihat contoh SVG path di source HTML (`build_patient_v2_full.py` logic, cari fungsi `pulse_svg`).
3. **Readout mono** — setiap angka penting (ETA, jarak, koordinat) ditampilkan dalam card kecil dengan label huruf kapital JetBrains Mono di atas, nilai besar di bawah.

### Komponen kunci per platform
- **App Pasien**: 4 tab nav (Beranda, Peta, Riwayat, Profil). Tombol SOS = elemen paling dominan di layar, bracket + ring animasi + glow merah.
- **App Sopir**: 3 tab nav (Beranda, Riwayat, Akun). Toggle status Tersedia/Tidak Tersedia jadi elemen utama di Beranda.
- **Dashboard Web**: sidebar kiri tetap + area konten kanan. Portal RS pakai aksen hijau, Panel Admin pakai aksen ungu (`#9333EA`) sebagai pembeda level akses — desain dasarnya tetap sama, cuma warna aksen beda.

### Aturan penting
- Merah (`siren`) HANYA untuk SOS, batal, dan status darurat/error. Jangan dipakai buat CTA biasa.
- Hijau (`vital`) adalah warna brand utama buat semua aksi positif/konfirmasi (tombol "Terima Tugas", "Verifikasi", dll) — bukan cuma dekorasi.
- Border-radius, shadow, dan spacing yang dipakai di mockup ini konsisten — pertahankan skala yang sama (jangan sharp corners, jangan flat/no-shadow).
