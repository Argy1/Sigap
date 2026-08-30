import { query, queryOne } from '../db/pool.js';
import type { CallStatus, LatLng } from '../types/index.js';
import { badRequest, notFound } from '../utils/errors.js';
import { findNearestHospitals } from './geo.service.js';
import { reverseGeocode } from './routing.service.js';

/**
 * Orkestrasi golden path. Controller memanggil fungsi-fungsi di sini; seluruh
 * aturan alur SOS tinggal di satu tempat.
 */

// --------------------------------------------------------------------------
// Bentuk data yang dikirim ke client
// --------------------------------------------------------------------------

export interface EmergencyCallDTO {
  id: string;
  callCode: string;
  patientId: string | null;
  hospitalId: string | null;
  hospitalName: string | null;
  driverId: string | null;
  driverName: string | null;
  driverPhone: string | null;
  vehiclePlate: string | null;
  patientName: string;
  patientPhone: string | null;
  isGuest: boolean;
  location: LatLng;
  patientAddress: string | null;
  status: CallStatus;
  conditionNote: string | null;
  cancelReason: string | null;
  medical: {
    bloodType: string | null;
    allergies: string[];
    medicalHistory: string | null;
  } | null;
  driverLocation: LatLng | null;
  createdAt: string;
  confirmedAt: string | null;
  enRouteAt: string | null;
  arrivedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
}

/**
 * SELECT bersama untuk semua pembacaan panggilan, supaya bentuk DTO selalu
 * konsisten di seluruh endpoint dan event socket.
 *
 * Perhatikan: query ini TIDAK punya klausa WHERE. Pemanggil WAJIB menambahkan
 * filter kepemilikan sendiri — lihat komentar di rbac.ts.
 */
const CALL_SELECT = `
  SELECT
    ec.id, ec.call_code, ec.patient_id, ec.hospital_id, ec.driver_id,
    ST_Y(ec.patient_location::geometry) AS lat,
    ST_X(ec.patient_location::geometry) AS lng,
    ec.patient_address, ec.guest_name, ec.guest_phone, ec.medical_snapshot,
    ec.status, ec.condition_note, ec.cancel_reason,
    ec.created_at, ec.confirmed_at, ec.en_route_at, ec.arrived_at,
    ec.completed_at, ec.cancelled_at,
    h.name  AS hospital_name,
    pp.full_name AS patient_name,
    pp.phone     AS patient_phone,
    dp.full_name AS driver_name,
    dp.phone     AS driver_phone,
    d.vehicle_plate,
    ST_Y(d.current_location::geometry) AS driver_lat,
    ST_X(d.current_location::geometry) AS driver_lng
  FROM emergency_calls ec
  LEFT JOIN hospitals h  ON h.id = ec.hospital_id
  LEFT JOIN profiles  pp ON pp.id = ec.patient_id
  LEFT JOIN drivers   d  ON d.id = ec.driver_id
  LEFT JOIN profiles  dp ON dp.id = d.profile_id
`;

interface CallRow {
  id: string;
  call_code: string;
  patient_id: string | null;
  hospital_id: string | null;
  driver_id: string | null;
  lat: string | number;
  lng: string | number;
  patient_address: string | null;
  guest_name: string | null;
  guest_phone: string | null;
  medical_snapshot: {
    bloodType?: string | null;
    allergies?: string[];
    medicalHistory?: string | null;
  } | null;
  status: CallStatus;
  condition_note: string | null;
  cancel_reason: string | null;
  created_at: Date;
  confirmed_at: Date | null;
  en_route_at: Date | null;
  arrived_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  hospital_name: string | null;
  patient_name: string | null;
  patient_phone: string | null;
  driver_name: string | null;
  driver_phone: string | null;
  vehicle_plate: string | null;
  driver_lat: string | number | null;
  driver_lng: string | number | null;
}

const iso = (d: Date | null) => (d ? d.toISOString() : null);

export function toCallDTO(r: CallRow): EmergencyCallDTO {
  return {
    id: r.id,
    callCode: r.call_code,
    patientId: r.patient_id,
    hospitalId: r.hospital_id,
    hospitalName: r.hospital_name,
    driverId: r.driver_id,
    driverName: r.driver_name,
    driverPhone: r.driver_phone,
    vehiclePlate: r.vehicle_plate,
    // Mode tamu: nama diambil dari guest_name, bukan dari profil yang tidak ada.
    patientName: r.patient_name ?? r.guest_name ?? 'Pasien Tanpa Nama',
    patientPhone: r.patient_phone ?? r.guest_phone,
    isGuest: r.patient_id === null,
    location: { lat: Number(r.lat), lng: Number(r.lng) },
    patientAddress: r.patient_address,
    status: r.status,
    conditionNote: r.condition_note,
    cancelReason: r.cancel_reason,
    medical: r.medical_snapshot
      ? {
          bloodType: r.medical_snapshot.bloodType ?? null,
          allergies: r.medical_snapshot.allergies ?? [],
          medicalHistory: r.medical_snapshot.medicalHistory ?? null,
        }
      : null,
    driverLocation:
      r.driver_lat === null || r.driver_lng === null
        ? null
        : { lat: Number(r.driver_lat), lng: Number(r.driver_lng) },
    createdAt: r.created_at.toISOString(),
    confirmedAt: iso(r.confirmed_at),
    enRouteAt: iso(r.en_route_at),
    arrivedAt: iso(r.arrived_at),
    completedAt: iso(r.completed_at),
    cancelledAt: iso(r.cancelled_at),
  };
}

export async function getCallById(id: string): Promise<EmergencyCallDTO | null> {
  const row = await queryOne<CallRow>(`${CALL_SELECT} WHERE ec.id = $1`, [id]);
  return row ? toCallDTO(row) : null;
}

export async function listCalls(
  where: string,
  params: readonly unknown[],
  limit = 50,
): Promise<EmergencyCallDTO[]> {
  const res = await query<CallRow>(
    `${CALL_SELECT} WHERE ${where} ORDER BY ec.created_at DESC LIMIT ${limit}`,
    params,
  );
  return res.rows.map(toCallDTO);
}

// --------------------------------------------------------------------------
// Langkah 1–2 golden path: buat panggilan + tentukan RS terdekat
// --------------------------------------------------------------------------

export interface CreateCallInput {
  patientId: string | null;
  location: LatLng;
  conditionNote?: string | null;
  guestName?: string | null;
  guestPhone?: string | null;
}

/**
 * Membuat panggilan darurat.
 *
 * Urutan sengaja dibuat begini: reverse geocoding dan pencarian RS dijalankan
 * BERSAMAAN, lalu baris disimpan. Keduanya panggilan jaringan; menjalankannya
 * paralel memangkas beberapa ratus milidetik dari jalur paling kritis di
 * seluruh aplikasi.
 *
 * Kalau tidak ada RS terverifikasi sama sekali, panggilan TETAP disimpan dengan
 * hospital_id NULL. Kehilangan catatan SOS jauh lebih buruk daripada SOS yang
 * belum punya tujuan — admin masih bisa menugaskannya manual.
 */
export async function createEmergencyCall(
  input: CreateCallInput,
): Promise<{ call: EmergencyCallDTO; candidates: Awaited<ReturnType<typeof findNearestHospitals>> }> {
  const { location } = input;

  const [address, hospitals, medical] = await Promise.all([
    reverseGeocode(location),
    findNearestHospitals(location),
    input.patientId ? loadMedicalSnapshot(input.patientId) : Promise.resolve(null),
  ]);

  const chosen = hospitals[0] ?? null;

  const inserted = await queryOne<{ id: string }>(
    `INSERT INTO emergency_calls
       (patient_id, hospital_id, patient_location, patient_address,
        guest_name, guest_phone, medical_snapshot, condition_note, status)
     VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5,
             $6, $7, $8, $9, 'pending')
     RETURNING id`,
    [
      input.patientId,
      chosen?.id ?? null,
      location.lng,
      location.lat,
      address,
      input.guestName ?? null,
      input.guestPhone ?? null,
      medical ? JSON.stringify(medical) : null,
      input.conditionNote ?? null,
    ],
  );

  const call = await getCallById(inserted!.id);
  return { call: call!, candidates: hospitals };
}

async function loadMedicalSnapshot(patientId: string) {
  const row = await queryOne<{
    blood_type: string | null;
    allergies: string[];
    medical_history: string | null;
  }>(
    `SELECT blood_type, allergies, medical_history
     FROM patient_profiles WHERE profile_id = $1`,
    [patientId],
  );
  if (!row) return null;
  return {
    bloodType: row.blood_type,
    allergies: row.allergies ?? [],
    medicalHistory: row.medical_history,
  };
}

// --------------------------------------------------------------------------
// Langkah 7: transisi status
// --------------------------------------------------------------------------

/**
 * Transisi status yang sah. Bentuknya mesin keadaan eksplisit supaya tidak
 * mungkin ada panggilan yang, misalnya, melompat dari `pending` langsung ke
 * `completed` tanpa pernah ada sopir yang berangkat.
 */
const ALLOWED_TRANSITIONS: Record<CallStatus, CallStatus[]> = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['en_route', 'cancelled'],
  en_route: ['arrived', 'cancelled'],
  arrived: ['completed', 'cancelled'],
  completed: [],
  cancelled: [],
};

const TIMESTAMP_COLUMN: Partial<Record<CallStatus, string>> = {
  confirmed: 'confirmed_at',
  en_route: 'en_route_at',
  arrived: 'arrived_at',
  completed: 'completed_at',
  cancelled: 'cancelled_at',
};

export async function updateCallStatus(
  callId: string,
  next: CallStatus,
  opts: { cancelReason?: string | null } = {},
): Promise<EmergencyCallDTO> {
  const current = await queryOne<{ status: CallStatus; driver_id: string | null }>(
    'SELECT status, driver_id FROM emergency_calls WHERE id = $1',
    [callId],
  );
  if (!current) throw notFound('Panggilan darurat tidak ditemukan');

  if (!ALLOWED_TRANSITIONS[current.status].includes(next)) {
    throw badRequest(
      `Status tidak bisa berpindah dari "${current.status}" ke "${next}"`,
    );
  }

  const tsCol = TIMESTAMP_COLUMN[next];
  await query(
    `UPDATE emergency_calls
     SET status = $2,
         cancel_reason = COALESCE($3, cancel_reason)
         ${tsCol ? `, ${tsCol} = now()` : ''}
     WHERE id = $1`,
    [callId, next, opts.cancelReason ?? null],
  );

  // Sopir dibebaskan begitu tugasnya berakhir — kalau tidak, dia akan hilang
  // selamanya dari daftar "sopir tersedia".
  if (current.driver_id && (next === 'completed' || next === 'cancelled')) {
    await query(
      `UPDATE drivers SET availability_status = 'available' WHERE id = $1`,
      [current.driver_id],
    );
  }

  return (await getCallById(callId))!;
}

// --------------------------------------------------------------------------
// Langkah 4: penugasan hibrida (backend menyarankan, staff RS memutuskan)
// --------------------------------------------------------------------------

export async function assignDriver(
  callId: string,
  driverId: string,
): Promise<{ call: EmergencyCallDTO; previousDriverId: string | null }> {
  const call = await queryOne<{
    status: CallStatus;
    hospital_id: string | null;
    driver_id: string | null;
  }>('SELECT status, hospital_id, driver_id FROM emergency_calls WHERE id = $1', [callId]);
  if (!call) throw notFound('Panggilan darurat tidak ditemukan');

  if (call.status === 'completed' || call.status === 'cancelled') {
    throw badRequest('Panggilan sudah selesai atau dibatalkan');
  }

  // Sopir wajib berasal dari RS yang sama dengan panggilan. Dicek di SQL,
  // bukan hanya dipercaya dari body request.
  const driver = await queryOne<{ id: string; hospital_id: string }>(
    'SELECT id, hospital_id FROM drivers WHERE id = $1',
    [driverId],
  );
  if (!driver) throw notFound('Sopir tidak ditemukan');
  if (driver.hospital_id !== call.hospital_id) {
    throw badRequest('Sopir tersebut bukan bagian dari rumah sakit ini');
  }

  const previousDriverId = call.driver_id;

  await query(
    `UPDATE emergency_calls
     SET driver_id = $2,
         status = CASE WHEN status = 'pending' THEN 'confirmed' ELSE status END,
         confirmed_at = COALESCE(confirmed_at, now())
     WHERE id = $1`,
    [callId, driverId],
  );

  await query(`UPDATE drivers SET availability_status = 'busy' WHERE id = $1`, [driverId]);
  if (previousDriverId && previousDriverId !== driverId) {
    await query(
      `UPDATE drivers SET availability_status = 'available' WHERE id = $1`,
      [previousDriverId],
    );
  }

  return { call: (await getCallById(callId))!, previousDriverId };
}

/**
 * Sopir menolak tugas. Panggilan dikembalikan ke antrean RS (bukan dibatalkan)
 * supaya staff bisa menugaskan sopir lain.
 */
export async function rejectAssignment(
  callId: string,
  driverId: string,
): Promise<EmergencyCallDTO> {
  await query(
    `UPDATE emergency_calls
     SET driver_id = NULL, status = 'pending', confirmed_at = NULL
     WHERE id = $1 AND driver_id = $2`,
    [callId, driverId],
  );
  await query(
    `UPDATE drivers SET availability_status = 'available' WHERE id = $1`,
    [driverId],
  );
  return (await getCallById(callId))!;
}
