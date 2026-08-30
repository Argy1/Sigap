import bcrypt from 'bcryptjs';
import type { Request, Response } from 'express';
import { z } from 'zod';
import { query, queryOne, withTransaction } from '../db/pool.js';
import { hospitalScopeOf, isPlatformAdmin } from '../middleware/rbac.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../utils/errors.js';
import { pathParam } from '../utils/http.js';

interface DriverRow {
  id: string;
  profile_id: string;
  hospital_id: string;
  full_name: string;
  phone: string | null;
  vehicle_plate: string | null;
  availability_status: string;
  lat: string | number | null;
  lng: string | number | null;
  location_updated_at: Date | null;
  is_active: boolean;
}

const DRIVER_SELECT = `
  SELECT d.id, d.profile_id, d.hospital_id,
         p.full_name, p.phone, p.is_active,
         d.vehicle_plate, d.availability_status,
         ST_Y(d.current_location::geometry) AS lat,
         ST_X(d.current_location::geometry) AS lng,
         d.location_updated_at
  FROM drivers d
  JOIN profiles p ON p.id = d.profile_id
`;

const toDriverDTO = (r: DriverRow) => ({
  id: r.id,
  profileId: r.profile_id,
  hospitalId: r.hospital_id,
  fullName: r.full_name,
  phone: r.phone,
  vehiclePlate: r.vehicle_plate,
  availabilityStatus: r.availability_status,
  isActive: r.is_active,
  location:
    r.lat === null || r.lng === null ? null : { lat: Number(r.lat), lng: Number(r.lng) },
  locationUpdatedAt: r.location_updated_at ? r.location_updated_at.toISOString() : null,
});

/**
 * Daftar sopir.
 *
 * Perhatikan `hospitalScopeOf`: hospital_id TIDAK PERNAH diambil dari query
 * string. Staff RS hanya bisa melihat sopir RS-nya sendiri, titik. Menerima
 * ?hospitalId= dari client akan membuat endpoint ini bocor lintas RS hanya
 * dengan menebak satu uuid.
 */
export const listDrivers = asyncHandler(async (req: Request, res: Response) => {
  const auth = req.auth!;

  if (isPlatformAdmin(auth)) {
    const hospitalId = req.query.hospitalId as string | undefined;
    const rows = await query<DriverRow>(
      `${DRIVER_SELECT} ${hospitalId ? 'WHERE d.hospital_id = $1' : ''} ORDER BY p.full_name`,
      hospitalId ? [hospitalId] : [],
    );
    res.json({ drivers: rows.rows.map(toDriverDTO) });
    return;
  }

  const hospitalId = hospitalScopeOf(auth);
  const rows = await query<DriverRow>(
    `${DRIVER_SELECT} WHERE d.hospital_id = $1 ORDER BY p.full_name`,
    [hospitalId],
  );
  res.json({ drivers: rows.rows.map(toDriverDTO) });
});

export const createDriverSchema = z.object({
  fullName: z.string().trim().min(2, 'Nama minimal 2 karakter'),
  phone: z
    .string()
    .trim()
    .regex(/^[0-9+][0-9\s-]{7,19}$/, 'Format nomor HP tidak valid'),
  password: z.string().min(6, 'Kata sandi minimal 6 karakter'),
  vehiclePlate: z.string().trim().max(20).optional(),
});

/**
 * Staff RS membuatkan akun sopir. Sopir tidak bisa mendaftar sendiri —
 * sesuai mockup layar Masuk Sopir: "akun yang diberikan oleh rumah sakit Anda".
 */
export const createDriver = asyncHandler(async (req: Request, res: Response) => {
  const auth = req.auth!;
  const hospitalId = isPlatformAdmin(auth)
    ? (req.body.hospitalId as string | undefined)
    : hospitalScopeOf(auth);
  if (!hospitalId) throw badRequest('hospitalId wajib diisi untuk admin');

  const body = req.body as z.infer<typeof createDriverSchema>;

  const dupe = await queryOne('SELECT id FROM profiles WHERE phone = $1', [body.phone]);
  if (dupe) throw badRequest('Nomor HP sudah terdaftar');

  const passwordHash = await bcrypt.hash(body.password, 10);

  const driverId = await withTransaction(async (client) => {
    const p = await client.query<{ id: string }>(
      `INSERT INTO profiles (role, full_name, phone, password_hash, hospital_id)
       VALUES ('driver', $1, $2, $3, $4)
       RETURNING id`,
      [body.fullName, body.phone, passwordHash, hospitalId],
    );
    const d = await client.query<{ id: string }>(
      `INSERT INTO drivers (profile_id, hospital_id, vehicle_plate, availability_status)
       VALUES ($1, $2, $3, 'offline')
       RETURNING id`,
      [p.rows[0]!.id, hospitalId, body.vehiclePlate ?? null],
    );
    return d.rows[0]!.id;
  });

  const row = await queryOne<DriverRow>(`${DRIVER_SELECT} WHERE d.id = $1`, [driverId]);
  res.status(201).json({ driver: toDriverDTO(row!) });
});

export const updateDriverSchema = z.object({
  fullName: z.string().trim().min(2).optional(),
  vehiclePlate: z.string().trim().max(20).nullable().optional(),
  availabilityStatus: z.enum(['available', 'busy', 'offline']).optional(),
  isActive: z.boolean().optional(),
  password: z.string().min(6).optional(),
});

/** Guard kepemilikan: satu-satunya jalan menyentuh baris driver milik orang lain. */
async function loadOwnedDriver(req: Request, driverId: string): Promise<DriverRow> {
  const row = await queryOne<DriverRow>(`${DRIVER_SELECT} WHERE d.id = $1`, [driverId]);
  if (!row) throw notFound('Sopir tidak ditemukan');

  const auth = req.auth!;
  if (!isPlatformAdmin(auth) && row.hospital_id !== auth.hospitalId) {
    throw forbidden('Sopir ini terdaftar di rumah sakit lain');
  }
  return row;
}

export const updateDriver = asyncHandler(async (req: Request, res: Response) => {
  const driver = await loadOwnedDriver(req, pathParam(req, 'id'));
  const body = req.body as z.infer<typeof updateDriverSchema>;

  await withTransaction(async (client) => {
    if (body.fullName !== undefined || body.isActive !== undefined || body.password) {
      const passwordHash = body.password ? await bcrypt.hash(body.password, 10) : null;
      await client.query(
        `UPDATE profiles SET
           full_name     = COALESCE($2, full_name),
           is_active     = COALESCE($3, is_active),
           password_hash = COALESCE($4, password_hash)
         WHERE id = $1`,
        [driver.profile_id, body.fullName ?? null, body.isActive ?? null, passwordHash],
      );
    }
    await client.query(
      `UPDATE drivers SET
         vehicle_plate       = COALESCE($2, vehicle_plate),
         availability_status = COALESCE($3, availability_status)
       WHERE id = $1`,
      [driver.id, body.vehiclePlate ?? null, body.availabilityStatus ?? null],
    );
  });

  const row = await queryOne<DriverRow>(`${DRIVER_SELECT} WHERE d.id = $1`, [driver.id]);
  res.json({ driver: toDriverDTO(row!) });
});

export const deleteDriver = asyncHandler(async (req: Request, res: Response) => {
  const driver = await loadOwnedDriver(req, pathParam(req, 'id'));

  const busy = await queryOne(
    `SELECT id FROM emergency_calls
     WHERE driver_id = $1 AND status IN ('confirmed','en_route','arrived')`,
    [driver.id],
  );
  if (busy) throw badRequest('Sopir sedang menangani panggilan aktif');

  // Menghapus profil ikut menghapus baris driver (ON DELETE CASCADE).
  await query('DELETE FROM profiles WHERE id = $1', [driver.profile_id]);
  res.status(204).send();
});

// --------------------------------------------------------------------------
// Endpoint milik sopir sendiri
// --------------------------------------------------------------------------

export const availabilitySchema = z.object({
  availabilityStatus: z.enum(['available', 'offline']),
});

/**
 * Toggle Tersedia/Tidak Tersedia — elemen utama di Beranda App Sopir.
 *
 * `busy` sengaja tidak boleh diset manual: status itu milik sistem, dipasang
 * saat sopir ditugaskan dan dilepas saat tugasnya selesai.
 */
export const setAvailability = asyncHandler(async (req: Request, res: Response) => {
  const driverId = req.auth!.driverId;
  if (!driverId) throw forbidden('Akun ini bukan sopir');

  const { availabilityStatus } = req.body as z.infer<typeof availabilitySchema>;

  const active = await queryOne(
    `SELECT id FROM emergency_calls
     WHERE driver_id = $1 AND status IN ('confirmed','en_route','arrived')`,
    [driverId],
  );
  if (active) throw badRequest('Tidak bisa mengubah status saat menangani tugas aktif');

  await query('UPDATE drivers SET availability_status = $2 WHERE id = $1', [
    driverId,
    availabilityStatus,
  ]);

  const row = await queryOne<DriverRow>(`${DRIVER_SELECT} WHERE d.id = $1`, [driverId]);
  res.json({ driver: toDriverDTO(row!) });
});

export const locationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

/**
 * Jalur REST untuk mengirim posisi. Jalur utamanya adalah socket
 * (`driver:location:push`); endpoint ini disediakan sebagai cadangan kalau
 * koneksi socket sedang putus, supaya posisi sopir tidak pernah benar-benar
 * hilang dari database.
 */
export const pushLocation = asyncHandler(async (req: Request, res: Response) => {
  const driverId = req.auth!.driverId;
  if (!driverId) throw forbidden('Akun ini bukan sopir');

  const { lat, lng } = req.body as z.infer<typeof locationSchema>;
  await query(
    `UPDATE drivers
     SET current_location = ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
         location_updated_at = now()
     WHERE id = $1`,
    [driverId, lng, lat],
  );
  res.status(204).send();
});

export const myDriverProfile = asyncHandler(async (req: Request, res: Response) => {
  const driverId = req.auth!.driverId;
  if (!driverId) throw forbidden('Akun ini bukan sopir');
  const row = await queryOne<DriverRow>(`${DRIVER_SELECT} WHERE d.id = $1`, [driverId]);
  if (!row) throw notFound('Data sopir tidak ditemukan');
  res.json({ driver: toDriverDTO(row) });
});
