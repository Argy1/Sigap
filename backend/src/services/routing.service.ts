import { env, hasGoogleMaps } from '../config/env.js';
import type { LatLng } from '../types/index.js';

/**
 * Satu-satunya titik kontak dengan Google Maps.
 *
 * Dipanggil HANYA dari backend, tidak pernah dari client — supaya API key tidak
 * bocor dan supaya SOS mode tamu tetap bisa jalan tanpa autentikasi apa pun.
 *
 * Kalau GOOGLE_MAPS_API_KEY kosong, seluruh fungsi di sini otomatis memakai
 * perhitungan fallback. Aplikasi tetap berfungsi penuh — hanya angkanya
 * perkiraan garis lurus terkoreksi, bukan jarak tempuh jalan sebenarnya.
 */

// --------------------------------------------------------------------------
// Fallback: haversine + koreksi jalan kota
// --------------------------------------------------------------------------

/** Rasio jarak jalan terhadap garis lurus untuk kota padat seperti Bogor. */
const ROAD_DETOUR_FACTOR = 1.35;
/** Kecepatan rata-rata ambulans di jalan kota (km/jam). */
const AVG_SPEED_KMH = 32;

const EARTH_RADIUS_M = 6_371_000;
const toRad = (deg: number) => (deg * Math.PI) / 180;

export function haversineMeters(a: LatLng, b: LatLng): number {
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(lat1) * Math.cos(lat2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

function estimateFallback(origin: LatLng, dest: LatLng): RouteEstimate {
  const straight = haversineMeters(origin, dest);
  const distanceMeters = Math.round(straight * ROAD_DETOUR_FACTOR);
  const durationSeconds = Math.round((distanceMeters / 1000 / AVG_SPEED_KMH) * 3600);
  return { distanceMeters, durationSeconds, source: 'estimate' };
}

// --------------------------------------------------------------------------
// Kontrak publik
// --------------------------------------------------------------------------

export interface RouteEstimate {
  distanceMeters: number;
  durationSeconds: number;
  /** 'google' = jarak tempuh jalan asli; 'estimate' = haversine terkoreksi. */
  source: 'google' | 'estimate';
}

/**
 * Refine sekumpulan kandidat dengan jarak tempuh jalan sebenarnya.
 *
 * Memakai Distance Matrix API, bukan Directions API: 1 origin -> N destinations
 * selesai dalam SATU request, sedangkan Directions butuh N request untuk hasil
 * yang sama. Maksud spesifikasi (jarak jalan asli, dipanggil dari backend) tetap
 * terpenuhi identik.
 *
 * Kalau API gagal atau key tidak ada, hasil fallback dikembalikan — pencarian
 * RS terdekat TIDAK PERNAH gagal total hanya karena Google bermasalah. Ini
 * jalur darurat; ketersediaan lebih penting daripada presisi.
 */
export async function refineByRoad(
  origin: LatLng,
  destinations: readonly LatLng[],
): Promise<RouteEstimate[]> {
  if (destinations.length === 0) return [];

  if (!hasGoogleMaps) {
    return destinations.map((d) => estimateFallback(origin, d));
  }

  try {
    const url = new URL('https://maps.googleapis.com/maps/api/distancematrix/json');
    url.searchParams.set('origins', `${origin.lat},${origin.lng}`);
    url.searchParams.set(
      'destinations',
      destinations.map((d) => `${d.lat},${d.lng}`).join('|'),
    );
    url.searchParams.set('mode', 'driving');
    url.searchParams.set('departure_time', 'now');
    url.searchParams.set('key', env.GOOGLE_MAPS_API_KEY);

    const res = await fetch(url, { signal: AbortSignal.timeout(5_000) });
    const data = (await res.json()) as {
      status: string;
      rows?: Array<{
        elements: Array<{
          status: string;
          distance?: { value: number };
          duration?: { value: number };
          duration_in_traffic?: { value: number };
        }>;
      }>;
    };

    if (data.status !== 'OK' || !data.rows?.[0]) {
      console.warn(`[routing] Distance Matrix status=${data.status}, pakai fallback`);
      return destinations.map((d) => estimateFallback(origin, d));
    }

    const elements = data.rows[0].elements;
    return destinations.map((d, i) => {
      const el = elements[i];
      if (!el || el.status !== 'OK' || !el.distance || !el.duration) {
        return estimateFallback(origin, d);
      }
      return {
        distanceMeters: el.distance.value,
        durationSeconds: (el.duration_in_traffic ?? el.duration).value,
        source: 'google' as const,
      };
    });
  } catch (err) {
    console.warn(
      '[routing] Distance Matrix gagal, pakai fallback:',
      err instanceof Error ? err.message : err,
    );
    return destinations.map((d) => estimateFallback(origin, d));
  }
}

/**
 * Reverse geocoding: koordinat -> alamat yang bisa dibaca manusia.
 *
 * Ini yang membuat pasien tidak perlu menyebutkan alamat sama sekali — inti
 * dari masalah yang diselesaikan aplikasi ini.
 */
export async function reverseGeocode(point: LatLng): Promise<string> {
  const placeholder = `Lokasi GPS ${point.lat.toFixed(4)}, ${point.lng.toFixed(4)}`;

  if (!hasGoogleMaps) return placeholder;

  try {
    const url = new URL('https://maps.googleapis.com/maps/api/geocode/json');
    url.searchParams.set('latlng', `${point.lat},${point.lng}`);
    url.searchParams.set('language', 'id');
    url.searchParams.set('key', env.GOOGLE_MAPS_API_KEY);

    const res = await fetch(url, { signal: AbortSignal.timeout(5_000) });
    const data = (await res.json()) as {
      status: string;
      results?: Array<{ formatted_address: string }>;
    };

    if (data.status !== 'OK' || !data.results?.[0]) return placeholder;
    return data.results[0].formatted_address;
  } catch {
    return placeholder;
  }
}

/** Untuk ditampilkan di health check & dashboard: mode routing yang aktif. */
export const routingMode = (): 'google' | 'fallback' => (hasGoogleMaps ? 'google' : 'fallback');
