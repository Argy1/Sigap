import type { Request, Response } from 'express';
import { z } from 'zod';
import { queryOne } from '../db/pool.js';
import { isPlatformAdmin } from '../middleware/rbac.js';
import { findNearestDrivers } from '../services/geo.service.js';
import {
  assignDriver,
  createEmergencyCall,
  getCallById,
  listCalls,
  rejectAssignment,
  updateCallStatus,
  type EmergencyCallDTO,
} from '../services/dispatch.service.js';
import { signCallToken } from '../services/token.service.js';
import {
  emitAssignmentCancelled,
  emitAssignmentNew,
  emitSosNew,
  emitSosUpdated,
} from '../sockets/emit.js';
import type { AuthContext, CallStatus } from '../types/index.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../utils/errors.js';
import { pathParam } from '../utils/http.js';

// --------------------------------------------------------------------------
// Langkah 1–3: buat SOS
// --------------------------------------------------------------------------

export const createCallSchema = z
  .object({
    lat: z.number().min(-90).max(90),
    lng: z.number().min(-180).max(180),
    conditionNote: z.string().trim().max(500).optional(),
    /** Wajib kalau tidak login (mode tamu). */
    guestName: z.string().trim().min(2).max(120).optional(),
    guestPhone: z
      .string()
      .trim()
      .regex(/^[0-9+][0-9\s-]{7,19}$/, 'Format nomor HP tidak valid')
      .optional(),
  })
  .strict();

/**
 * Membuat panggilan darurat. Endpoint PALING KRITIS di sistem.
 *
 * Autentikasi bersifat OPSIONAL — inilah yang mewujudkan mode tamu. Kalau ada
 * access token, panggilan ditautkan ke profil pasien dan data medisnya ikut
 * di-snapshot. Kalau tidak, penelepon wajib menyertakan nama + nomor HP supaya
 * RS punya cara menghubungi balik, dan mendapat `callToken` untuk memantau.
 */
export const createCall = asyncHandler(async (req: Request, res: Response) => {
  const body = req.body as z.infer<typeof createCallSchema>;
  const auth = req.auth;

  // Hanya pasien (atau tamu) yang boleh menekan SOS. Staff/sopir/admin yang
  // menekan SOS lewat akunnya hampir pasti salah pakai.
  if (auth && auth.role !== 'patient') {
    throw forbidden('Hanya akun pasien yang bisa mengirim SOS');
  }

  if (!auth && !body.guestPhone) {
    throw badRequest('Mode tamu wajib menyertakan guestPhone agar bisa dihubungi balik');
  }

  const { call, candidates } = await createEmergencyCall({
    patientId: auth?.profileId ?? null,
    location: { lat: body.lat, lng: body.lng },
    conditionNote: body.conditionNote ?? null,
    guestName: body.guestName ?? null,
    guestPhone: body.guestPhone ?? null,
  });

  // Langkah 3: RS terpilih langsung diberi tahu secara realtime.
  if (call.hospitalId) emitSosNew(call.hospitalId, call);

  res.status(201).json({
    call,
    /** Kandidat RS lain — dipakai kalau nanti perlu fallback manual. */
    hospitalCandidates: candidates,
    /** Hanya untuk tamu: bekal memantau panggilan ini tanpa punya akun. */
    callToken: auth ? undefined : signCallToken(call.id),
    routingMode: candidates[0]?.source ?? 'estimate',
  });
});

// --------------------------------------------------------------------------
// Otorisasi baca satu panggilan
// --------------------------------------------------------------------------

/**
 * Siapa boleh melihat satu panggilan.
 *
 * Ditulis sebagai fungsi eksplisit, bukan tersebar sebagai if di controller,
 * supaya aturannya bisa dibaca sekaligus dan diuji di audit RBAC.
 */
function canReadCall(
  call: EmergencyCallDTO,
  auth: AuthContext | undefined,
  callAccess: { callId: string } | undefined,
): boolean {
  // Tamu pemegang call token: hanya panggilan yang tercantum di token itu.
  if (callAccess) return callAccess.callId === call.id;
  if (!auth) return false;

  switch (auth.role) {
    case 'admin':
      return true;
    case 'patient':
      return call.patientId === auth.profileId;
    case 'hospital_staff':
      return call.hospitalId !== null && call.hospitalId === auth.hospitalId;
    case 'driver':
      return call.driverId !== null && call.driverId === auth.driverId;
    default:
      return false;
  }
}

export const getCall = asyncHandler(async (req: Request, res: Response) => {
  const call = await getCallById(pathParam(req, 'id'));
  if (!call) throw notFound('Panggilan darurat tidak ditemukan');

  if (!canReadCall(call, req.auth, req.callAccess)) {
    throw forbidden('Anda tidak punya akses ke panggilan ini');
  }
  res.json({ call });
});

// --------------------------------------------------------------------------
// Daftar panggilan — selalu dipersempit oleh SQL, bukan oleh middleware saja
// --------------------------------------------------------------------------

export const listCallsQuerySchema = z.object({
  status: z
    .enum(['pending', 'confirmed', 'en_route', 'arrived', 'completed', 'cancelled'])
    .optional(),
  active: z.coerce.boolean().optional(),
});

export const listMyCalls = asyncHandler(async (req: Request, res: Response) => {
  const auth = req.auth!;
  const status = req.query.status as CallStatus | undefined;
  const activeOnly = req.query.active === 'true';

  const ACTIVE = `ec.status IN ('pending','confirmed','en_route','arrived')`;

  switch (auth.role) {
    case 'patient': {
      const where = ['ec.patient_id = $1'];
      if (status) where.push(`ec.status = '${sanitizeStatus(status)}'`);
      else if (activeOnly) where.push(ACTIVE);
      res.json({ calls: await listCalls(where.join(' AND '), [auth.profileId]) });
      return;
    }
    case 'hospital_staff': {
      if (!auth.hospitalId) throw forbidden('Akun Anda belum tertaut ke rumah sakit');
      const where = ['ec.hospital_id = $1'];
      if (status) where.push(`ec.status = '${sanitizeStatus(status)}'`);
      else if (activeOnly) where.push(ACTIVE);
      res.json({ calls: await listCalls(where.join(' AND '), [auth.hospitalId]) });
      return;
    }
    case 'driver': {
      if (!auth.driverId) throw forbidden('Akun ini bukan sopir');
      const where = ['ec.driver_id = $1'];
      if (status) where.push(`ec.status = '${sanitizeStatus(status)}'`);
      else if (activeOnly) where.push(ACTIVE);
      res.json({ calls: await listCalls(where.join(' AND '), [auth.driverId]) });
      return;
    }
    case 'admin': {
      const where = status ? `ec.status = '${sanitizeStatus(status)}'` : 'true';
      res.json({ calls: await listCalls(where, []) });
      return;
    }
  }
});

/**
 * Status hanya boleh berasal dari daftar tertutup. Nilainya sudah divalidasi
 * Zod di route, tapi karena string ini masuk ke SQL secara literal, dicek ulang
 * di sini — pertahanan berlapis untuk satu-satunya tempat interpolasi terjadi.
 */
const VALID_STATUSES: readonly CallStatus[] = [
  'pending',
  'confirmed',
  'en_route',
  'arrived',
  'completed',
  'cancelled',
];
function sanitizeStatus(status: string): CallStatus {
  if (!VALID_STATUSES.includes(status as CallStatus)) {
    throw badRequest(`Status tidak dikenal: ${status}`);
  }
  return status as CallStatus;
}

// --------------------------------------------------------------------------
// Langkah 4: saran sopir + penugasan hibrida
// --------------------------------------------------------------------------

/** Guard: panggilan ini benar milik RS pengguna? */
async function loadCallForHospital(req: Request): Promise<EmergencyCallDTO> {
  const call = await getCallById(pathParam(req, 'id'));
  if (!call) throw notFound('Panggilan darurat tidak ditemukan');

  const auth = req.auth!;
  if (isPlatformAdmin(auth)) return call;
  if (!call.hospitalId || call.hospitalId !== auth.hospitalId) {
    throw forbidden('Panggilan ini milik rumah sakit lain');
  }
  return call;
}

/**
 * Backend MENYARANKAN, staff RS MEMUTUSKAN. Bukan otomatis penuh (staff sering
 * tahu konteks yang tidak diketahui sistem), bukan manual penuh (mencari sopir
 * terdekat satu per satu terlalu lambat saat darurat).
 */
export const suggestedDrivers = asyncHandler(async (req: Request, res: Response) => {
  const call = await loadCallForHospital(req);
  if (!call.hospitalId) throw badRequest('Panggilan ini belum punya rumah sakit tujuan');

  const drivers = await findNearestDrivers(call.hospitalId, call.location);
  res.json({ drivers });
});

export const assignSchema = z.object({
  driverId: z.uuid('driverId harus berupa UUID'),
});

export const assign = asyncHandler(async (req: Request, res: Response) => {
  const call = await loadCallForHospital(req);
  const { driverId } = req.body as z.infer<typeof assignSchema>;

  const result = await assignDriver(call.id, driverId);

  // Langkah 5: sopir langsung diberi tahu.
  emitAssignmentNew(driverId, result.call);
  if (result.previousDriverId && result.previousDriverId !== driverId) {
    emitAssignmentCancelled(result.previousDriverId, call.id);
  }
  emitSosUpdated(result.call.hospitalId, call.id, result.call);

  res.json({ call: result.call });
});

// --------------------------------------------------------------------------
// Langkah 7: transisi status
// --------------------------------------------------------------------------

export const statusSchema = z.object({
  status: z.enum(['confirmed', 'en_route', 'arrived', 'completed', 'cancelled']),
  cancelReason: z.string().trim().max(300).optional(),
});

/**
 * Siapa boleh mengubah status ke apa.
 *
 * - Sopir  : menggerakkan panggilannya sendiri maju (en_route -> arrived -> completed)
 * - Staff  : apa saja pada panggilan RS-nya
 * - Pasien : HANYA membatalkan panggilannya sendiri
 */
function assertCanChangeStatus(
  call: EmergencyCallDTO,
  auth: AuthContext,
  next: CallStatus,
): void {
  if (auth.role === 'admin') return;

  if (auth.role === 'hospital_staff') {
    if (!call.hospitalId || call.hospitalId !== auth.hospitalId) {
      throw forbidden('Panggilan ini milik rumah sakit lain');
    }
    return;
  }

  if (auth.role === 'driver') {
    if (!call.driverId || call.driverId !== auth.driverId) {
      throw forbidden('Anda tidak ditugaskan pada panggilan ini');
    }
    if (!['en_route', 'arrived', 'completed'].includes(next)) {
      throw forbidden('Sopir hanya bisa mengubah status ke en_route/arrived/completed');
    }
    return;
  }

  if (auth.role === 'patient') {
    if (call.patientId !== auth.profileId) {
      throw forbidden('Ini bukan panggilan Anda');
    }
    if (next !== 'cancelled') {
      throw forbidden('Pasien hanya bisa membatalkan panggilan');
    }
    return;
  }

  throw forbidden();
}

export const changeStatus = asyncHandler(async (req: Request, res: Response) => {
  const existing = await getCallById(pathParam(req, 'id'));
  if (!existing) throw notFound('Panggilan darurat tidak ditemukan');

  const body = req.body as z.infer<typeof statusSchema>;

  // Tamu boleh membatalkan panggilannya sendiri lewat call token.
  if (req.callAccess) {
    if (req.callAccess.callId !== existing.id) throw forbidden();
    if (body.status !== 'cancelled') {
      throw forbidden('Mode tamu hanya bisa membatalkan panggilan');
    }
  } else {
    assertCanChangeStatus(existing, req.auth!, body.status);
  }

  const call = await updateCallStatus(existing.id, body.status, {
    cancelReason: body.cancelReason ?? null,
  });

  emitSosUpdated(call.hospitalId, call.id, call);
  if (body.status === 'cancelled' && existing.driverId) {
    emitAssignmentCancelled(existing.driverId, call.id);
  }

  res.json({ call });
});

/** Sopir menolak tugas — panggilan kembali ke antrean RS, bukan dibatalkan. */
export const reject = asyncHandler(async (req: Request, res: Response) => {
  const auth = req.auth!;
  if (!auth.driverId) throw forbidden('Akun ini bukan sopir');

  const existing = await queryOne<{ id: string; driver_id: string | null }>(
    'SELECT id, driver_id FROM emergency_calls WHERE id = $1',
    [pathParam(req, 'id')],
  );
  if (!existing) throw notFound('Panggilan darurat tidak ditemukan');
  if (existing.driver_id !== auth.driverId) {
    throw forbidden('Anda tidak ditugaskan pada panggilan ini');
  }

  const call = await rejectAssignment(existing.id, auth.driverId);
  emitSosUpdated(call.hospitalId, call.id, call);
  res.json({ call });
});
