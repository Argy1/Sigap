/**
 * Error aplikasi dengan status HTTP. Dilempar dari mana saja, ditangkap satu
 * kali di middleware/error.ts — tidak perlu try/catch berulang di controller.
 */
export class AppError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly code?: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const badRequest = (msg: string, details?: unknown) =>
  new AppError(400, msg, 'BAD_REQUEST', details);

export const unauthorized = (msg = 'Autentikasi diperlukan') =>
  new AppError(401, msg, 'UNAUTHORIZED');

export const forbidden = (msg = 'Anda tidak punya akses ke sumber daya ini') =>
  new AppError(403, msg, 'FORBIDDEN');

export const notFound = (msg = 'Data tidak ditemukan') =>
  new AppError(404, msg, 'NOT_FOUND');

export const conflict = (msg: string) => new AppError(409, msg, 'CONFLICT');

/**
 * Bungkus handler async supaya error-nya diteruskan ke next() secara otomatis.
 * Express 5 sudah menangani promise rejection, tapi wrapper ini menjaga tipe
 * tetap jelas dan kompatibel.
 */
import type { NextFunction, Request, RequestHandler, Response } from 'express';

export const asyncHandler =
  (fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>): RequestHandler =>
  (req, res, next) => {
    void fn(req, res, next).catch(next);
  };
