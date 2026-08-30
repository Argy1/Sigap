import type { NextFunction, Request, Response } from 'express';
import { verifyAccessToken, verifyCallToken } from '../services/token.service.js';
import { unauthorized } from '../utils/errors.js';

function extractBearer(req: Request): string | null {
  const header = req.header('authorization');
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) return null;
  return token;
}

/** Wajib login. Menolak request tanpa access token yang sah. */
export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  const token = extractBearer(req);
  if (!token) return next(unauthorized('Header Authorization Bearer tidak ada'));

  const payload = verifyAccessToken(token);
  req.auth = {
    profileId: payload.sub,
    role: payload.role,
    hospitalId: payload.hospitalId ?? null,
    driverId: payload.driverId ?? null,
  };
  next();
}

/**
 * Login opsional — dipakai endpoint POST /api/emergency-calls.
 *
 * Ini yang membuat MODE TAMU mungkin: kalau ada token yang sah, panggilan
 * ditautkan ke profil pasien; kalau tidak ada, panggilan tetap dibuat sebagai
 * SOS tamu. Token yang RUSAK tetap ditolak — diam-diam mengabaikannya akan
 * menyembunyikan bug sesi yang kedaluwarsa.
 */
export function optionalAuthenticate(
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  const token = extractBearer(req);
  if (!token) return next();

  const payload = verifyAccessToken(token);
  req.auth = {
    profileId: payload.sub,
    role: payload.role,
    hospitalId: payload.hospitalId ?? null,
    driverId: payload.driverId ?? null,
  };
  next();
}

/**
 * Menerima access token ATAU call token (mode tamu).
 *
 * Dipakai endpoint yang boleh diakses pemilik panggilan tamu, mis.
 * GET /api/emergency-calls/:id. Otorisasi sebenarnya (apakah call token ini
 * cocok dengan :id yang diminta) dilakukan di controller.
 */
export function authenticateAny(
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  const token = extractBearer(req);
  const callToken = req.header('x-call-token');

  if (token) {
    const payload = verifyAccessToken(token);
    req.auth = {
      profileId: payload.sub,
      role: payload.role,
      hospitalId: payload.hospitalId ?? null,
      driverId: payload.driverId ?? null,
    };
    return next();
  }

  if (callToken) {
    const payload = verifyCallToken(callToken);
    req.callAccess = { callId: payload.callId };
    return next();
  }

  next(unauthorized('Perlu access token atau call token'));
}
