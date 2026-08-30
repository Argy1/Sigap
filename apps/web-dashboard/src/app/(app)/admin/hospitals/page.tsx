'use client';

import { useCallback, useEffect, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from '@/components/AuthProvider';
import { PendingBadge, TopBar } from '@/components/dispatch/primitives';
import { useSocket, useSocketEvent } from '@/hooks/useSocket';
import { api } from '@/lib/api';
import { formatCoords, formatRelative } from '@/lib/format';
import type { Hospital } from '@/lib/types';

/**
 * Panel Admin — Verifikasi RS.
 *
 * Aksen UNGU, bukan hijau: pembeda level akses yang disengaja di sistem desain.
 * Struktur halamannya sendiri identik dengan Portal RS.
 *
 * Verifikasi bersifat NON-BLOCKING terhadap pendaftaran: RS sudah bisa masuk
 * dan mengelola sopirnya sejak mendaftar. Yang dikunci verifikasi hanya satu
 * hal — RS belum terverifikasi tidak ikut dalam pencarian RS terdekat, jadi
 * tidak akan menerima panggilan darurat sungguhan.
 */
export default function AdminHospitalsPage() {
  const { user } = useAuth();
  const { socket } = useSocket(true);
  const [hospitals, setHospitals] = useState<Hospital[]>([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const { hospitals } = await api.adminHospitals();
      setHospitals(hospitals);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal memuat data');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  // RS baru mendaftar -> langsung muncul di panel admin tanpa refresh.
  useSocketEvent<Hospital>(socket, 'hospital:registered', (h) => {
    setHospitals((prev) => (prev.some((x) => x.id === h.id) ? prev : [h, ...prev]));
    toast.info(`Pendaftaran baru: ${h.name}`);
  });

  async function decide(h: Hospital, status: 'verified' | 'rejected') {
    setBusyId(h.id);
    try {
      const { hospital } = await api.verifyHospital(h.id, status);
      setHospitals((prev) => prev.map((x) => (x.id === hospital.id ? hospital : x)));
      toast.success(
        status === 'verified'
          ? `${hospital.name} terverifikasi — kini ikut dalam pencarian RS terdekat`
          : `${hospital.name} ditolak`,
      );
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal memproses');
    } finally {
      setBusyId(null);
    }
  }

  const pending = hospitals.filter((h) => h.verificationStatus === 'unverified');
  const decided = hospitals.filter((h) => h.verificationStatus !== 'unverified');

  if (user && user.role !== 'admin') {
    return (
      <div className="mono-sub py-16 text-center">
        Halaman ini hanya untuk admin platform.
      </div>
    );
  }

  return (
    <>
      <TopBar
        title="Verifikasi Rumah Sakit"
        subtitle={
          pending.length > 0
            ? `${pending.length} pendaftaran baru menunggu verifikasi`
            : 'Tidak ada pendaftaran yang menunggu'
        }
      />

      {loading && <div className="mono-sub py-10 text-center">Memuat...</div>}

      {pending.map((h) => (
        <HospitalCard
          key={h.id}
          hospital={h}
          busy={busyId === h.id}
          onVerify={() => void decide(h, 'verified')}
          onReject={() => void decide(h, 'rejected')}
        />
      ))}

      {decided.length > 0 && (
        <>
          <div className="mono-label mb-2.5 mt-6">Sudah Diproses</div>
          {decided.map((h) => (
            <HospitalCard key={h.id} hospital={h} />
          ))}
        </>
      )}
    </>
  );
}

function HospitalCard({
  hospital,
  busy,
  onVerify,
  onReject,
}: {
  hospital: Hospital;
  busy?: boolean;
  onVerify?: () => void;
  onReject?: () => void;
}) {
  const isPending = hospital.verificationStatus === 'unverified';
  const isVerified = hospital.verificationStatus === 'verified';

  return (
    <div
      className="card-surface mb-2.5 flex flex-wrap items-center gap-3.5 px-4 py-3.5"
      style={{ opacity: isPending ? 1 : 0.6 }}
    >
      <div
        className="flex h-[42px] w-[42px] flex-shrink-0 items-center justify-center rounded-xl"
        style={{
          background: isVerified ? 'var(--vital-tint)' : 'var(--vital-gradient)',
        }}
      >
        {isVerified ? (
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="var(--vital)"
            strokeWidth={2.2}
            strokeLinecap="round"
          >
            <path d="M20 6 9 17l-5-5" />
          </svg>
        ) : (
          <svg
            width="20"
            height="20"
            viewBox="0 0 24 24"
            fill="none"
            stroke="#04140C"
            strokeWidth={2.2}
            strokeLinecap="round"
          >
            <path d="M12 8v8M8 12h8" />
          </svg>
        )}
      </div>

      <div className="min-w-[200px] flex-1">
        <div className="text-xs font-bold text-[var(--text-primary)]">{hospital.name}</div>
        <div className="mt-0.5 font-mono text-[8.5px] uppercase text-[var(--text-secondary)]">
          {hospital.address} · DIDAFTARKAN {formatRelative(hospital.createdAt)}
        </div>
        <div className="mt-0.5 font-mono text-[8px] text-[var(--text-tertiary)]">
          {formatCoords(hospital.lat, hospital.lng)}
          {hospital.driverCount !== undefined && ` · ${hospital.driverCount} SOPIR`}
        </div>
      </div>

      {isPending ? (
        <div className="flex items-center gap-2">
          <PendingBadge />
          <button
            type="button"
            onClick={onReject}
            disabled={busy}
            className="btn-outline-console"
          >
            Tolak
          </button>
          <button
            type="button"
            onClick={onVerify}
            disabled={busy}
            className="btn-vital"
            style={{ padding: '7px 13px', fontSize: 9.5 }}
          >
            {busy ? '...' : 'Verifikasi'}
          </button>
        </div>
      ) : (
        <span
          className="inline-block rounded-md px-2.5 py-[3px] font-mono text-[8px] font-bold uppercase"
          style={
            isVerified
              ? { background: 'var(--vital-tint)', color: 'var(--vital)' }
              : { background: 'var(--siren-tint)', color: 'var(--siren)' }
          }
        >
          {isVerified ? 'Terverifikasi' : 'Ditolak'}
        </span>
      )}
    </div>
  );
}
