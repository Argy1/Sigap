'use client';

import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { ConsoleMap, type MapMarker } from '@/components/dispatch/ConsoleMap';
import { StatCard, TopBar } from '@/components/dispatch/primitives';
import { api } from '@/lib/api';
import { minutesBetween } from '@/lib/format';
import type { EmergencyCall, Hospital } from '@/lib/types';
import { isActiveCall } from '@/lib/types';

/**
 * Statistik Sistem — pandangan admin ke seluruh platform.
 *
 * Sengaja dibuat ringkas: statistik mendalam (heatmap cakupan, analisis
 * isochrone) ada di backlog CLAUDE.md, bukan lingkup must-have. Yang ada di
 * sini cukup untuk menjawab "platform ini sehat atau tidak" dalam sekali lihat.
 */
export default function AdminStatsPage() {
  const [hospitals, setHospitals] = useState<Hospital[]>([]);
  const [calls, setCalls] = useState<EmergencyCall[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const [h, c] = await Promise.all([api.adminHospitals(), api.listCalls()]);
        setHospitals(h.hospitals);
        setCalls(c.calls);
      } catch (err) {
        toast.error(err instanceof Error ? err.message : 'Gagal memuat statistik');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const stats = useMemo(() => {
    const verified = hospitals.filter((h) => h.verificationStatus === 'verified');
    const pending = hospitals.filter((h) => h.verificationStatus === 'unverified');
    const totalDrivers = hospitals.reduce((s, h) => s + (h.driverCount ?? 0), 0);

    const responses = calls
      .map((c) => minutesBetween(c.createdAt, c.arrivedAt))
      .filter((m): m is number => m !== null);

    const guestCalls = calls.filter((c) => c.isGuest);

    return {
      verified: verified.length,
      pending: pending.length,
      totalHospitals: hospitals.length,
      totalDrivers,
      totalCalls: calls.length,
      activeCalls: calls.filter(isActiveCall).length,
      completed: calls.filter((c) => c.status === 'completed').length,
      guestShare:
        calls.length > 0 ? Math.round((guestCalls.length / calls.length) * 100) : 0,
      avgResponse:
        responses.length > 0
          ? responses.reduce((a, b) => a + b, 0) / responses.length
          : null,
    };
  }, [hospitals, calls]);

  const markers = useMemo<MapMarker[]>(
    () =>
      hospitals.map((h, i) => ({
        id: h.id,
        position: { lat: h.lat, lng: h.lng },
        label: String(i + 1),
        tone: h.verificationStatus === 'verified' ? 'vital' : 'muted',
        title: `${h.name} (${h.verificationStatus})`,
      })),
    [hospitals],
  );

  if (loading) return <div className="mono-sub py-16 text-center">Memuat statistik...</div>;

  return (
    <>
      <TopBar
        title="Statistik Sistem"
        subtitle="Ringkasan seluruh platform Sigap — Kota Bogor"
      />

      <div className="mb-4 flex flex-wrap gap-3.5">
        <StatCard
          label="RS TERVERIFIKASI"
          value={`${stats.verified}/${stats.totalHospitals}`}
          sub={stats.pending > 0 ? `${stats.pending} MENUNGGU` : 'SEMUA DIPROSES'}
          tone={stats.pending > 0 ? 'amber' : 'default'}
        />
        <StatCard label="TOTAL SOPIR" value={stats.totalDrivers} sub="SELURUH RS" />
        <StatCard
          label="TOTAL PANGGILAN"
          value={stats.totalCalls}
          sub={`${stats.completed} SELESAI`}
        />
        <StatCard
          label="SOS AKTIF"
          value={stats.activeCalls}
          tone={stats.activeCalls > 0 ? 'siren' : 'default'}
          sub={stats.activeCalls > 0 ? 'SEDANG BERJALAN' : 'TIDAK ADA'}
        />
      </div>

      <div className="mb-4 flex flex-wrap gap-3.5">
        <StatCard
          label="RATA-RATA RESPON"
          value={stats.avgResponse === null ? '—' : stats.avgResponse.toFixed(1)}
          unit={stats.avgResponse === null ? undefined : 'MNT'}
          sub="SOS SAMPAI SOPIR TIBA"
        />
        <StatCard
          label="PANGGILAN MODE TAMU"
          value={`${stats.guestShare}%`}
          sub="SOS TANPA LOGIN"
        />
      </div>

      <div className="mono-label mb-2.5">Sebaran Rumah Sakit Terdaftar</div>
      <ConsoleMap markers={markers} minHeight={340} />
    </>
  );
}
