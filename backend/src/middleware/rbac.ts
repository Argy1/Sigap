import type { NextFunction, Request, Response } from 'express';
import type { AuthContext, Role } from '../types/index.js';
import { forbidden, unauthorized } from '../utils/errors.js';

/**
 * SATU-SATUNYA tempat aturan akses per role didefinisikan.
 *
 * Prinsip penting yang dipegang di seluruh proyek:
 * middleware ini adalah lapisan PERTAMA, bukan satu-satunya. Setiap query yang
 * menyentuh data milik RS WAJIB tetap membawa `WHERE hospital_id = $x` di level
 * SQL. Middleware menjawab "role ini boleh memanggil endpoint ini?"; SQL
 * menjawab "baris ini milik siapa?". Mengandalkan salah satu saja bocor.
 */

export function requireRole(...roles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.auth) return next(unauthorized());
    if (!roles.includes(req.auth.role)) {
      return next(
        forbidden(`Endpoint ini hanya untuk role: ${roles.join(', ')}`),
      );
    }
    next();
  };
}

/**
 * Memastikan pengguna benar-benar terikat ke sebuah RS, lalu mengembalikan
 * hospital_id-nya untuk dipakai di klausa WHERE.
 *
 * Admin adalah pengecualian: dia tidak terikat RS mana pun dan boleh lintas RS.
 */
export function hospitalScopeOf(auth: AuthContext): string {
  if (auth.role === 'admin') {
    throw forbidden('Admin harus menyebut hospital_id secara eksplisit');
  }
  if (!auth.hospitalId) {
    throw forbidden('Akun Anda belum tertaut ke rumah sakit mana pun');
  }
  return auth.hospitalId;
}

/** True kalau pengguna boleh melihat data lintas RS. */
export const isPlatformAdmin = (auth: AuthContext): boolean => auth.role === 'admin';

/**
 * Guard untuk sumber daya milik RS. Melempar 403 kalau `resourceHospitalId`
 * bukan RS milik pengguna (kecuali admin).
 */
export function assertSameHospital(
  auth: AuthContext,
  resourceHospitalId: string | null,
): void {
  if (isPlatformAdmin(auth)) return;
  if (!resourceHospitalId || resourceHospitalId !== auth.hospitalId) {
    throw forbidden('Data ini milik rumah sakit lain');
  }
}
