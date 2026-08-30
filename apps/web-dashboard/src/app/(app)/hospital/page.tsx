'use client';

import { useEffect, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from '@/components/AuthProvider';
import { ConsoleMap } from '@/components/dispatch/ConsoleMap';
import { Readout, TopBar } from '@/components/dispatch/primitives';
import { api } from '@/lib/api';
import { formatCoords, formatDateTime } from '@/lib/format';
import type { Hospital } from '@/lib/types';

/** Profil RS — data yang menentukan RS ini muncul di pencarian SOS mana saja. */
export default function HospitalProfilePage() {
  const { user } = useAuth();
  const [hospital, setHospital] = useState<Hospital | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [form, setForm] = useState({ name: '', address: '', phone: '', lat: '', lng: '' });

  useEffect(() => {
    if (!user?.hospitalId) {
      setLoading(false);
      return;
    }
    (async () => {
      try {
        const { hospital } = await api.getHospital(user.hospitalId!);
        setHospital(hospital);
        setForm({
          name: hospital.name,
          address: hospital.address,
          phone: hospital.phone ?? '',
          lat: String(hospital.lat),
          lng: String(hospital.lng),
        });
      } catch (err) {
        toast.error(err instanceof Error ? err.message : 'Gagal memuat profil RS');
      } finally {
        setLoading(false);
      }
    })();
  }, [user?.hospitalId]);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!hospital) return;
    setBusy(true);
    try {
      const lat = Number(form.lat);
      const lng = Number(form.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        throw new Error('Koordinat harus berupa angka');
      }
      const { hospital: updated } = await api.updateHospital(hospital.id, {
        name: form.name.trim(),
        address: form.address.trim(),
        phone: form.phone.trim() || null,
        lat,
        lng,
      });
      setHospital(updated);
      toast.success('Profil rumah sakit diperbarui');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal menyimpan');
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <div className="mono-sub py-16 text-center">Memuat...</div>;
  if (!hospital) {
    return (
      <div className="mono-sub py-16 text-center">
        Akun Anda belum tertaut ke rumah sakit mana pun.
      </div>
    );
  }

  const verified = hospital.verificationStatus === 'verified';
  const field =
    'w-full rounded-xl border-[1.5px] border-[var(--border-strong)] bg-[var(--surface-2)] px-3 py-2.5 text-[11px] font-medium text-[var(--text-primary)] outline-none transition-colors focus:border-[var(--vital)]';

  return (
    <>
      <TopBar title="Profil Rumah Sakit" subtitle={hospital.name} />

      {!verified && (
        <div
          className="mb-4 rounded-xl px-4 py-3 text-[10px] font-semibold leading-relaxed"
          style={{ background: 'var(--amber-tint)', color: 'var(--amber-text)' }}
        >
          ⚠ RS ini <b>belum terverifikasi admin</b>. Anda tetap bisa mengelola sopir dan
          data RS, tapi RS belum ikut dalam pencarian RS terdekat — jadi belum akan
          menerima panggilan darurat.
        </div>
      )}

      <div className="flex flex-col gap-4 lg:flex-row">
        <form onSubmit={save} className="card-surface flex-1 px-4 py-4">
          <div className="mono-label mb-3">Data Rumah Sakit</div>

          <label className="mono-label mb-1.5 block">Nama</label>
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            className={`${field} mb-3`}
            required
          />

          <label className="mono-label mb-1.5 block">Alamat</label>
          <input
            value={form.address}
            onChange={(e) => setForm({ ...form, address: e.target.value })}
            className={`${field} mb-3`}
            required
          />

          <label className="mono-label mb-1.5 block">Telepon</label>
          <input
            value={form.phone}
            onChange={(e) => setForm({ ...form, phone: e.target.value })}
            className={`${field} mb-3`}
          />

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="mono-label mb-1.5 block">Lintang (lat)</label>
              <input
                value={form.lat}
                onChange={(e) => setForm({ ...form, lat: e.target.value })}
                className={field}
                required
              />
            </div>
            <div>
              <label className="mono-label mb-1.5 block">Bujur (lng)</label>
              <input
                value={form.lng}
                onChange={(e) => setForm({ ...form, lng: e.target.value })}
                className={field}
                required
              />
            </div>
          </div>

          <p className="mt-2 text-[9px] leading-relaxed text-[var(--text-secondary)]">
            Koordinat ini yang dipakai PostGIS untuk menghitung jarak ke pasien. Salah
            memasukkannya berarti RS ini akan muncul di urutan yang salah — atau tidak
            muncul sama sekali.
          </p>

          <button type="submit" disabled={busy} className="btn-vital mt-4">
            {busy ? 'MENYIMPAN...' : 'SIMPAN PERUBAHAN'}
          </button>
        </form>

        <div className="flex-1">
          <ConsoleMap
            minHeight={260}
            markers={[
              {
                id: 'self',
                position: { lat: hospital.lat, lng: hospital.lng },
                label: 'RS',
                tone: verified ? 'vital' : 'muted',
                title: hospital.name,
              },
            ]}
          />
          <div className="mt-3.5 grid grid-cols-2 gap-3">
            <Readout
              label="STATUS VERIFIKASI"
              value={verified ? 'TERVERIFIKASI' : 'MENUNGGU'}
              tone={verified ? 'vital' : 'plain'}
            />
            <Readout
              label="KOORDINAT"
              value={
                <span className="text-[10px]">
                  {formatCoords(hospital.lat, hospital.lng)}
                </span>
              }
            />
            <Readout
              label="TERDAFTAR"
              value={<span className="text-[9.5px]">{formatDateTime(hospital.createdAt)}</span>}
              tone="plain"
            />
            <Readout
              label="DIVERIFIKASI"
              value={
                <span className="text-[9.5px]">
                  {hospital.verifiedAt ? formatDateTime(hospital.verifiedAt) : '—'}
                </span>
              }
              tone="plain"
            />
          </div>
        </div>
      </div>
    </>
  );
}
