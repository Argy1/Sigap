'use client';

import { AdvancedMarker, APIProvider, Map } from '@vis.gl/react-google-maps';
import { useTheme } from 'next-themes';
import { useMemo } from 'react';
import { GOOGLE_MAPS_KEY } from '@/lib/config';
import { cn } from '@/lib/utils';
import type { ConsoleMapProps } from './ConsoleMap';
import { MapPin } from './ConsoleMap';

/** Pusat Kota Bogor — dipakai saat belum ada titik apa pun untuk difokuskan. */
const BOGOR_CENTER = { lat: -6.5944, lng: 106.7892 };

const TONE_COLOR = {
  siren: '#FF3355',
  vital: '#39E991',
  muted: 'rgba(57,233,145,0.5)',
  admin: '#9333EA',
} as const;

/**
 * Peta Google Maps sungguhan. Hanya dirender kalau
 * NEXT_PUBLIC_GOOGLE_MAPS_API_KEY terisi — pemilihannya ada di ConsoleMap.
 *
 * mapId ikut berganti mengikuti tema supaya peta gelap dipakai di mode gelap;
 * tanpa itu, peta terang menyala terlalu terang di ruang IGD yang temaram.
 */
export function GoogleMapPane({
  markers = [],
  origin,
  className,
  minHeight = 360,
}: ConsoleMapProps) {
  const { resolvedTheme } = useTheme();

  const center = useMemo(() => {
    const points = [...markers.map((m) => m.position), ...(origin ? [origin] : [])];
    if (points.length === 0) return BOGOR_CENTER;
    return {
      lat: points.reduce((s, p) => s + p.lat, 0) / points.length,
      lng: points.reduce((s, p) => s + p.lng, 0) / points.length,
    };
  }, [markers, origin]);

  return (
    <div
      className={cn(
        'overflow-hidden rounded-[15px] border border-[var(--border-subtle)]',
        className,
      )}
      style={{ minHeight }}
    >
      <APIProvider apiKey={GOOGLE_MAPS_KEY}>
        <Map
          style={{ width: '100%', height: '100%', minHeight }}
          defaultCenter={center}
          defaultZoom={14}
          gestureHandling="greedy"
          disableDefaultUI
          zoomControl
          colorScheme={resolvedTheme === 'dark' ? 'DARK' : 'LIGHT'}
          mapId="ambulans-dispatch"
        >
          {origin && (
            <AdvancedMarker position={origin} title="Rumah sakit Anda">
              <span className="block h-5 w-5 rounded-full border-2 border-white bg-[rgba(10,14,20,0.65)]" />
            </AdvancedMarker>
          )}
          {markers.map((m) => (
            <AdvancedMarker
              key={m.id}
              position={m.position}
              title={m.title}
              onClick={m.onClick}
            >
              <MapPin label={m.label} color={TONE_COLOR[m.tone]} pulsing={m.tone === 'siren'} />
            </AdvancedMarker>
          ))}
        </Map>
      </APIProvider>
    </div>
  );
}
