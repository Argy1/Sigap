import bcrypt from 'bcryptjs';
import type { Request, Response } from 'express';
import { z } from 'zod';
import { query, queryOne, withTransaction } from '../db/pool.js';
import { assertSameHospital } from '../middleware/rbac.js';
import { validatedQuery } from '../middleware/validate.js';
import { findNearestHospitals } from '../services/geo.service.js';
import { emitHospitalRegistered } from '../sockets/emit.js';
import { asyncHandler, badRequest, notFound } from '../utils/errors.js';
import { pathParam } from '../utils/http.js';

export const nearestQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  limit: z.coerce.number().int().min(1).max(20).optional(),
});

/**
 * Pencarian RS terdekat — PUBLIK.
 *
 * Sengaja tidak butuh autentikasi: layar Peta di App Pasien memakainya, dan
 * pengguna mode tamu harus bisa melihat RS terdekat sebelum menekan SOS.
 */
export const nearest = asyncHandler(async (req: Request, res: Response) => {
  const { lat, lng, limit } = validatedQuery<z.infer<typeof nearestQuerySchema>>(req);
  const hospitals = await findNearestHospitals({ lat, lng }, limit);
  res.json({ hospitals });
});

// --------------------------------------------------------------------------
// Registrasi mandiri RS (non-blocking)
// --------------------------------------------------------------------------

export const registerHospitalSchema = z.object({
  name: z.string().trim().min(3, 'Nama RS minimal 3 karakter'),
  address: z.string().trim().min(5, 'Alamat minimal 5 karakter'),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  phone: z.string().trim().max(30).optional(),
  staff: z.object({
    fullName: z.string().trim().min(2),
    email: z.email('Format email tidak valid'),
    password: z.string().min(6, 'Kata sandi minimal 6 karakter'),
  }),
});

/**
 * RS mendaftarkan diri sendiri. Satu transaksi membuat dua hal sekaligus:
 * baris `hospitals` (status 'unverified') dan akun `hospital_staff` pertamanya.
 *
 * NON-BLOCKING: staff langsung bisa masuk dan mengelola sopir sambil menunggu
 * verifikasi admin. Yang ditahan hanya satu hal — RS belum terverifikasi tidak
 * ikut dalam pencarian RS terdekat, jadi tidak akan menerima SOS sungguhan.
 */
export const registerHospital = asyncHandler(async (req: Request, res: Response) => {
  const body = req.body as z.infer<typeof registerHospitalSchema>;

  const dupe = await queryOne('SELECT id FROM profiles WHERE lower(email) = lower($1)', [
    body.staff.email,
  ]);
  if (dupe) throw badRequest('Email tersebut sudah terdaftar');

  const passwordHash = await bcrypt.hash(body.staff.password, 10);

  const result = await withTransaction(async (client) => {
    const h = await client.query<{ id: string }>(
      `INSERT INTO hospitals (name, address, location, phone, verification_status)
       VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5, 'unverified')
       RETURNING id`,
      [body.name, body.address, body.lng, body.lat, body.phone ?? null],
    );
    const hospitalId = h.rows[0]!.id;

    const p = await client.query<{ id: string }>(
      `INSERT INTO profiles (role, full_name, email, password_hash, hospital_id)
       VALUES ('hospital_staff', $1, $2, $3, $4)
       RETURNING id`,
      [body.staff.fullName, body.staff.email, passwordHash, hospitalId],
    );

    await client.query('UPDATE hospitals SET created_by = $1 WHERE id = $2', [
      p.rows[0]!.id,
      hospitalId,
    ]);

    return { hospitalId, profileId: p.rows[0]!.id };
  });

  const hospital = await getHospitalRow(result.hospitalId);
  emitHospitalRegistered(hospital);

  res.status(201).json({
    hospital,
    message:
      'Rumah sakit terdaftar. Anda sudah bisa masuk; verifikasi admin sedang diproses.',
  });
});

// --------------------------------------------------------------------------
// Baca / ubah satu RS
// --------------------------------------------------------------------------

interface HospitalRow {
  id: string;
  name: string;
  address: string;
  phone: string | null;
  lat: string | number;
  lng: string | number;
  verification_status: string;
  verified_at: Date | null;
  created_at: Date;
}

const HOSPITAL_SELECT = `
  SELECT id, name, address, phone,
         ST_Y(location::geometry) AS lat,
         ST_X(location::geometry) AS lng,
         verification_status, verified_at, created_at
  FROM hospitals
`;

const toHospitalDTO = (r: HospitalRow) => ({
  id: r.id,
  name: r.name,
  address: r.address,
  phone: r.phone,
  lat: Number(r.lat),
  lng: Number(r.lng),
  verificationStatus: r.verification_status,
  verifiedAt: r.verified_at ? r.verified_at.toISOString() : null,
  createdAt: r.created_at.toISOString(),
});

export async function getHospitalRow(id: string) {
  const row = await queryOne<HospitalRow>(`${HOSPITAL_SELECT} WHERE id = $1`, [id]);
  return row ? toHospitalDTO(row) : null;
}

export const getHospital = asyncHandler(async (req: Request, res: Response) => {
  const id = pathParam(req, 'id');
  // Staff RS hanya boleh membaca RS-nya sendiri; admin boleh semua.
  assertSameHospital(req.auth!, id);

  const hospital = await getHospitalRow(id);
  if (!hospital) throw notFound('Rumah sakit tidak ditemukan');
  res.json({ hospital });
});

export const updateHospitalSchema = z.object({
  name: z.string().trim().min(3).optional(),
  address: z.string().trim().min(5).optional(),
  phone: z.string().trim().max(30).nullable().optional(),
  lat: z.number().min(-90).max(90).optional(),
  lng: z.number().min(-180).max(180).optional(),
});

export const updateHospital = asyncHandler(async (req: Request, res: Response) => {
  const id = pathParam(req, 'id');
  assertSameHospital(req.auth!, id);

  const body = req.body as z.infer<typeof updateHospitalSchema>;
  const hasPoint = body.lat !== undefined && body.lng !== undefined;

  await query(
    `UPDATE hospitals SET
       name     = COALESCE($2, name),
       address  = COALESCE($3, address),
       phone    = COALESCE($4, phone),
       location = CASE WHEN $5::boolean
                       THEN ST_SetSRID(ST_MakePoint($6, $7), 4326)::geography
                       ELSE location END
     WHERE id = $1`,
    [
      id,
      body.name ?? null,
      body.address ?? null,
      body.phone ?? null,
      hasPoint,
      body.lng ?? null,
      body.lat ?? null,
    ],
  );

  res.json({ hospital: await getHospitalRow(id) });
});

// --------------------------------------------------------------------------
// Admin: daftar & verifikasi RS
// --------------------------------------------------------------------------

export const listHospitalsQuerySchema = z.object({
  status: z.enum(['unverified', 'verified', 'rejected']).optional(),
});

export const listHospitals = asyncHandler(async (req: Request, res: Response) => {
  const { status } = validatedQuery<z.infer<typeof listHospitalsQuerySchema>>(req);
  const res_ = await query<HospitalRow & { driver_count: string }>(
    `SELECT h.id, h.name, h.address, h.phone,
            ST_Y(h.location::geometry) AS lat,
            ST_X(h.location::geometry) AS lng,
            h.verification_status, h.verified_at, h.created_at,
            (SELECT count(*) FROM drivers d WHERE d.hospital_id = h.id) AS driver_count
     FROM hospitals h
     ${status ? 'WHERE h.verification_status = $1' : ''}
     ORDER BY
       -- Yang menunggu verifikasi selalu di atas: itu yang butuh tindakan admin.
       CASE h.verification_status WHEN 'unverified' THEN 0 ELSE 1 END,
       h.created_at DESC`,
    status ? [status] : [],
  );

  res.json({
    hospitals: res_.rows.map((r) => ({
      ...toHospitalDTO(r),
      driverCount: Number(r.driver_count),
    })),
  });
});

export const verifySchema = z.object({
  status: z.enum(['verified', 'rejected']),
});

export const verifyHospital = asyncHandler(async (req: Request, res: Response) => {
  const id = pathParam(req, 'id');
  const { status } = req.body as z.infer<typeof verifySchema>;

  const updated = await queryOne<{ id: string }>(
    `UPDATE hospitals
     SET verification_status = $2,
         verified_at = CASE WHEN $2 = 'verified' THEN now() ELSE NULL END
     WHERE id = $1
     RETURNING id`,
    [id, status],
  );
  if (!updated) throw notFound('Rumah sakit tidak ditemukan');

  res.json({ hospital: await getHospitalRow(id) });
});
