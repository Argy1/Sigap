'use client';

import { useMemo } from 'react';
import { hasGoogleMaps } from '@/lib/config';
import type { LatLng } from '@/lib/types';
import { cn } from '@/lib/utils';
import { GoogleMapPane } from './GoogleMapPane';

export interface MapMarker {
  id: string;
  position: LatLng;
  /** Teks di dalam pin — biasanya nomor urut atau satu huruf. */
  label: string;
  tone: 'siren' | 'vital' | 'muted' | 'admin';
  title?: string;
  onClick?: () => void;
}

export interface ConsoleMapProps {
  markers?: MapMarker[];
  /** Titik pengguna/RS — digambar sebagai dot dengan cincin, bukan pin. */
  origin?: LatLng | null;
  className?: string;
  /** Tinggi minimum area peta. */
  minHeight?: number;
}

/**
 * Panel peta dashboard.
 *
 * Dua implementasi, dipilih otomatis:
 *  - Ada NEXT_PUBLIC_GOOGLE_MAPS_API_KEY -> Google Maps sungguhan.
 *  - Tidak ada                           -> peta bergaya konsol di bawah.
 *
 * Fallback-nya BUKAN placeholder darurat: mockup di /design-reference memang
 * menggambarkan peta abstrak bergaya konsol (grid + garis jalan diagonal), jadi
 * tampilan ini justru yang paling setia ke desain. Posisi pin tetap dihitung
 * dari koordinat asli, hanya latarnya yang bukan citra jalan sungguhan.
 */
export function ConsoleMap(props: ConsoleMapProps) {
  if (hasGoogleMaps) return <GoogleMapPane {...props} />;
  return <FallbackConsoleMap {...props} />;
}

const TONE_COLOR: Record<MapMarker['tone'], string> = {
  siren: 'var(--siren-raw)',
  vital: 'var(--vital)',
  muted: 'color-mix(in srgb, var(--vital) 45%, transparent)',
  admin: 'var(--admin)',
};

function FallbackConsoleMap({
  markers = [],
  origin,
  className,
  minHeight = 360,
}: ConsoleMapProps) {
  /**
   * Proyeksikan lat/lng ke persentase dalam kotak peta.
   *
   * Bounding box dihitung dari semua titik yang ada, lalu diberi padding supaya
   * pin tidak menempel di tepi. Kalau semua titik berimpit (atau cuma ada satu),
   * jangkauan minimum dipakai supaya tidak terjadi pembagian dengan nol.
   */
  const project = useMemo(() => {
    const points = [...markers.map((m) => m.position), ...(origin ? [origin] : [])];
    if (points.length === 0) {
      return () => ({ left: '50%', top: '50%' });
    }

    const lats = points.map((p) => p.lat);
    const lngs = points.map((p) => p.lng);
    const MIN_SPAN = 0.012; // ~1.3 km, skala kota

    const latMid = (Math.min(...lats) + Math.max(...lats)) / 2;
    const lngMid = (Math.min(...lngs) + Math.max(...lngs)) / 2;
    const latSpan = Math.max(Math.max(...lats) - Math.min(...lats), MIN_SPAN) * 1.4;
    const lngSpan = Math.max(Math.max(...lngs) - Math.min(...lngs), MIN_SPAN) * 1.4;

    return (p: LatLng) => ({
      left: `${((p.lng - lngMid) / lngSpan + 0.5) * 100}%`,
      // Lintang naik ke atas, sumbu Y layar naik ke bawah -> dibalik.
      top: `${(0.5 - (p.lat - latMid) / latSpan) * 100}%`,
    });
  }, [markers, origin]);

  return (
    <div
      className={cn(
        'console-map relative overflow-hidden rounded-[15px] border border-[var(--border-subtle)]',
        className,
      )}
      style={{ minHeight }}
    >
      {/* Penanda bahwa ini mode fallback — jujur ke pengguna tanpa mengganggu. */}
      <div className="pointer-events-none absolute bottom-2.5 right-3 font-mono text-[7.5px] font-bold uppercase tracking-widest text-[var(--text-tertiary)]">
        Peta Skematik · Koordinat Presisi
      </div>

      {origin && (
        <div
          className="absolute -translate-x-1/2 -translate-y-1/2"
          style={project(origin)}
          title="Rumah sakit Anda"
        >
          <span className="block h-5 w-5 rounded-full border-2 border-[var(--text-primary)] bg-[color-mix(in_srgb,var(--text-primary)_15%,transparent)]" />
        </div>
      )}

      {markers.map((m) => (
        <button
          key={m.id}
          type="button"
          onClick={m.onClick}
          title={m.title}
          className="absolute -translate-x-1/2 -translate-y-full outline-none focus-visible:ring-2 focus-visible:ring-[var(--vital)]"
          style={{ ...project(m.position), cursor: m.onClick ? 'pointer' : 'default' }}
        >
          <MapPin label={m.label} color={TONE_COLOR[m.tone]} pulsing={m.tone === 'siren'} />
        </button>
      ))}
    </div>
  );
}

/** Pin bentuk tetesan — replikasi `.mpin` di design-reference. */
export function MapPin({
  label,
  color,
  pulsing = false,
}: {
  label: string;
  color: string;
  pulsing?: boolean;
}) {
  return (
    <span
      className={cn(
        'flex h-7 w-7 items-center justify-center rounded-[50%_50%_50%_0] shadow-[0_4px_12px_rgba(0,0,0,0.35)]',
        pulsing && 'sos-pending',
      )}
      style={{ background: color, transform: 'rotate(-45deg)' }}
    >
      <span
        className="font-mono text-[11px] font-extrabold text-white"
        style={{ transform: 'rotate(45deg)' }}
      >
        {label}
      </span>
    </span>
  );
}
