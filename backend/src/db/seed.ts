import bcrypt from 'bcryptjs';
import { pool, query, queryOne } from './pool.js';

/**
 * Data awal untuk demo & pengembangan.
 *
 * Koordinat rumah sakit di bawah adalah lokasi asli di Kota Bogor, bukan angka
 * karangan — supaya pengujian query PostGIS "RS terdekat" menghasilkan urutan
 * yang benar-benar masuk akal secara geografis.
 *
 * Idempoten: menjalankannya berkali-kali tidak menggandakan data.
 */

const PASSWORD = 'password123';

interface HospitalSeed {
  name: string;
  address: string;
  lat: number;
  lng: number;
  phone: string;
  status: 'verified' | 'unverified';
}

const HOSPITALS: HospitalSeed[] = [
  {
    name: 'RSUD Kota Bogor',
    address: 'Jl. Dr. Sumeru No. 120, Menteng, Bogor Barat',
    lat: -6.5871,
    lng: 106.7856,
    phone: '0251-8312292',
    status: 'verified',
  },
  {
    name: 'RS PMI Bogor',
    address: 'Jl. Raya Pajajaran No. 80, Bantarjati, Bogor Utara',
    lat: -6.5836,
    lng: 106.8074,
    phone: '0251-8324080',
    status: 'verified',
  },
  {
    name: 'RS Salak Bogor',
    address: 'Jl. Jenderal Sudirman No. 8, Sempur, Bogor Tengah',
    lat: -6.5905,
    lng: 106.7965,
    phone: '0251-8344609',
    status: 'verified',
  },
  {
    name: 'RS Hermina Bogor',
    address: 'Jl. Ring Road I No. 75, Curug Mekar, Bogor Barat',
    lat: -6.5729,
    lng: 106.7756,
    phone: '0251-8382525',
    status: 'unverified', // menunggu verifikasi admin — tampil di Panel Admin
  },
  {
    name: 'RS Azra Bogor',
    address: 'Jl. Raya Pajajaran No. 219, Bantarjati, Bogor Utara',
    lat: -6.5784,
    lng: 106.8103,
    phone: '0251-8318456',
    status: 'unverified',
  },
  {
    name: 'RS Vania Bogor',
    address: 'Jl. Siliwangi No. 88, Sukasari, Bogor Timur',
    lat: -6.6055,
    lng: 106.8069,
    phone: '0251-8380900',
    status: 'verified',
  },
];

interface DriverSeed {
  fullName: string;
  phone: string;
  plate: string;
  /** Posisi awal — supaya query "sopir terdekat" langsung punya data. */
  lat: number;
  lng: number;
  status: 'available' | 'busy' | 'offline';
}

const DRIVERS_RSUD: DriverSeed[] = [
  { fullName: 'Ahmad Ridwan', phone: '081211110001', plate: 'F 1234 XZ', lat: -6.5885, lng: 106.7871, status: 'available' },
  { fullName: 'Dedi Prasetyo', phone: '081211110002', plate: 'F 5678 YA', lat: -6.5920, lng: 106.7910, status: 'available' },
  { fullName: 'Bambang Suryanto', phone: '081211110003', plate: 'F 9012 ZB', lat: -6.5810, lng: 106.7800, status: 'busy' },
  { fullName: 'Rudi Hartono', phone: '081211110004', plate: 'F 3456 XC', lat: -6.5860, lng: 106.7840, status: 'offline' },
  { fullName: 'Yusuf Setiawan', phone: '081211110005', plate: 'F 7890 YD', lat: -6.5950, lng: 106.7890, status: 'available' },
];

const DRIVERS_PMI: DriverSeed[] = [
  { fullName: 'Iwan Kurniawan', phone: '081222220001', plate: 'F 2468 PM', lat: -6.5845, lng: 106.8060, status: 'available' },
  { fullName: 'Slamet Riyadi', phone: '081222220002', plate: 'F 1357 PM', lat: -6.5800, lng: 106.8090, status: 'available' },
];

async function upsertProfile(opts: {
  role: string;
  fullName: string;
  phone?: string | null;
  email?: string | null;
  hospitalId?: string | null;
}): Promise<string> {
  const hash = await bcrypt.hash(PASSWORD, 10);

  const existing = await queryOne<{ id: string }>(
    `SELECT id FROM profiles
     WHERE ($1::text IS NOT NULL AND phone = $1)
        OR ($2::text IS NOT NULL AND lower(email) = lower($2))`,
    [opts.phone ?? null, opts.email ?? null],
  );

  if (existing) {
    await query(
      `UPDATE profiles SET full_name = $2, role = $3, hospital_id = $4, password_hash = $5
       WHERE id = $1`,
      [existing.id, opts.fullName, opts.role, opts.hospitalId ?? null, hash],
    );
    return existing.id;
  }

  const row = await queryOne<{ id: string }>(
    `INSERT INTO profiles (role, full_name, phone, email, password_hash, hospital_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id`,
    [opts.role, opts.fullName, opts.phone ?? null, opts.email ?? null, hash, opts.hospitalId ?? null],
  );
  return row!.id;
}

async function seedHospital(h: HospitalSeed): Promise<string> {
  const existing = await queryOne<{ id: string }>(
    'SELECT id FROM hospitals WHERE name = $1',
    [h.name],
  );
  if (existing) {
    await query(
      `UPDATE hospitals SET
         address = $2, phone = $3, verification_status = $4,
         location = ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography,
         verified_at = CASE WHEN $4 = 'verified' THEN COALESCE(verified_at, now()) ELSE NULL END
       WHERE id = $1`,
      [existing.id, h.address, h.phone, h.status, h.lng, h.lat],
    );
    return existing.id;
  }

  const row = await queryOne<{ id: string }>(
    `INSERT INTO hospitals (name, address, location, phone, verification_status, verified_at)
     VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, $5, $6,
             CASE WHEN $6 = 'verified' THEN now() ELSE NULL END)
     RETURNING id`,
    [h.name, h.address, h.lng, h.lat, h.phone, h.status],
  );
  return row!.id;
}

async function seedDriver(hospitalId: string, d: DriverSeed): Promise<void> {
  const profileId = await upsertProfile({
    role: 'driver',
    fullName: d.fullName,
    phone: d.phone,
    hospitalId,
  });

  const existing = await queryOne<{ id: string }>(
    'SELECT id FROM drivers WHERE profile_id = $1',
    [profileId],
  );

  if (existing) {
    await query(
      `UPDATE drivers SET
         hospital_id = $2, vehicle_plate = $3, availability_status = $4,
         current_location = ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography,
         location_updated_at = now()
       WHERE id = $1`,
      [existing.id, hospitalId, d.plate, d.status, d.lng, d.lat],
    );
    return;
  }

  await query(
    `INSERT INTO drivers
       (profile_id, hospital_id, vehicle_plate, availability_status,
        current_location, location_updated_at)
     VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($5, $6), 4326)::geography, now())`,
    [profileId, hospitalId, d.plate, d.status, d.lng, d.lat],
  );
}

async function main(): Promise<void> {
  console.log('[seed] Mengisi data awal...');

  const hospitalIds = new Map<string, string>();
  for (const h of HOSPITALS) {
    const id = await seedHospital(h);
    hospitalIds.set(h.name, id);
    console.log(`[seed] RS  ${h.status === 'verified' ? '[terverifikasi]' : '[menunggu]  '} ${h.name}`);
  }

  const rsudId = hospitalIds.get('RSUD Kota Bogor')!;
  const pmiId = hospitalIds.get('RS PMI Bogor')!;

  // --- Admin platform -------------------------------------------------------
  await upsertProfile({
    role: 'admin',
    fullName: 'Admin Platform',
    email: 'admin@sigap.id',
  });

  // --- Staff RS -------------------------------------------------------------
  // Dua RS berbeda, sengaja: dipakai audit RBAC untuk membuktikan staff RS A
  // tidak bisa menyentuh data RS B.
  const sitiId = await upsertProfile({
    role: 'hospital_staff',
    fullName: 'Siti Pratiwi',
    email: 'staff@rsudbogor.id',
    hospitalId: rsudId,
  });
  await upsertProfile({
    role: 'hospital_staff',
    fullName: 'Rina Kartika',
    email: 'staff@rspmibogor.id',
    hospitalId: pmiId,
  });
  await query('UPDATE hospitals SET created_by = $1 WHERE id = $2', [sitiId, rsudId]);

  // --- Sopir ----------------------------------------------------------------
  for (const d of DRIVERS_RSUD) await seedDriver(rsudId, d);
  for (const d of DRIVERS_PMI) await seedDriver(pmiId, d);
  console.log(`[seed] Sopir: ${DRIVERS_RSUD.length + DRIVERS_PMI.length} akun`);

  // --- Pasien demo ----------------------------------------------------------
  const budiId = await upsertProfile({
    role: 'patient',
    fullName: 'Budi Santoso',
    phone: '081234567890',
  });
  await query(
    `INSERT INTO patient_profiles
       (profile_id, blood_type, allergies, medical_history,
        emergency_contact_name, emergency_contact_phone)
     VALUES ($1, 'O+', ARRAY['Penisilin'], 'Hipertensi, riwayat jantung',
             'Sri Santoso', '081298765432')
     ON CONFLICT (profile_id) DO UPDATE SET
       blood_type = EXCLUDED.blood_type,
       allergies = EXCLUDED.allergies,
       medical_history = EXCLUDED.medical_history,
       emergency_contact_name = EXCLUDED.emergency_contact_name,
       emergency_contact_phone = EXCLUDED.emergency_contact_phone`,
    [budiId],
  );

  const rinaId = await upsertProfile({
    role: 'patient',
    fullName: 'Rina Wulandari',
    phone: '081234567891',
  });
  await query(
    `INSERT INTO patient_profiles (profile_id, blood_type, allergies)
     VALUES ($1, 'B+', ARRAY[]::text[])
     ON CONFLICT (profile_id) DO NOTHING`,
    [rinaId],
  );

  console.log('');
  console.log('  ┌──────────────────────────────────────────────────────────────┐');
  console.log('  │  AKUN DEMO — kata sandi semuanya: password123                │');
  console.log('  ├──────────────────────────────────────────────────────────────┤');
  console.log('  │  Admin        admin@sigap.id                              │');
  console.log('  │  Staff RSUD   staff@rsudbogor.id                             │');
  console.log('  │  Staff PMI    staff@rspmibogor.id                            │');
  console.log('  │  Sopir        081211110001  (Ahmad Ridwan, RSUD)             │');
  console.log('  │  Pasien       081234567890  (Budi Santoso)                   │');
  console.log('  └──────────────────────────────────────────────────────────────┘');
  console.log('');
}

try {
  await main();
  console.log('[seed] Selesai.');
} catch (err) {
  console.error('[seed] Gagal:', err instanceof Error ? err.message : err);
  process.exitCode = 1;
} finally {
  await pool.end();
}
