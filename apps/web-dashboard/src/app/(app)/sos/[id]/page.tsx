'use client';

import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { toast } from 'sonner';
import { ConsoleMap, type MapMarker } from '@/components/dispatch/ConsoleMap';
import { PulseStepper } from '@/components/dispatch/PulseStepper';
import {
  Avatar,
  Readout,
  StatusChip,
  TopBar,
} from '@/components/dispatch/primitives';
import { useSocket, useSocketEvent } from '@/hooks/useSocket';
import { api } from '@/lib/api';
import {
  formatCoords,
  formatDistance,
  formatDuration,
  formatRelative,
} from '@/lib/format';
import type { EmergencyCall, SuggestedDriver } from '@/lib/types';
import { cn } from '@/lib/utils';

/**
 * Detail SOS & Penugasan Sopir.
 *
 * Layar tempat langkah 4 golden path terjadi: backend MENYARANKAN sopir
 * terdekat, staff RS MEMUTUSKAN. Bukan otomatis penuh — staff sering tahu hal
 * yang tidak diketahui sistem (sopir baru selesai shift, ambulans sedang
 * dibersihkan). Bukan manual penuh — mencari sopir satu per satu terlalu lambat
 * saat setiap detik berarti.
 */
export default function SosDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { socket } = useSocket(true);

  const [call, setCall] = useState<EmergencyCall | null>(null);
  const [suggested, setSuggested] = useState<SuggestedDriver[]>([]);
  const [selectedDriver, setSelectedDriver] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const { call } = await api.getCall(id);
      setCall(call);

      // Saran sopir hanya relevan selagi panggilan masih berjalan.
      if (call.status !== 'completed' && call.status !== 'cancelled') {
        const { drivers } = await api.suggestedDrivers(id);
        setSuggested(drivers);
        setSelectedDriver((prev) => prev ?? drivers[0]?.id ?? null);
      }
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal memuat panggilan');
      router.push('/dashboard');
    } finally {
      setLoading(false);
    }
  }, [id, router]);

  useEffect(() => {
    void load();
  }, [load]);

  useSocketEvent<EmergencyCall>(socket, 'sos:updated', (updated) => {
    if (updated.id === id) setCall(updated);
  });

  useSocketEvent<{ callId: string; lat: number; lng: number }>(
    socket,
    'driver:location',
    ({ callId, lat, lng }) => {
      if (callId === id) {
        setCall((prev) => (prev ? { ...prev, driverLocation: { lat, lng } } : prev));
      }
    },
  );

  async function handleAssign() {
    if (!selectedDriver || !call) return;
    setBusy(true);
    try {
      const { call: updated } = await api.assignDriver(call.id, selectedDriver);
      setCall(updated);
      toast.success(`Sopir ditugaskan ke ${updated.callCode}`);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal menugaskan sopir');
    } finally {
      setBusy(false);
    }
  }

  async function handleCancel() {
    if (!call) return;
    setBusy(true);
    try {
      const { call: updated } = await api.changeStatus(
        call.id,
        'cancelled',
        'Dibatalkan oleh staff rumah sakit',
      );
      setCall(updated);
      toast.success('Panggilan dibatalkan');
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Gagal membatalkan');
    } finally {
      setBusy(false);
    }
  }

  const markers = useMemo<MapMarker[]>(() => {
    if (!call) return [];
    const pins: MapMarker[] = [
      {
        id: 'patient',
        position: call.location,
        label: 'P',
        tone: call.status === 'pending' ? 'siren' : 'vital',
        title: `Pasien — ${call.patientName}`,
      },
    ];
    if (call.driverLocation) {
      pins.push({
        id: 'driver',
        position: call.driverLocation,
        label: 'A',
        tone: 'muted',
        title: `Ambulans — ${call.driverName ?? 'sopir'}`,
      });
    }
    return pins;
  }, [call]);

  if (loading || !call) {
    return <div className="mono-sub py-16 text-center">Memuat panggilan...</div>;
  }

  const finished = call.status === 'completed' || call.status === 'cancelled';

  return (
    <>
      <TopBar
        title={
          <span className="flex items-center gap-2.5">
            <Link
              href="/dashboard"
              className="flex h-7 w-7 items-center justify-center rounded-lg border border-[var(--border-subtle)] text-[var(--text-secondary)] transition-colors hover:text-[var(--vital)]"
              aria-label="Kembali"
            >
              <svg
                width="13"
                height="13"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2.5}
                strokeLinecap="round"
              >
                <path d="m15 18-6-6 6-6" />
              </svg>
            </Link>
            SOS #{call.callCode} — {call.patientName}
          </span>
        }
        subtitle={`${formatRelative(call.createdAt)} · ${call.patientAddress ?? formatCoords(call.location.lat, call.location.lng)}`}
        actions={<StatusChip status={call.status} size="md" />}
      />

      <div className="flex flex-col gap-4 xl:flex-row">
        <div className="flex-[1.5]">
          <ConsoleMap markers={markers} minHeight={340} />

          <div className="card-surface mt-3.5 px-4 py-3.5">
            <div className="mono-label mb-2">Alur Status Panggilan</div>
            <PulseStepper status={call.status} />
          </div>

          <div className="mt-3.5 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Readout
              label="KOORDINAT"
              value={
                <span className="text-[10px]">
                  {formatCoords(call.location.lat, call.location.lng)}
                </span>
              }
            />
            <Readout label="MASUK" value={formatRelative(call.createdAt)} tone="plain" />
            <Readout
              label="SOPIR"
              value={call.driverName ? call.driverName.split(' ')[0] : '—'}
              tone={call.driverName ? 'vital' : 'plain'}
            />
            <Readout
              label="KONTAK"
              value={<span className="text-[10px]">{call.patientPhone ?? '—'}</span>}
              tone="plain"
            />
          </div>
        </div>

        <div className="flex flex-1 flex-col gap-3.5">
          {/* --- Data medis: yang paling menentukan tindakan responder ------ */}
          <div className="card-surface px-4 py-3.5">
            <div className="mono-label mb-2.5">Data Medis Pasien</div>
            {call.medical ? (
              <>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <div className="font-mono text-[8px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
                      Gol. Darah
                    </div>
                    <div className="mt-1 font-display text-sm font-extrabold text-[var(--text-primary)]">
                      {call.medical.bloodType ?? '—'}
                    </div>
                  </div>
                  <div>
                    <div className="font-mono text-[8px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
                      Alergi
                    </div>
                    <div
                      className="mt-1 font-display text-sm font-extrabold"
                      style={{
                        color:
                          call.medical.allergies.length > 0
                            ? 'var(--siren)'
                            : 'var(--text-primary)',
                      }}
                    >
                      {call.medical.allergies.length > 0
                        ? call.medical.allergies.join(', ')
                        : 'Tidak ada'}
                    </div>
                  </div>
                </div>
                {call.medical.medicalHistory && (
                  <div className="mt-3 border-t border-[var(--divider)] pt-2.5">
                    <div className="font-mono text-[8px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
                      Riwayat Penyakit
                    </div>
                    <div className="mt-1 text-[10.5px] font-medium text-[var(--text-primary)]">
                      {call.medical.medicalHistory}
                    </div>
                  </div>
                )}
              </>
            ) : (
              <div
                className="rounded-[10px] px-3 py-2.5 font-mono text-[8.5px] font-bold"
                style={{
                  background: 'var(--amber-tint)',
                  color: 'var(--amber-text)',
                }}
              >
                ⚠ PANGGILAN MODE TAMU — TIDAK ADA DATA MEDIS TERSIMPAN
              </div>
            )}

            {call.conditionNote && (
              <div className="mt-3 border-t border-[var(--divider)] pt-2.5">
                <div className="font-mono text-[8px] font-bold uppercase tracking-[0.04em] text-[var(--text-secondary)]">
                  Kondisi Dilaporkan
                </div>
                <div className="mt-1 text-[10.5px] font-semibold text-[var(--text-primary)]">
                  {call.conditionNote}
                </div>
              </div>
            )}
          </div>

          {/* --- Penugasan hibrida ----------------------------------------- */}
          {!finished && (
            <div className="card-surface px-4 py-3.5">
              <div className="mono-label mb-1">Saran Sopir Terdekat</div>
              <div className="mb-2.5 font-mono text-[7.5px] uppercase tracking-[0.03em] text-[var(--text-tertiary)]">
                Diurutkan waktu tempuh · Anda yang memutuskan
              </div>

              {suggested.length === 0 ? (
                <div
                  className="rounded-[10px] px-3 py-2.5 font-mono text-[8.5px] font-bold"
                  style={{ background: 'var(--amber-tint)', color: 'var(--amber-text)' }}
                >
                  ⚠ TIDAK ADA SOPIR TERSEDIA DI RS INI
                </div>
              ) : (
                <div className="flex flex-col">
                  {suggested.map((d) => {
                    const selected = selectedDriver === d.id;
                    return (
                      <button
                        key={d.id}
                        type="button"
                        onClick={() => setSelectedDriver(d.id)}
                        className={cn(
                          'flex items-center gap-2.5 rounded-[10px] px-2 py-2 text-left transition-colors',
                          selected && 'bg-[var(--vital-tint)]',
                        )}
                      >
                        <Avatar name={d.fullName} size={30} />
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-[11px] font-bold text-[var(--text-primary)]">
                            {d.fullName}
                          </span>
                          <span className="mt-0.5 block font-mono text-[8px] text-[var(--text-secondary)]">
                            {/* Punya koordinat tapi sudah usang tetap ditampilkan
                                jaraknya — menyembunyikannya justru merampas
                                informasi yang berguna dari petugas. Yang perlu
                                jelas adalah SEBERAPA BARU datanya. */}
                            {d.distanceMeters !== null
                              ? `${formatDistance(d.distanceMeters)} · ${formatDuration(d.durationSeconds)}`
                              : 'POSISI BELUM DIKETAHUI'}
                            {d.vehiclePlate ? ` · ${d.vehiclePlate}` : ''}
                          </span>
                          {d.distanceMeters !== null && !d.hasFreshLocation && (
                            <span
                              className="mt-0.5 block font-mono text-[7.5px] font-bold uppercase"
                              style={{ color: 'var(--amber-text)' }}
                            >
                              ⚠ posisi {d.locationUpdatedAt ? formatRelative(d.locationUpdatedAt).toLowerCase() : 'usang'}
                            </span>
                          )}
                        </span>
                        {selected && (
                          <svg
                            width="14"
                            height="14"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="var(--vital)"
                            strokeWidth={2.6}
                            strokeLinecap="round"
                          >
                            <path d="M20 6 9 17l-5-5" />
                          </svg>
                        )}
                      </button>
                    );
                  })}

                  <button
                    type="button"
                    onClick={() => void handleAssign()}
                    disabled={!selectedDriver || busy}
                    className="btn-vital mt-2.5 w-full py-2.5 text-center"
                  >
                    {busy
                      ? 'MEMPROSES...'
                      : call.driverId
                        ? 'ALIHKAN KE SOPIR INI'
                        : `TUGASKAN ${suggested.find((d) => d.id === selectedDriver)?.fullName.toUpperCase() ?? ''}`}
                  </button>
                </div>
              )}
            </div>
          )}

          {/* --- Sopir yang sedang bertugas -------------------------------- */}
          {call.driverName && (
            <div className="card-surface flex items-center gap-3 px-4 py-3">
              <Avatar name={call.driverName} size={36} />
              <div className="min-w-0 flex-1">
                <div className="mono-label">Sopir Bertugas</div>
                <div className="mt-0.5 truncate text-[11px] font-bold text-[var(--text-primary)]">
                  {call.driverName}
                </div>
                <div className="font-mono text-[8px] text-[var(--text-secondary)]">
                  {call.vehiclePlate ?? '—'} · {call.driverPhone ?? '—'}
                </div>
              </div>
            </div>
          )}

          {!finished && (
            <button
              type="button"
              onClick={() => void handleCancel()}
              disabled={busy}
              className="w-full rounded-xl border-[1.5px] px-4 py-2.5 text-[10.5px] font-bold transition-colors"
              style={{
                borderColor: 'color-mix(in srgb, var(--siren-raw) 38%, transparent)',
                color: 'var(--siren)',
              }}
            >
              BATALKAN PANGGILAN
            </button>
          )}

          {call.status === 'cancelled' && call.cancelReason && (
            <div
              className="rounded-xl px-4 py-3 text-[10px] font-semibold"
              style={{ background: 'var(--siren-tint)', color: 'var(--siren)' }}
            >
              Alasan pembatalan: {call.cancelReason}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
