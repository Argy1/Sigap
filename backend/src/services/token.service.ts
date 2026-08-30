import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { query, queryOne } from '../db/pool.js';
import type { AccessTokenPayload, CallTokenPayload } from '../types/index.js';
import { unauthorized } from '../utils/errors.js';

/**
 * Tiga jenis token di sistem ini:
 *
 *  1. ACCESS  — JWT pendek (15m), dikirim di header Authorization.
 *  2. REFRESH — string acak (bukan JWT), disimpan HASH-nya di database supaya
 *               bisa dirotasi & dicabut per-perangkat.
 *  3. CALL    — JWT untuk MODE TAMU, cakupannya hanya satu emergency_call.
 */

// --------------------------------------------------------------------------
// Access token
// --------------------------------------------------------------------------

export function signAccessToken(payload: AccessTokenPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_TTL,
  } as jwt.SignOptions);
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  try {
    return jwt.verify(token, env.JWT_ACCESS_SECRET) as AccessTokenPayload;
  } catch {
    throw unauthorized('Access token tidak valid atau sudah kedaluwarsa');
  }
}

// --------------------------------------------------------------------------
// Call token (mode tamu)
// --------------------------------------------------------------------------

export function signCallToken(callId: string): string {
  const payload: CallTokenPayload = { callId, scope: 'call' };
  return jwt.sign(payload, env.JWT_CALL_SECRET, {
    expiresIn: env.JWT_CALL_TTL,
  } as jwt.SignOptions);
}

export function verifyCallToken(token: string): CallTokenPayload {
  try {
    const decoded = jwt.verify(token, env.JWT_CALL_SECRET) as CallTokenPayload;
    if (decoded.scope !== 'call') throw new Error('scope salah');
    return decoded;
  } catch {
    throw unauthorized('Call token tidak valid atau sudah kedaluwarsa');
  }
}

// --------------------------------------------------------------------------
// Refresh token — random string, disimpan sebagai SHA-256 hash
// --------------------------------------------------------------------------

const hashToken = (raw: string) => createHash('sha256').update(raw).digest('hex');

/** Terjemahkan "30d" / "12h" / "15m" jadi milidetik. */
function ttlToMs(ttl: string): number {
  const match = /^(\d+)([smhd])$/.exec(ttl.trim());
  if (!match) throw new Error(`Format TTL tidak valid: ${ttl}`);
  const value = Number(match[1]);
  const unit = match[2] as 's' | 'm' | 'h' | 'd';
  const factor = { s: 1_000, m: 60_000, h: 3_600_000, d: 86_400_000 }[unit];
  return value * factor;
}

export async function issueRefreshToken(
  profileId: string,
  userAgent?: string,
): Promise<string> {
  const raw = randomBytes(48).toString('base64url');
  const expiresAt = new Date(Date.now() + ttlToMs(env.JWT_REFRESH_TTL));

  await query(
    `INSERT INTO refresh_tokens (profile_id, token_hash, user_agent, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [profileId, hashToken(raw), userAgent ?? null, expiresAt],
  );

  return raw;
}

/**
 * Rotasi: token lama langsung dicabut, token baru diterbitkan. Kalau token yang
 * sudah dicabut dipakai lagi, seluruh sesi profil itu ikut dicabut — indikasi
 * token dicuri.
 */
export async function rotateRefreshToken(
  raw: string,
  userAgent?: string,
): Promise<{ profileId: string; refreshToken: string }> {
  const tokenHash = hashToken(raw);

  const row = await queryOne<{
    id: string;
    profile_id: string;
    revoked_at: Date | null;
    expires_at: Date;
  }>(
    `SELECT id, profile_id, revoked_at, expires_at
     FROM refresh_tokens WHERE token_hash = $1`,
    [tokenHash],
  );

  if (!row) throw unauthorized('Refresh token tidak dikenal');

  if (row.revoked_at) {
    // Token bekas dipakai ulang → curigai pencurian, cabut semua sesi.
    await query(
      `UPDATE refresh_tokens SET revoked_at = now()
       WHERE profile_id = $1 AND revoked_at IS NULL`,
      [row.profile_id],
    );
    throw unauthorized('Refresh token sudah dicabut. Silakan masuk lagi.');
  }

  if (row.expires_at.getTime() < Date.now()) {
    throw unauthorized('Refresh token sudah kedaluwarsa');
  }

  await query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [row.id]);
  const next = await issueRefreshToken(row.profile_id, userAgent);

  return { profileId: row.profile_id, refreshToken: next };
}

export async function revokeRefreshToken(raw: string): Promise<void> {
  await query(
    `UPDATE refresh_tokens SET revoked_at = now()
     WHERE token_hash = $1 AND revoked_at IS NULL`,
    [hashToken(raw)],
  );
}

export async function revokeAllForProfile(profileId: string): Promise<void> {
  await query(
    `UPDATE refresh_tokens SET revoked_at = now()
     WHERE profile_id = $1 AND revoked_at IS NULL`,
    [profileId],
  );
}
