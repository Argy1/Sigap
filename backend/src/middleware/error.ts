import type { NextFunction, Request, Response } from 'express';
import { env } from '../config/env.js';
import { AppError } from '../utils/errors.js';

/** Handler 404 untuk route yang tidak terdaftar. */
export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: `Route ${req.method} ${req.path} tidak ada` },
  });
}

/**
 * Error handler terpusat. Satu-satunya tempat error diubah jadi response HTTP.
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: {
        code: err.code ?? 'ERROR',
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
      },
    });
    return;
  }

  // Pelanggaran constraint database -> pesan yang bisa dimengerti pengguna.
  const pgErr = err as { code?: string; constraint?: string; detail?: string };
  if (pgErr?.code === '23505') {
    res.status(409).json({
      error: {
        code: 'CONFLICT',
        message: 'Data sudah terdaftar (nomor HP atau email sudah dipakai)',
        ...(env.NODE_ENV !== 'production' ? { details: pgErr.detail } : {}),
      },
    });
    return;
  }
  if (pgErr?.code === '23503') {
    res.status(400).json({
      error: { code: 'BAD_REQUEST', message: 'Referensi data tidak ditemukan' },
    });
    return;
  }

  console.error('[error] tidak tertangani:', err);
  res.status(500).json({
    error: {
      code: 'INTERNAL',
      message: 'Terjadi kesalahan di server',
      ...(env.NODE_ENV !== 'production'
        ? { details: err instanceof Error ? err.message : String(err) }
        : {}),
    },
  });
}
