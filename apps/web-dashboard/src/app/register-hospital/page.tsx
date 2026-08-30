'use client';

import Link from 'next/link';
import { useState } from 'react';
import { ConsoleMap } from '@/components/dispatch/ConsoleMap';
import { api, ApiError } from '@/lib/api';

/** Titik tengah Kota Bogor — awal yang masuk akal untuk koordinat baru. */
const BOGOR = { lat: -6.5944, lng: 106.7892 };

/**
 * Registrasi mandiri RS — PUBLIK, tanpa login.
 *
 * Prosesnya NON-BLOCKING: begitu formulir terkirim, akun staff langsung aktif
 * dan bisa dipakai masuk. Verifikasi admin berjalan paralel; yang ditahan
 * hanyalah keikutsertaan RS ini dalam pencarian RS terdekat.
 */
export default function RegisterHospitalPage() {
  const [form, setForm] = useState({
    name: '',
    address: '',
    phone: '',
    lat: String(BOGOR.lat),
    lng: String(BOGOR.lng),
    staffName: '',
    email: '',
    password: '',
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  const lat = Number(form.lat);
  const lng = Number(form.lng);
  const coordsValid = Number.isFinite(lat) && Number.isFinite(lng);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      if (!coordsValid) throw new Error('Koordinat harus berupa angka yang valid');
      await api.registerHospital({
        name: form.name.trim(),
        address: form.address.trim(),
        lat,
        lng,
        phone: form.phone.trim() || undefined,
        staff: {
          fullName: form.staffName.trim(),
          email: form.email.trim(),
          password: form.password,
        },
      });
      setDone(true);
    } catch (err) {
      const msg =
        err instanceof ApiError && Array.isArray(err.details)
          ? (err.details as { message: string }[]).map((d) => d.message).join(', ')
          : err instanceof Error
            ? err.message
            : 'Gagal mendaftarkan rumah sakit';
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  const field =
    'w-full rounded-xl border-[1.5px] border-[var(--border-strong)] bg-[var(--surface-2)] px-3.5 py-2.5 text-[11px] font-medium text-[var(--text-primary)] outline-none transition-colors placeholder:text-[var(--text-tertiary)] focus:border-[var(--vital)]';

  if (done) {
    return (
      <div className="console-surface flex min-h-screen items-center justify-center bg-[var(--paper)] px-4">
        <div className="card-surface max-w-[420px] px-7 py-8 text-center">
          <div
            className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-[18px]"
            style={{ background: 'var(--vital-gradient)' }}
          >
            <svg
              width="26"
              height="26"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#04140C"
              strokeWidth={2.4}
              strokeLinecap="round"
            >
              <path d="M20 6 9 17l-5-5" />
            </svg>
          </div>
          <h1 className="font-display text-base font-extrabold text-[var(--text-primary)]">
            Pendaftaran Terkirim
          </h1>
          <p className="mt-3 text-[10.5px] leading-relaxed text-[var(--text-secondary)]">
            Akun staff Anda <b className="text-[var(--text-primary)]">sudah aktif</b> —
            silakan masuk sekarang untuk mulai mendaftarkan sopir dan ambulans.
            <br />
            <br />
            Admin platform akan memverifikasi rumah sakit Anda. Setelah terverifikasi, RS
            Anda otomatis ikut dalam pencarian rumah sakit terdekat dan mulai menerima
            panggilan darurat.
          </p>
          <Link href="/login" className="btn-vital mt-6 block w-full py-3 text-center">
            MASUK SEKARANG
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="console-surface min-h-screen bg-[var(--paper)] px-4 py-10">
      <div className="mx-auto max-w-[900px]">
        <Link
          href="/login"
          className="mb-5 inline-flex items-center gap-1.5 font-mono text-[9px] font-bold uppercase tracking-[0.06em] text-[var(--text-secondary)] transition-colors hover:text-[var(--vital)]"
        >
          <svg
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2.5}
            strokeLinecap="round"
          >
            <path d="m15 18-6-6 6-6" />
          </svg>
          Kembali ke halaman masuk
        </Link>

        <h1 className="font-display text-[17px] font-extrabold text-[var(--text-primary)]">
          Daftarkan Rumah Sakit
        </h1>
        <p className="mono-sub mt-1.5">
          Bergabung dengan jaringan ambulans darurat Kota Bogor
        </p>

        <form onSubmit={submit} className="mt-6 flex flex-col gap-4 lg:flex-row">
          <div className="card-surface flex-1 px-5 py-5">
            <div className="mono-label mb-3">Data Rumah Sakit</div>

            <label className="mono-label mb-1.5 block">Nama Rumah Sakit</label>
            <input
              required
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="RS Contoh Bogor"
              className={`${field} mb-3`}
            />

            <label className="mono-label mb-1.5 block">Alamat Lengkap</label>
            <input
              required
              value={form.address}
              onChange={(e) => setForm({ ...form, address: e.target.value })}
              placeholder="Jl. Contoh No. 12, Bogor Tengah"
              className={`${field} mb-3`}
            />

            <label className="mono-label mb-1.5 block">Telepon</label>
            <input
              value={form.phone}
              onChange={(e) => setForm({ ...form, phone: e.target.value })}
              placeholder="0251-1234567"
              className={`${field} mb-3`}
            />

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="mono-label mb-1.5 block">Lintang (lat)</label>
                <input
                  required
                  value={form.lat}
                  onChange={(e) => setForm({ ...form, lat: e.target.value })}
                  className={field}
                />
              </div>
              <div>
                <label className="mono-label mb-1.5 block">Bujur (lng)</label>
                <input
                  required
                  value={form.lng}
                  onChange={(e) => setForm({ ...form, lng: e.target.value })}
                  className={field}
                />
              </div>
            </div>
            <p className="mt-2 text-[9px] leading-relaxed text-[var(--text-secondary)]">
              Koordinat menentukan urutan RS Anda dalam pencarian RS terdekat. Ambil dari
              Google Maps: klik kanan pada lokasi RS, lalu salin angkanya.
            </p>

            <div className="mt-3.5">
              <ConsoleMap
                minHeight={160}
                markers={
                  coordsValid
                    ? [
                        {
                          id: 'new',
                          position: { lat, lng },
                          label: 'RS',
                          tone: 'vital',
                          title: form.name || 'Lokasi RS',
                        },
                      ]
                    : []
                }
              />
            </div>
          </div>

          <div className="card-surface flex-1 px-5 py-5">
            <div className="mono-label mb-3">Akun Staff Pertama</div>
            <p className="mb-3 text-[9.5px] leading-relaxed text-[var(--text-secondary)]">
              Akun ini yang akan Anda pakai masuk ke Portal RS untuk memantau panggilan
              darurat dan mengelola sopir.
            </p>

            <label className="mono-label mb-1.5 block">Nama Penanggung Jawab</label>
            <input
              required
              value={form.staffName}
              onChange={(e) => setForm({ ...form, staffName: e.target.value })}
              placeholder="Siti Pratiwi"
              className={`${field} mb-3`}
            />

            <label className="mono-label mb-1.5 block">Email (untuk login)</label>
            <input
              required
              type="email"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
              placeholder="staff@rscontoh.id"
              className={`${field} mb-3`}
            />

            <label className="mono-label mb-1.5 block">Kata Sandi</label>
            <input
              required
              type="password"
              minLength={6}
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              placeholder="minimal 6 karakter"
              className={field}
            />

            {error && (
              <div
                className="mt-4 rounded-xl px-3 py-2.5 text-[10px] font-semibold leading-relaxed"
                style={{ background: 'var(--siren-tint)', color: 'var(--siren)' }}
              >
                {error}
              </div>
            )}

            <div
              className="mt-4 rounded-xl px-3.5 py-3 text-[9.5px] font-semibold leading-relaxed"
              style={{ background: 'var(--amber-tint)', color: 'var(--amber-text)' }}
            >
              Setelah mendaftar Anda <b>langsung bisa masuk</b>. Verifikasi admin berjalan
              paralel — RS baru ikut menerima panggilan darurat setelah terverifikasi.
            </div>

            <button type="submit" disabled={busy} className="btn-vital mt-5 w-full py-3.5">
              {busy ? 'MENDAFTARKAN...' : 'DAFTARKAN RUMAH SAKIT'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
