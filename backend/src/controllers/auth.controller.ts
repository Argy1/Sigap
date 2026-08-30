import bcrypt from 'bcryptjs';
import type { Request, Response } from 'express';
import { z } from 'zod';
import { query, queryOne, withTransaction } from '../db/pool.js';
import {
  issueRefreshToken,
  revokeAllForProfile,
  revokeRefreshToken,
  rotateRefreshToken,
  signAccessToken,
} from '../services/token.service.js';
import type { Role } from '../types/index.js';
import { asyncHandler, badRequest, notFound, unauthorized } from '../utils/errors.js';

const BCRYPT_ROUNDS = 10;

const phoneSchema = z
  .string()
  .trim()
  .regex(/^[0-9+][0-9\s-]{7,19}$/, 'Format nomor HP tidak valid');

export const registerSchema = z.object({
  fullName: z.string().trim().min(2, 'Nama minimal 2 karakter'),
  phone: phoneSchema,
  password: z.string().min(6, 'Kata sandi minimal 6 karakter'),
});

export const loginSchema = z.object({
  /** Bisa nomor HP (pasien & sopir) atau email (staff RS & admin). */
  identifier: z.string().trim().min(3, 'Isi nomor HP atau email'),
  password: z.string().min(1, 'Kata sandi wajib diisi'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(10, 'refreshToken wajib diisi'),
});

interface ProfileRow {
  id: string;
  role: Role;
  full_name: string;
  phone: string | null;
  email: string | null;
  password_hash: string;
  is_active: boolean;
  hospital_id: string | null;
}

/** Bentuk profil yang aman dikirim ke client (tanpa password_hash). */
async function publicProfile(profileId: string) {
  const row = await queryOne<{
    id: string;
    role: Role;
    full_name: string;
    phone: string | null;
    email: string | null;
    hospital_id: string | null;
    hospital_name: string | null;
    driver_id: string | null;
    vehicle_plate: string | null;
    availability_status: string | null;
  }>(
    `SELECT p.id, p.role, p.full_name, p.phone, p.email, p.hospital_id,
            h.name AS hospital_name,
            d.id AS driver_id, d.vehicle_plate, d.availability_status
     FROM profiles p
     LEFT JOIN hospitals h ON h.id = p.hospital_id
     LEFT JOIN drivers   d ON d.profile_id = p.id
     WHERE p.id = $1`,
    [profileId],
  );
  if (!row) throw notFound('Profil tidak ditemukan');

  return {
    id: row.id,
    role: row.role,
    fullName: row.full_name,
    phone: row.phone,
    email: row.email,
    hospitalId: row.hospital_id,
    hospitalName: row.hospital_name,
    driverId: row.driver_id,
    vehiclePlate: row.vehicle_plate,
    availabilityStatus: row.availability_status,
  };
}

/** Token bundle yang dikembalikan setelah login/register/refresh. */
async function issueSession(profile: ProfileRow, userAgent?: string) {
  // driverId ikut disematkan di token supaya socket & endpoint sopir tidak
  // perlu query tambahan di setiap request.
  const driver =
    profile.role === 'driver'
      ? await queryOne<{ id: string }>('SELECT id FROM drivers WHERE profile_id = $1', [
          profile.id,
        ])
      : null;

  const accessToken = signAccessToken({
    sub: profile.id,
    role: profile.role,
    hospitalId: profile.hospital_id,
    driverId: driver?.id ?? null,
  });
  const refreshToken = await issueRefreshToken(profile.id, userAgent);

  return { accessToken, refreshToken, user: await publicProfile(profile.id) };
}

/**
 * Registrasi mandiri — HANYA untuk role `patient`.
 *
 * Sopir dibuatkan akun oleh staff RS-nya (lihat drivers.controller), staff RS
 * lahir saat RS mendaftar (hospitals.controller), dan admin di-seed. Kalau
 * endpoint ini menerima parameter `role`, siapa pun bisa mendaftar jadi admin.
 */
export const register = asyncHandler(async (req: Request, res: Response) => {
  const { fullName, phone, password } = req.body as z.infer<typeof registerSchema>;

  const existing = await queryOne('SELECT id FROM profiles WHERE phone = $1', [phone]);
  if (existing) throw badRequest('Nomor HP sudah terdaftar. Silakan masuk.');

  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  const profile = await withTransaction(async (client) => {
    const inserted = await client.query<ProfileRow>(
      `INSERT INTO profiles (role, full_name, phone, password_hash)
       VALUES ('patient', $1, $2, $3)
       RETURNING id, role, full_name, phone, email, password_hash, is_active, hospital_id`,
      [fullName, phone, passwordHash],
    );
    const row = inserted.rows[0]!;
    // Baris medis dibuat kosong sejak awal supaya layar Profil Medis tidak
    // perlu menangani kasus "belum ada baris".
    await client.query('INSERT INTO patient_profiles (profile_id) VALUES ($1)', [row.id]);
    return row;
  });

  res.status(201).json(await issueSession(profile, req.header('user-agent')));
});

export const login = asyncHandler(async (req: Request, res: Response) => {
  const { identifier, password } = req.body as z.infer<typeof loginSchema>;

  const profile = await queryOne<ProfileRow>(
    `SELECT id, role, full_name, phone, email, password_hash, is_active, hospital_id
     FROM profiles
     WHERE phone = $1 OR lower(email) = lower($1)`,
    [identifier],
  );

  // Pesan sengaja disamakan untuk identifier tidak dikenal dan kata sandi salah,
  // supaya endpoint ini tidak bisa dipakai menebak nomor mana yang terdaftar.
  if (!profile) throw unauthorized('Nomor HP/email atau kata sandi salah');

  const ok = await bcrypt.compare(password, profile.password_hash);
  if (!ok) throw unauthorized('Nomor HP/email atau kata sandi salah');

  if (!profile.is_active) throw unauthorized('Akun Anda dinonaktifkan');

  res.json(await issueSession(profile, req.header('user-agent')));
});

export const refresh = asyncHandler(async (req: Request, res: Response) => {
  const { refreshToken } = req.body as z.infer<typeof refreshSchema>;
  const rotated = await rotateRefreshToken(refreshToken, req.header('user-agent'));

  const profile = await queryOne<ProfileRow>(
    `SELECT id, role, full_name, phone, email, password_hash, is_active, hospital_id
     FROM profiles WHERE id = $1`,
    [rotated.profileId],
  );
  if (!profile || !profile.is_active) throw unauthorized('Akun tidak aktif');

  const driver =
    profile.role === 'driver'
      ? await queryOne<{ id: string }>('SELECT id FROM drivers WHERE profile_id = $1', [
          profile.id,
        ])
      : null;

  res.json({
    accessToken: signAccessToken({
      sub: profile.id,
      role: profile.role,
      hospitalId: profile.hospital_id,
      driverId: driver?.id ?? null,
    }),
    refreshToken: rotated.refreshToken,
    user: await publicProfile(profile.id),
  });
});

export const logout = asyncHandler(async (req: Request, res: Response) => {
  const { refreshToken } = req.body as { refreshToken?: string };
  if (refreshToken) await revokeRefreshToken(refreshToken);
  else if (req.auth) await revokeAllForProfile(req.auth.profileId);
  res.status(204).send();
});

export const me = asyncHandler(async (req: Request, res: Response) => {
  res.json({ user: await publicProfile(req.auth!.profileId) });
});

// --------------------------------------------------------------------------
// Profil medis pasien
// --------------------------------------------------------------------------

export const medicalSchema = z.object({
  bloodType: z
    .enum(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'])
    .nullable()
    .optional(),
  allergies: z.array(z.string().trim().min(1)).max(20).optional(),
  medicalHistory: z.string().trim().max(2000).nullable().optional(),
  emergencyContactName: z.string().trim().max(120).nullable().optional(),
  emergencyContactPhone: z.string().trim().max(30).nullable().optional(),
});

export const getMedical = asyncHandler(async (req: Request, res: Response) => {
  const row = await queryOne<{
    blood_type: string | null;
    allergies: string[];
    medical_history: string | null;
    emergency_contact_name: string | null;
    emergency_contact_phone: string | null;
  }>(
    `SELECT blood_type, allergies, medical_history,
            emergency_contact_name, emergency_contact_phone
     FROM patient_profiles WHERE profile_id = $1`,
    [req.auth!.profileId],
  );

  res.json({
    medical: {
      bloodType: row?.blood_type ?? null,
      allergies: row?.allergies ?? [],
      medicalHistory: row?.medical_history ?? null,
      emergencyContactName: row?.emergency_contact_name ?? null,
      emergencyContactPhone: row?.emergency_contact_phone ?? null,
    },
  });
});

export const updateMedical = asyncHandler(async (req: Request, res: Response) => {
  const body = req.body as z.infer<typeof medicalSchema>;
  const profileId = req.auth!.profileId;

  await query(
    `INSERT INTO patient_profiles
       (profile_id, blood_type, allergies, medical_history,
        emergency_contact_name, emergency_contact_phone)
     VALUES ($1, $2, COALESCE($3, ARRAY[]::text[]), $4, $5, $6)
     ON CONFLICT (profile_id) DO UPDATE SET
       blood_type              = COALESCE(EXCLUDED.blood_type, patient_profiles.blood_type),
       allergies               = COALESCE($3, patient_profiles.allergies),
       medical_history         = COALESCE(EXCLUDED.medical_history, patient_profiles.medical_history),
       emergency_contact_name  = COALESCE(EXCLUDED.emergency_contact_name, patient_profiles.emergency_contact_name),
       emergency_contact_phone = COALESCE(EXCLUDED.emergency_contact_phone, patient_profiles.emergency_contact_phone)`,
    [
      profileId,
      body.bloodType ?? null,
      body.allergies ?? null,
      body.medicalHistory ?? null,
      body.emergencyContactName ?? null,
      body.emergencyContactPhone ?? null,
    ],
  );

  await getMedical(req, res, () => {});
});
