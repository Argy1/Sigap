import { cp, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Salin aset non-TypeScript ke dist/.
 *
 * `tsc` HANYA mengompilasi berkas .ts — berkas .sql tidak ikut terbawa. Tanpa
 * langkah ini, `dist/db/migrations/` kosong dan migration runner di production
 * akan melaporkan "tidak ada migration baru" pada database yang masih kosong:
 * gagal diam-diam, bentuk kegagalan yang paling sulit dilacak.
 */
const root = join(dirname(fileURLToPath(import.meta.url)), '..');

const src = join(root, 'src', 'db', 'migrations');
const dest = join(root, 'dist', 'db', 'migrations');

await mkdir(dest, { recursive: true });
await cp(src, dest, { recursive: true });

console.log(`[build] migration SQL disalin ke ${dest}`);
