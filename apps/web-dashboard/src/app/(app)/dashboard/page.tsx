'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { useAuth } from '@/components/AuthProvider';
import { ConsoleMap, type MapMarker } from '@/components/dispatch/ConsoleMap';
import { LiveDot, StatCard, StatusChip, TopBar } from '@/components/dispatch/primitives';
import { useSocket, useSocketEvent } from '@/hooks/useSocket';
import { api } from '@/lib/api';
import { formatRelative, minutesBetween } from '@/lib/format';
import type { Driver, EmergencyCall, Hospital } from '@/lib/types';
import { isActiveCall } from '@/lib/types';
import { cn } from '@/lib/utils';

/**
 * Dashboard Utama — layar yang paling banyak dipandangi staff IGD.
 *
 * Semua yang tampil di sini bergerak sendiri: SOS baru muncul lewat Socket.io
 * tanpa refresh, perubahan status ikut tercermin langsung. Staff tidak boleh
 * perlu menekan tombol muat ulang saat ada panggilan darurat masuk.
 */
export default function DashboardPage() {
  const { user } = useAuth();
  const router = useRouter();
  const { socket, connected } = useSocket(true);

  const [calls, setCalls] = useState<EmergencyCall[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [hospital, setHospital] = useState<Hospital | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const [c, d] = await Promise.all([api.listCalls(), api.listDrivers()]);
      setCalls(c.calls);
      setDrivers(d.drivers);
      if (user?.hospitalId) {
        const h = await api.getHospital(user.hospitalId);
        setHospital(h.hospital);
      }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal memuat data');
    } finally {
      setLoading(false);
    }
  }, [user?.hospitalId]);

  useEffect(() => {
    void load();
  }, [load]);

  /** SOS baru: sisipkan di paling atas + bunyikan notifikasi. */
  useSocketEvent<EmergencyCall>(socket, 'sos:new', (call) => {
    setCalls((prev) => (prev.some((c) => c.id === call.id) ? prev : [call, ...prev]));
    toast.error(`SOS BARU · ${call.patientName}`, {
      description: call.patientAddress ?? 'Lokasi diterima',
      action: { label: 'Buka', onClick: () => router.push(`/sos/${call.id}`) },
      duration: 10_000,
    });
    playAlert();
  });

  /** Perubahan status: ganti di tempat, jangan muat ulang seluruh daftar. */
  useSocketEvent<EmergencyCall>(socket, 'sos:updated', (call) => {
    setCalls((prev) => {
      const idx = prev.findIndex((c) => c.id === call.id);
      if (idx === -1) return [call, ...prev];
      const next = [...prev];
      next[idx] = call;
      return next;
    });
  });

  /** Posisi sopir bergerak — perbarui pin di peta tanpa memuat ulang apa pun. */
  useSocketEvent<{ callId: string; lat: number; lng: number }>(
    socket,
    'driver:location',
    ({ callId, lat, lng }) => {
      setCalls((prev) =>
        prev.map((c) => (c.id === callId ? { ...c, driverLocation: { lat, lng } } : c)),
      );
    },
  );

  const activeCalls = useMemo(() => calls.filter(isActiveCall), [calls]);
  const pendingCalls = useMemo(
    () => activeCalls.filter((c) => c.status === 'pending'),
    [activeCalls],
  );

  const stats = useMemo(() => {
    const availableDrivers = drivers.filter((d) => d.availabilityStatus === 'available');

    const today = new Date().toDateString();
    const completedToday = calls.filter(
      (c) => c.status === 'completed' && new Date(c.createdAt).toDateString() === today,
    );

    // Waktu respons = dari SOS masuk sampai sopir tiba di lokasi pasien.
    const responseTimes = calls
      .map((c) => minutesBetween(c.createdAt, c.arrivedAt))
      .filter((m): m is number => m !== null);
    const avgResponse =
      responseTimes.length > 0
        ? responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length
        : null;

    return {
      activeCount: activeCalls.length,
      pendingCount: pendingCalls.length,
      availableDrivers: availableDrivers.length,
      totalDrivers: drivers.length,
      avgResponse,
      completedToday: completedToday.length,
    };
  }, [calls, drivers, activeCalls, pendingCalls]);

  /** Pin peta: panggilan aktif (bernomor) + posisi sopir yang sedang bertugas. */
  const markers = useMemo<MapMarker[]>(() => {
    const callPins: MapMarker[] = activeCalls.map((c, i) => ({
      id: c.id,
      position: c.location,
      label: String(i + 1),
      tone: c.status === 'pending' ? 'siren' : 'vital',
      title: `${c.callCode} — ${c.patientName}`,
      onClick: () => router.push(`/sos/${c.id}`),
    }));

    const driverPins: MapMarker[] = activeCalls
      .filter((c) => c.driverLocation)
      .map((c) => ({
        id: `driver-${c.id}`,
        position: c.driverLocation!,
        label: 'A',
        tone: 'muted' as const,
        title: `Ambulans — ${c.driverName ?? 'sopir'}`,
      }));

    return [...callPins, ...driverPins];
  }, [activeCalls, router]);

  return (
    <>
      <TopBar
        title="Dashboard"
        subtitle="Pantauan panggilan darurat secara langsung"
        actions={<LiveDot connected={connected} />}
      />

      <div className="mb-4 flex flex-wrap gap-3.5">
        <StatCard
          label="SOS AKTIF"
          value={stats.activeCount}
          tone={stats.pendingCount > 0 ? 'siren' : 'default'}
          sub={stats.pendingCount > 0 ? `${stats.pendingCount} BUTUH RESPONS` : 'SEMUA TERTANGANI'}
        />
        <StatCard
          label="SOPIR TERSEDIA"
          value={`${stats.availableDrivers}/${stats.totalDrivers}`}
          sub="SIAP DITUGASKAN"
        />
        <StatCard
          label="RATA-RATA RESPON"
          value={stats.avgResponse === null ? '—' : stats.avgResponse.toFixed(1)}
          unit={stats.avgResponse === null ? undefined : 'MNT'}
          sub={stats.avgResponse === null ? 'BELUM ADA DATA' : 'SOS SAMPAI TIBA'}
        />
        <StatCard
          label="SELESAI HARI INI"
          value={stats.completedToday}
          sub={stats.completedToday > 0 ? 'SEMUA TUNTAS' : 'BELUM ADA'}
        />
      </div>

      <div className="flex flex-col gap-4 lg:flex-row">
        <ConsoleMap
          className="flex-[1.3]"
          markers={markers}
          origin={hospital ? { lat: hospital.lat, lng: hospital.lng } : null}
          minHeight={380}
        />

        <div className="flex max-h-[380px] flex-1 flex-col gap-2.5 overflow-y-auto pr-1">
          {loading && (
            <div className="mono-sub py-8 text-center">Memuat panggilan...</div>
          )}

          {!loading && activeCalls.length === 0 && (
            <div className="card-surface flex flex-1 flex-col items-center justify-center px-6 py-10 text-center">
              <div
                className="mb-3 h-2 w-2 rounded-full live-dot"
                style={{ background: 'var(--vital)', boxShadow: '0 0 0 5px var(--vital-tint)' }}
              />
              <div className="font-display text-[12.5px] font-bold text-[var(--text-primary)]">
                TIDAK ADA SOS AKTIF
              </div>
              <div className="mt-1.5 text-[9.5px] font-medium leading-relaxed text-[var(--text-secondary)]">
                Panggilan darurat baru akan muncul di sini
                <br />
                secara otomatis tanpa perlu memuat ulang
              </div>
            </div>
          )}

          {activeCalls.map((call) => (
            <SosCard key={call.id} call={call} />
          ))}
        </div>
      </div>
    </>
  );
}

/** Kartu SOS — garis kiri merah tebal, replikasi `.sos-card` di mockup. */
function SosCard({ call }: { call: EmergencyCall }) {
  const pending = call.status === 'pending';
  return (
    <Link
      href={`/sos/${call.id}`}
      className={cn(
        'card-surface block px-3.5 py-3 transition-transform hover:translate-x-[2px]',
        pending && 'sos-pending',
      )}
      style={{
        borderLeft: `3px solid ${pending ? 'var(--siren-raw)' : 'var(--vital)'}`,
      }}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="text-[11.5px] font-bold text-[var(--text-primary)]">
          {call.patientName}
          {call.isGuest && (
            <span className="ml-1.5 font-mono text-[7.5px] font-bold uppercase text-[var(--amber-text)]">
              · tamu
            </span>
          )}
        </span>
        <span className="whitespace-nowrap font-mono text-[8px] font-semibold text-[var(--text-secondary)]">
          {formatRelative(call.createdAt)}
        </span>
      </div>

      <div className="mt-1.5 font-mono text-[8.5px] uppercase text-[var(--text-secondary)]">
        {call.patientAddress ?? '—'}
      </div>

      <div className="mt-2 flex items-center gap-2">
        <StatusChip status={call.status} />
        <span className="font-mono text-[7.5px] font-bold text-[var(--text-tertiary)]">
          #{call.callCode}
        </span>
      </div>
    </Link>
  );
}

/**
 * Nada peringatan singkat lewat Web Audio API.
 *
 * Sengaja tidak memakai file audio: satu berkas aset lagi untuk dua nada beep,
 * dan berkas eksternal bisa gagal dimuat justru saat paling dibutuhkan.
 */
function playAlert() {
  try {
    const Ctx =
      window.AudioContext ??
      (window as unknown as { webkitAudioContext?: typeof AudioContext })
        .webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();

    [0, 0.18].forEach((offset) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 880;
      gain.gain.setValueAtTime(0.0001, ctx.currentTime + offset);
      gain.gain.exponentialRampToValueAtTime(0.15, ctx.currentTime + offset + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + offset + 0.14);
      osc.connect(gain).connect(ctx.destination);
      osc.start(ctx.currentTime + offset);
      osc.stop(ctx.currentTime + offset + 0.16);
    });

    setTimeout(() => void ctx.close(), 800);
  } catch {
    // Browser memblokir audio sebelum ada interaksi pengguna — abaikan,
    // notifikasi visual (toast + denyut kartu) tetap muncul.
  }
}
