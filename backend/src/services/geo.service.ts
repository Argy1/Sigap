import { env } from '../config/env.js';
import { query } from '../db/pool.js';
import type { LatLng } from '../types/index.js';
import { refineByRoad, type RouteEstimate } from './routing.service.js';

/**
 * Pencarian spasial — inti fitur SIG dari proyek ini.
 *
 * STRATEGI DUA TAHAP (dipakai untuk RS maupun sopir):
 *
 *   Tahap 1 — PostGIS KNN. Operator `<->` pada kolom geography memakai index
 *             GiST, jadi mengambil 5 kandidat terdekat dari ribuan baris tetap
 *             cepat. Ini urutan berdasarkan GARIS LURUS.
 *
 *   Tahap 2 — Refine 5 kandidat itu dengan jarak tempuh JALAN sebenarnya.
 *             Penting karena garis lurus menyesatkan: RS di seberang sungai
 *             bisa terlihat 800 m padahal harus memutar 4 km.
 *
 * Kenapa hanya 5 yang di-refine, bukan semua? Karena tahap 2 adalah panggilan
 * jaringan berbayar. KNN menyaring dulu ke kandidat yang masuk akal secara
 * geografis, baru presisi mahal diterapkan pada himpunan kecil itu.
 */

/** Literal PostGIS untuk titik lat/lng. Selalu lewat parameter, tidak pernah string concat. */
const POINT_SQL = 'ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography';

export interface NearbyHospital {
  id: string;
  name: string;
  address: string;
  phone: string | null;
  lat: number;
  lng: number;
  /** Jarak garis lurus dari PostGIS (meter). */
  straightMeters: number;
  /** Hasil refine tahap 2. */
  distanceMeters: number;
  durationSeconds: number;
  source: RouteEstimate['source'];
}

interface HospitalRow {
  id: string;
  name: string;
  address: string;
  phone: string | null;
  lat: string | number;
  lng: string | number;
  straight_m: string | number;
}

/**
 * Cari RS terdekat dari sebuah titik.
 *
 * Hanya RS `verified` yang ikut — RS yang baru mendaftar dan belum diverifikasi
 * admin tidak boleh menerima panggilan darurat sungguhan.
 */
export async function findNearestHospitals(
  point: LatLng,
  limit = env.NEAREST_HOSPITAL_CANDIDATES,
): Promise<NearbyHospital[]> {
  // ---- Tahap 1: KNN PostGIS -------------------------------------------------
  const res = await query<HospitalRow>(
    `
    SELECT
      id,
      name,
      address,
      phone,
      ST_Y(location::geometry) AS lat,
      ST_X(location::geometry) AS lng,
      ST_Distance(location, ${POINT_SQL}) AS straight_m
    FROM hospitals
    WHERE verification_status = 'verified'
    ORDER BY location <-> ${POINT_SQL}
    LIMIT $3
    `,
    [point.lng, point.lat, limit],
  );

  if (res.rows.length === 0) return [];

  const candidates = res.rows.map((r) => ({
    id: r.id,
    name: r.name,
    address: r.address,
    phone: r.phone,
    lat: Number(r.lat),
    lng: Number(r.lng),
    straightMeters: Math.round(Number(r.straight_m)),
  }));

  // ---- Tahap 2: refine jarak tempuh jalan -----------------------------------
  const estimates = await refineByRoad(
    point,
    candidates.map((c) => ({ lat: c.lat, lng: c.lng })),
  );

  return candidates
    .map((c, i) => {
      const est = estimates[i]!;
      return {
        ...c,
        distanceMeters: est.distanceMeters,
        durationSeconds: est.durationSeconds,
        source: est.source,
      };
    })
    // Urutan akhir ditentukan WAKTU TEMPUH, bukan jarak. Untuk ambulans, yang
    // menentukan nyawa adalah menit, bukan kilometer.
    .sort((a, b) => a.durationSeconds - b.durationSeconds);
}

export interface NearbyDriver {
  id: string;
  profileId: string;
  fullName: string;
  phone: string | null;
  vehiclePlate: string | null;
  availabilityStatus: string;
  lat: number | null;
  lng: number | null;
  straightMeters: number | null;
  distanceMeters: number | null;
  durationSeconds: number | null;
  /** False kalau sopir belum pernah mengirim posisi ATAU posisinya sudah basi. */
  hasFreshLocation: boolean;
  /** Kapan posisi terakhir dikirim — biar UI bisa bilang "posisi 12 menit lalu". */
  locationUpdatedAt: string | null;
}

interface DriverRow {
  id: string;
  profile_id: string;
  full_name: string;
  phone: string | null;
  vehicle_plate: string | null;
  availability_status: string;
  lat: string | number | null;
  lng: string | number | null;
  straight_m: string | number | null;
  is_fresh: boolean;
  location_updated_at: Date | null;
}

/**
 * Cari sopir tersedia terdekat DI DALAM satu RS.
 *
 * Pola yang sama persis dengan pencarian RS, hanya ditambah dua filter:
 * `hospital_id` (sopir tidak boleh lintas RS) dan `availability_status`.
 *
 * Sopir tanpa posisi segar tetap dikembalikan — tapi diletakkan paling bawah.
 * Staff RS masih boleh menugaskan mereka secara manual (mis. sopir yang baru
 * mulai shift dan GPS-nya belum sempat mengirim), tapi mereka bukan saran utama.
 */
export async function findNearestDrivers(
  hospitalId: string,
  point: LatLng,
  limit = env.NEAREST_HOSPITAL_CANDIDATES,
): Promise<NearbyDriver[]> {
  const res = await query<DriverRow>(
    `
    SELECT
      d.id,
      d.profile_id,
      p.full_name,
      p.phone,
      d.vehicle_plate,
      d.availability_status,
      ST_Y(d.current_location::geometry) AS lat,
      ST_X(d.current_location::geometry) AS lng,
      CASE WHEN d.current_location IS NULL THEN NULL
           ELSE ST_Distance(d.current_location, ${POINT_SQL}) END AS straight_m,
      (d.current_location IS NOT NULL
        AND d.location_updated_at > now() - make_interval(secs => $4)) AS is_fresh,
      d.location_updated_at
    FROM drivers d
    JOIN profiles p ON p.id = d.profile_id
    WHERE d.hospital_id = $3
      AND d.availability_status = 'available'
      AND p.is_active = true
    ORDER BY
      (d.current_location IS NULL),
      d.current_location <-> ${POINT_SQL}
    LIMIT $5
    `,
    [point.lng, point.lat, hospitalId, env.DRIVER_LOCATION_MAX_AGE_SECONDS, limit],
  );

  if (res.rows.length === 0) return [];

  const candidates = res.rows.map((r) => ({
    id: r.id,
    profileId: r.profile_id,
    fullName: r.full_name,
    phone: r.phone,
    vehiclePlate: r.vehicle_plate,
    availabilityStatus: r.availability_status,
    lat: r.lat === null ? null : Number(r.lat),
    lng: r.lng === null ? null : Number(r.lng),
    straightMeters: r.straight_m === null ? null : Math.round(Number(r.straight_m)),
    hasFreshLocation: r.is_fresh,
    locationUpdatedAt: r.location_updated_at ? r.location_updated_at.toISOString() : null,
  }));

  // Hanya sopir yang punya koordinat yang bisa di-refine.
  const locatable = candidates.filter(
    (c): c is typeof c & { lat: number; lng: number } => c.lat !== null && c.lng !== null,
  );
  const estimates = await refineByRoad(
    point,
    locatable.map((c) => ({ lat: c.lat, lng: c.lng })),
  );
  const byId = new Map(locatable.map((c, i) => [c.id, estimates[i]!]));

  return candidates
    .map((c) => {
      const est = byId.get(c.id);
      return {
        ...c,
        distanceMeters: est?.distanceMeters ?? null,
        durationSeconds: est?.durationSeconds ?? null,
      };
    })
    .sort((a, b) => {
      // Sopir dengan posisi segar selalu di atas.
      if (a.hasFreshLocation !== b.hasFreshLocation) return a.hasFreshLocation ? -1 : 1;
      if (a.durationSeconds === null) return 1;
      if (b.durationSeconds === null) return -1;
      return a.durationSeconds - b.durationSeconds;
    });
}
