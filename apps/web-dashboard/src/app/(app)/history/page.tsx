'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { StatCard, StatusChip, TopBar } from '@/components/dispatch/primitives';
import { api } from '@/lib/api';
import { formatDateTime, minutesBetween } from '@/lib/format';
import type { CallStatus, EmergencyCall } from '@/lib/types';
import { cn } from '@/lib/utils';

const FILTERS: { value: CallStatus | 'all'; label: string }[] = [
  { value: 'all', label: 'SEMUA' },
  { value: 'completed', label: 'SELESAI' },
  { value: 'cancelled', label: 'DIBATALKAN' },
];

/** Riwayat SOS milik RS pengguna — dipersempit backend, bukan di sini. */
export default function HistoryPage() {
  const [calls, setCalls] = useState<EmergencyCall[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<CallStatus | 'all'>('all');

  useEffect(() => {
    (async () => {
      try {
        const { calls } = await api.listCalls();
        setCalls(calls);
      } catch (err) {
        toast.error(err instanceof Error ? err.message : 'Gagal memuat riwayat');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const filtered = useMemo(
    () => (filter === 'all' ? calls : calls.filter((c) => c.status === filter)),
    [calls, filter],
  );

  const stats = useMemo(() => {
    const completed = calls.filter((c) => c.status === 'completed');
    const cancelled = calls.filter((c) => c.status === 'cancelled');
    const responses = calls
      .map((c) => minutesBetween(c.createdAt, c.arrivedAt))
      .filter((m): m is number => m !== null);
    return {
      total: calls.length,
      completed: completed.length,
      cancelled: cancelled.length,
      avg:
        responses.length > 0
          ? responses.reduce((a, b) => a + b, 0) / responses.length
          : null,
    };
  }, [calls]);

  return (
    <>
      <TopBar
        title="Riwayat SOS"
        subtitle={`${calls.length} panggilan tercatat di rumah sakit ini`}
        actions={
          <div className="flex gap-1.5">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                type="button"
                onClick={() => setFilter(f.value)}
                className={cn(
                  'rounded-[9px] border px-3 py-1.5 font-mono text-[8.5px] font-bold uppercase tracking-[0.04em] transition-colors',
                  filter === f.value
                    ? 'border-transparent text-[var(--on-vital)]'
                    : 'border-[var(--border-subtle)] text-[var(--text-secondary)]',
                )}
                style={
                  filter === f.value ? { background: 'var(--vital-gradient)' } : undefined
                }
              >
                {f.label}
              </button>
            ))}
          </div>
        }
      />

      <div className="mb-4 flex flex-wrap gap-3.5">
        <StatCard label="TOTAL PANGGILAN" value={stats.total} />
        <StatCard label="SELESAI" value={stats.completed} tone="vital" />
        <StatCard label="DIBATALKAN" value={stats.cancelled} tone="siren" />
        <StatCard
          label="RATA-RATA RESPON"
          value={stats.avg === null ? '—' : stats.avg.toFixed(1)}
          unit={stats.avg === null ? undefined : 'MNT'}
          sub="SOS SAMPAI TIBA"
        />
      </div>

      <div className="card-surface overflow-hidden">
        <div className="flex items-center gap-3 border-b border-[var(--divider)] bg-[color-mix(in_srgb,var(--text-primary)_2%,transparent)] px-4 py-3 font-mono text-[8.5px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
          <div className="w-[70px]">Kode</div>
          <div className="flex-[2]">Pasien</div>
          <div className="flex-[2]">Lokasi</div>
          <div className="flex-1">Sopir</div>
          <div className="w-[110px]">Waktu</div>
          <div className="w-[80px]">Respon</div>
          <div className="w-[150px]">Status</div>
        </div>

        {loading && <div className="mono-sub px-4 py-10 text-center">Memuat...</div>}
        {!loading && filtered.length === 0 && (
          <div className="mono-sub px-4 py-10 text-center">Belum ada data.</div>
        )}

        {filtered.map((c) => {
          const response = minutesBetween(c.createdAt, c.arrivedAt);
          return (
            <Link
              key={c.id}
              href={`/sos/${c.id}`}
              className="flex items-center gap-3 border-b border-[var(--divider)] px-4 py-3 text-[10.5px] text-[var(--text-primary)] transition-colors last:border-b-0 hover:bg-[var(--vital-tint)]"
            >
              <div className="w-[70px] font-mono text-[9.5px] font-bold text-[var(--vital)]">
                #{c.callCode}
              </div>
              <div className="min-w-0 flex-[2]">
                <div className="truncate font-semibold">{c.patientName}</div>
                {c.isGuest && (
                  <div className="font-mono text-[7.5px] uppercase text-[var(--amber-text)]">
                    mode tamu
                  </div>
                )}
              </div>
              <div className="min-w-0 flex-[2] truncate font-mono text-[8.5px] text-[var(--text-secondary)]">
                {c.patientAddress ?? '—'}
              </div>
              <div className="min-w-0 flex-1 truncate">{c.driverName ?? '—'}</div>
              <div className="w-[110px] font-mono text-[8.5px] text-[var(--text-secondary)]">
                {formatDateTime(c.createdAt)}
              </div>
              <div className="w-[80px] font-mono text-[9.5px] font-bold text-[var(--vital)]">
                {response === null ? '—' : `${response} MNT`}
              </div>
              <div className="w-[150px]">
                <StatusChip status={c.status} />
              </div>
            </Link>
          );
        })}
      </div>
    </>
  );
}
