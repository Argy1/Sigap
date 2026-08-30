import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from './pool.js';

/**
 * Migration runner buatan sendiri — sengaja tanpa library pihak ketiga.
 *
 * Cara kerja: baca semua file `migrations/*.sql` terurut nama, jalankan yang
 * belum tercatat di tabel `schema_migrations`, masing-masing dalam satu
 * transaksi. Tidak ada magic, tidak ada DSL — cocok dengan tujuan proyek ini
 * (membangun backend dari nol).
 *
 * Perintah:
 *   npm run migrate          -> jalankan migration yang belum dijalankan
 *   npm run migrate:status   -> tampilkan status tiap migration
 *   tsx src/db/migrate.ts reset -> DROP seluruh schema publik lalu migrate ulang
 */

const MIGRATIONS_DIR = join(dirname(fileURLToPath(import.meta.url)), 'migrations');

async function ensureMigrationsTable(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name        text PRIMARY KEY,
      applied_at  timestamptz NOT NULL DEFAULT now()
    );
  `);
}

async function listMigrationFiles(): Promise<string[]> {
  const files = await readdir(MIGRATIONS_DIR);
  return files.filter((f) => f.endsWith('.sql')).sort();
}

async function appliedMigrations(): Promise<Set<string>> {
  const res = await pool.query<{ name: string }>('SELECT name FROM schema_migrations');
  return new Set(res.rows.map((r) => r.name));
}

async function up(): Promise<void> {
  await ensureMigrationsTable();
  const files = await listMigrationFiles();
  const applied = await appliedMigrations();

  const pending = files.filter((f) => !applied.has(f));
  if (pending.length === 0) {
    console.log('[migrate] Tidak ada migration baru. Database sudah mutakhir.');
    return;
  }

  for (const file of pending) {
    const sql = await readFile(join(MIGRATIONS_DIR, file), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`[migrate] OK   ${file}`);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`[migrate] GAGAL ${file}`);
      throw err;
    } finally {
      client.release();
    }
  }
  console.log(`[migrate] Selesai. ${pending.length} migration diterapkan.`);
}

async function status(): Promise<void> {
  await ensureMigrationsTable();
  const files = await listMigrationFiles();
  const applied = await appliedMigrations();
  console.log('\n  STATUS  MIGRATION');
  console.log('  ------  ----------------------------------------');
  for (const f of files) {
    console.log(`  ${applied.has(f) ? 'sudah ' : 'BELUM '}  ${f}`);
  }
  console.log('');
}

async function reset(): Promise<void> {
  console.log('[migrate] Menghapus schema public dan membangun ulang...');
  await pool.query('DROP SCHEMA IF EXISTS public CASCADE');
  await pool.query('CREATE SCHEMA public');
  await up();
}

const command = process.argv[2] ?? 'up';

try {
  if (command === 'up') await up();
  else if (command === 'status') await status();
  else if (command === 'reset') await reset();
  else {
    console.error(`Perintah tidak dikenal: ${command}. Gunakan: up | status | reset`);
    process.exitCode = 1;
  }
} catch (err) {
  console.error('\n[migrate] Error:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
} finally {
  await pool.end();
}
