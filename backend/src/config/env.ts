import 'dotenv/config';
import { z } from 'zod';

/**
 * Semua environment variable divalidasi di satu tempat saat boot.
 * Kalau ada yang salah/hilang, proses berhenti dengan pesan jelas —
 * jauh lebih baik daripada `undefined` yang meledak di tengah request.
 */
const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),

  DATABASE_URL: z.string().min(1, 'DATABASE_URL wajib diisi'),
  DATABASE_SSL: z
    .string()
    .default('false')
    .transform((v) => v.toLowerCase() === 'true'),

  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET terlalu pendek'),
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET terlalu pendek'),
  JWT_CALL_SECRET: z.string().min(16, 'JWT_CALL_SECRET terlalu pendek'),

  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_REFRESH_TTL: z.string().default('30d'),
  JWT_CALL_TTL: z.string().default('6h'),

  CORS_ORIGINS: z
    .string()
    .default('http://localhost:3000')
    .transform((v) =>
      v
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean),
    ),

  // Kosong = mode fallback (haversine + alamat placeholder). Lihat routing.service.ts.
  GOOGLE_MAPS_API_KEY: z.string().default(''),

  NEAREST_HOSPITAL_CANDIDATES: z.coerce.number().int().min(1).max(25).default(5),
  DRIVER_LOCATION_MAX_AGE_SECONDS: z.coerce.number().int().positive().default(300),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  console.error('\n[config] Environment tidak valid:\n');
  for (const issue of parsed.error.issues) {
    console.error(`  - ${issue.path.join('.')}: ${issue.message}`);
  }
  console.error('\nSalin backend/.env.example jadi backend/.env lalu isi nilainya.\n');
  process.exit(1);
}

export const env = parsed.data;

/** True kalau Google Maps aktif; false = seluruh sistem pakai fallback bawaan. */
export const hasGoogleMaps = env.GOOGLE_MAPS_API_KEY.trim().length > 0;
