import type { Request } from 'express';
import { badRequest } from './errors.js';

/**
 * Ambil path parameter sebagai string tunggal.
 *
 * Tipe Express 5 memodelkan req.params sebagai `string | string[]` (karena
 * pola wildcard bisa menghasilkan array). Semua route di proyek ini memakai
 * parameter tunggal, jadi helper ini menormalkannya di satu tempat daripada
 * menyebar cast di setiap controller.
 */
export function pathParam(req: Request, name: string): string {
  const raw = (req.params as Record<string, string | string[] | undefined>)[name];
  const value = Array.isArray(raw) ? raw[0] : raw;
  if (!value) throw badRequest(`Parameter "${name}" tidak ada di URL`);
  return value;
}
