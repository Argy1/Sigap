import type { NextFunction, Request, Response } from 'express';
import type { ZodType } from 'zod';
import { badRequest } from '../utils/errors.js';

type Source = 'body' | 'query' | 'params';

/**
 * Validasi + koersi input pakai Zod. Hasil parse menggantikan nilai aslinya,
 * jadi controller selalu menerima data yang sudah bertipe benar.
 */
export function validate<T>(schema: ZodType<T>, source: Source = 'body') {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      return next(
        badRequest(
          'Input tidak valid',
          result.error.issues.map((i) => ({
            field: i.path.join('.'),
            message: i.message,
          })),
        ),
      );
    }
    // req.query di Express 5 read-only -> simpan hasil parse di properti terpisah.
    if (source === 'query') {
      (req as Request & { validatedQuery?: unknown }).validatedQuery = result.data;
    } else {
      req[source] = result.data as never;
    }
    next();
  };
}

/** Ambil hasil validasi query yang disimpan oleh validate(..., 'query'). */
export function validatedQuery<T>(req: Request): T {
  return (req as Request & { validatedQuery: T }).validatedQuery;
}
