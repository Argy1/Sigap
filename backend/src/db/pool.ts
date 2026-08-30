import pg from 'pg';
import { env } from '../config/env.js';

/**
 * Satu Pool untuk seluruh aplikasi. Tanpa ORM — semua query ditulis manual
 * dengan parameter ($1, $2, ...) supaya tidak ada celah SQL injection.
 */
export const pool = new pg.Pool({
  connectionString: env.DATABASE_URL,
  ssl: env.DATABASE_SSL ? { rejectUnauthorized: false } : undefined,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 15_000,
});

pool.on('error', (err) => {
  console.error('[db] idle client error:', err.message);
});

/** Helper query bertipe. */
export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params: readonly unknown[] = [],
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(text, params as unknown[]);
}

/** Ambil satu baris atau null. */
export async function queryOne<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params: readonly unknown[] = [],
): Promise<T | null> {
  const res = await pool.query<T>(text, params as unknown[]);
  return res.rows[0] ?? null;
}

/** Jalankan sekumpulan operasi dalam satu transaksi. */
export async function withTransaction<T>(
  fn: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
