'use client';

import { useCallback, useEffect, useState } from 'react';
import { toast } from 'sonner';
import {
  AvailabilityChip,
  Avatar,
  TopBar,
} from '@/components/dispatch/primitives';
import { api, ApiError } from '@/lib/api';
import { formatRelative } from '@/lib/format';
import type { Driver } from '@/lib/types';

/**
 * Kelola Sopir.
 *
 * Daftar yang tampil di sini SELALU hanya sopir milik RS pengguna — pembatasan
 * itu dikerjakan backend di level SQL, bukan di sini. Halaman ini tidak pernah
 * mengirim hospital_id sama sekali.
 */
export default function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);

  const load = useCallback(async () => {
    try {
      const { drivers } = await api.listDrivers();
      setDrivers(drivers);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal memuat sopir');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = drivers.filter((d) => {
    const q = search.toLowerCase().trim();
    if (!q) return true;
    return (
      d.fullName.toLowerCase().includes(q) ||
      (d.vehiclePlate ?? '').toLowerCase().includes(q) ||
      (d.phone ?? '').includes(q)
    );
  });

  async function handleDelete(driver: Driver) {
    if (!confirm(`Hapus akun sopir ${driver.fullName}? Tindakan ini permanen.`)) return;
    try {
      await api.deleteDriver(driver.id);
      setDrivers((prev) => prev.filter((d) => d.id !== driver.id));
      toast.success(`${driver.fullName} dihapus`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal menghapus sopir');
    }
  }

  async function handleToggleActive(driver: Driver) {
    try {
      const { driver: updated } = await api.updateDriver(driver.id, {
        isActive: !driver.isActive,
      });
      setDrivers((prev) => prev.map((d) => (d.id === updated.id ? updated : d)));
      toast.success(updated.isActive ? 'Akun diaktifkan' : 'Akun dinonaktifkan');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal mengubah status');
    }
  }

  return (
    <>
      <TopBar
        title="Kelola Sopir"
        subtitle={`${drivers.length} sopir terdaftar`}
        actions={
          <>
            <input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="CARI SOPIR..."
              className="w-[180px] rounded-[10px] border border-[var(--border-subtle)] bg-[var(--surface-2)] px-3 py-2 font-mono text-[9.5px] font-semibold uppercase text-[var(--text-primary)] outline-none transition-colors placeholder:text-[var(--text-tertiary)] focus:border-[var(--vital)]"
            />
            <button
              type="button"
              onClick={() => setShowForm((v) => !v)}
              className="btn-vital whitespace-nowrap"
            >
              {showForm ? 'TUTUP' : '+ TAMBAH SOPIR'}
            </button>
          </>
        }
      />

      {showForm && (
        <NewDriverForm
          onCreated={(d) => {
            setDrivers((prev) => [...prev, d]);
            setShowForm(false);
          }}
        />
      )}

      <div className="card-surface overflow-hidden">
        <div className="flex items-center gap-3 border-b border-[var(--divider)] bg-[color-mix(in_srgb,var(--text-primary)_2%,transparent)] px-4 py-3 font-mono text-[8.5px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
          <div className="flex-[2]">Nama Sopir</div>
          <div className="flex-1">No. Kendaraan</div>
          <div className="flex-1">Status</div>
          <div className="flex-1">Posisi Terakhir</div>
          <div className="w-[130px] text-right">Aksi</div>
        </div>

        {loading && <div className="mono-sub px-4 py-10 text-center">Memuat...</div>}

        {!loading && filtered.length === 0 && (
          <div className="mono-sub px-4 py-10 text-center">
            {drivers.length === 0
              ? 'Belum ada sopir terdaftar. Tambahkan lewat tombol di atas.'
              : 'Tidak ada sopir yang cocok dengan pencarian.'}
          </div>
        )}

        {filtered.map((d) => (
          <div
            key={d.id}
            className="flex items-center gap-3 border-b border-[var(--divider)] px-4 py-3 text-[10.5px] text-[var(--text-primary)] last:border-b-0"
            style={{ opacity: d.isActive ? 1 : 0.45 }}
          >
            <div className="flex flex-[2] items-center gap-2.5">
              <Avatar name={d.fullName} />
              <span className="min-w-0">
                <span className="block truncate font-semibold">{d.fullName}</span>
                <span className="block font-mono text-[8px] text-[var(--text-secondary)]">
                  {d.phone ?? '—'}
                </span>
              </span>
            </div>
            <div className="flex-1 font-mono text-[10px]">{d.vehiclePlate ?? '—'}</div>
            <div className="flex-1">
              <AvailabilityChip status={d.availabilityStatus} />
            </div>
            <div className="flex-1 font-mono text-[8.5px] text-[var(--text-secondary)]">
              {d.locationUpdatedAt ? formatRelative(d.locationUpdatedAt) : 'BELUM ADA'}
            </div>
            <div className="flex w-[130px] justify-end gap-2 text-[9.5px] font-bold">
              <button
                type="button"
                onClick={() => void handleToggleActive(d)}
                className="text-[var(--text-secondary)] transition-colors hover:text-[var(--vital)]"
              >
                {d.isActive ? 'Nonaktifkan' : 'Aktifkan'}
              </button>
              <span className="text-[var(--text-tertiary)]">·</span>
              <button
                type="button"
                onClick={() => void handleDelete(d)}
                className="text-[var(--text-secondary)] transition-colors hover:text-[var(--siren)]"
              >
                Hapus
              </button>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

/**
 * Form tambah sopir.
 *
 * Sopir tidak bisa mendaftar sendiri — akunnya dibuatkan RS, sesuai teks di
 * mockup layar Masuk Sopir: "akun yang diberikan oleh rumah sakit Anda".
 */
function NewDriverForm({ onCreated }: { onCreated: (d: Driver) => void }) {
  const [form, setForm] = useState({
    fullName: '',
    phone: '',
    password: '',
    vehiclePlate: '',
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { driver } = await api.createDriver({
        fullName: form.fullName.trim(),
        phone: form.phone.trim(),
        password: form.password,
        vehiclePlate: form.vehiclePlate.trim() || undefined,
      });
      toast.success(`Akun sopir ${driver.fullName} dibuat`);
      onCreated(driver);
    } catch (err) {
      const msg =
        err instanceof ApiError && Array.isArray(err.details)
          ? (err.details as { message: string }[]).map((d) => d.message).join(', ')
          : err instanceof Error
            ? err.message
            : 'Gagal membuat akun sopir';
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  const field =
    'w-full rounded-xl border-[1.5px] border-[var(--border-strong)] bg-[var(--surface-2)] px-3 py-2.5 text-[11px] font-medium text-[var(--text-primary)] outline-none transition-colors placeholder:text-[var(--text-tertiary)] focus:border-[var(--vital)]';

  return (
    <form onSubmit={submit} className="card-surface mb-4 px-4 py-4">
      <div className="mono-label mb-3">Akun Sopir Baru</div>
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <div>
          <label className="mono-label mb-1.5 block">Nama Lengkap</label>
          <input
            required
            value={form.fullName}
            onChange={(e) => setForm({ ...form, fullName: e.target.value })}
            placeholder="Ahmad Ridwan"
            className={field}
          />
        </div>
        <div>
          <label className="mono-label mb-1.5 block">Nomor HP (untuk login)</label>
          <input
            required
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            placeholder="081234567890"
            className={field}
          />
        </div>
        <div>
          <label className="mono-label mb-1.5 block">Kata Sandi Awal</label>
          <input
            required
            type="password"
            minLength={6}
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
            placeholder="minimal 6 karakter"
            className={field}
          />
        </div>
        <div>
          <label className="mono-label mb-1.5 block">Plat Kendaraan</label>
          <input
            value={form.vehiclePlate}
            onChange={(e) => setForm({ ...form, vehiclePlate: e.target.value })}
            placeholder="F 1234 XZ"
            className={field}
          />
        </div>
      </div>

      {error && (
        <div
          className="mt-3 rounded-xl px-3 py-2 text-[10px] font-semibold"
          style={{ background: 'var(--siren-tint)', color: 'var(--siren)' }}
        >
          {error}
        </div>
      )}

      <button type="submit" disabled={busy} className="btn-vital mt-4">
        {busy ? 'MENYIMPAN...' : 'SIMPAN SOPIR'}
      </button>
    </form>
  );
}
