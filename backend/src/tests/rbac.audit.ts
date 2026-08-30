/**
 * Audit kebocoran RBAC.
 *
 * Setiap uji di sini adalah percobaan penyalahgunaan yang HARUS ditolak. Uji
 * dianggap lulus kalau server menjawab 401/403 — bukan kalau server "berhasil".
 *
 * Fokus utama: isolasi antar rumah sakit. Seluruh dashboard bertumpu pada
 * asumsi bahwa staff RS A mustahil menyentuh data RS B. Kalau satu saja uji di
 * bawah ini gagal, asumsi itu batal.
 *
 * Prasyarat: backend jalan + database sudah di-seed.
 * Jalankan: npm run test:rbac
 */

const BASE = process.env.API_BASE ?? 'http://localhost:4000';
const API = `${BASE}/api`;

let passed = 0;
let failed = 0;

function expectStatus(label: string, actual: number, allowed: number[]): void {
  if (allowed.includes(actual)) {
    passed++;
    console.log(`  PASS  ${label}  (${actual})`);
  } else {
    failed++;
    console.log(`  FAIL  ${label}  -> dapat ${actual}, harusnya ${allowed.join('/')}`);
  }
}

async function http(
  method: string,
  path: string,
  opts: { body?: unknown; token?: string; callToken?: string } = {},
) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
  if (opts.callToken) headers['X-Call-Token'] = opts.callToken;
  const res = await fetch(`${API}${path}`, {
    method,
    headers,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

const login = async (identifier: string) => {
  const r = await http('POST', '/auth/login', {
    body: { identifier, password: 'password123' },
  });
  if (r.status !== 200) throw new Error(`Login ${identifier} gagal`);
  return r.body as { accessToken: string; user: any };
};

async function main(): Promise<void> {
  console.log('\n=== AUDIT RBAC — semua percobaan di bawah HARUS DITOLAK ===\n');

  const admin = await login('admin@ambulans.id');
  const staffA = await login('staff@rsudbogor.id'); // RSUD Kota Bogor
  const staffB = await login('staff@rspmibogor.id'); // RS PMI Bogor
  const driverA = await login('081211110001'); // sopir RSUD
  const driverB = await login('081222220001'); // sopir PMI
  const patient = await login('081234567890');
  const patient2 = await login('081234567891');

  const hospitalA = staffA.user.hospitalId;
  const hospitalB = staffB.user.hospitalId;

  // Siapkan satu panggilan yang jatuh ke RSUD (RS milik staffA).
  const callA = (
    await http('POST', '/emergency-calls', {
      token: patient.accessToken,
      body: { lat: -6.5878, lng: 106.7862, conditionNote: 'uji rbac' },
    })
  ).body.call;

  console.log(`  (panggilan uji ${callA.callCode} -> ${callA.hospitalName})\n`);

  // ------------------------------------------------------------------------
  console.log('--- Isolasi antar rumah sakit ---');
  // ------------------------------------------------------------------------

  expectStatus(
    'Staff RS B membaca panggilan milik RS A',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: staffB.accessToken })).status,
    [403],
  );

  expectStatus(
    'Staff RS B melihat saran sopir untuk panggilan RS A',
    (
      await http('GET', `/emergency-calls/${callA.id}/suggested-drivers`, {
        token: staffB.accessToken,
      })
    ).status,
    [403],
  );

  expectStatus(
    'Staff RS B menugaskan sopir pada panggilan RS A',
    (
      await http('POST', `/emergency-calls/${callA.id}/assign`, {
        token: staffB.accessToken,
        body: { driverId: '00000000-0000-0000-0000-000000000000' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'Staff RS B mengubah status panggilan RS A',
    (
      await http('PATCH', `/emergency-calls/${callA.id}/status`, {
        token: staffB.accessToken,
        body: { status: 'cancelled' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'Staff RS B membaca profil RS A',
    (await http('GET', `/hospitals/${hospitalA}`, { token: staffB.accessToken })).status,
    [403],
  );

  expectStatus(
    'Staff RS A mengubah profil RS B',
    (
      await http('PATCH', `/hospitals/${hospitalB}`, {
        token: staffA.accessToken,
        body: { name: 'Diretas' },
      })
    ).status,
    [403],
  );

  // Daftar sopir tidak boleh bisa diperlebar lewat query string.
  const driversB = await http('GET', `/drivers?hospitalId=${hospitalB}`, {
    token: staffA.accessToken,
  });
  const bocor =
    driversB.status === 200 &&
    driversB.body.drivers.some((d: any) => d.hospitalId !== hospitalA);
  if (!bocor) {
    passed++;
    console.log('  PASS  Staff RS A tidak bisa melihat sopir RS B lewat ?hospitalId=  (difilter)');
  } else {
    failed++;
    console.log('  FAIL  BOCOR: ?hospitalId= membuat staff RS A melihat sopir RS B');
  }

  // Ambil satu sopir milik RS B untuk diuji sebagai target.
  const bDrivers = await http('GET', '/drivers', { token: staffB.accessToken });
  const targetDriverB = bDrivers.body.drivers[0];

  expectStatus(
    'Staff RS A mengubah data sopir milik RS B',
    (
      await http('PATCH', `/drivers/${targetDriverB.id}`, {
        token: staffA.accessToken,
        body: { fullName: 'Diretas' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'Staff RS A menghapus sopir milik RS B',
    (await http('DELETE', `/drivers/${targetDriverB.id}`, { token: staffA.accessToken })).status,
    [403],
  );

  // ------------------------------------------------------------------------
  console.log('\n--- Isolasi antar pasien ---');
  // ------------------------------------------------------------------------

  expectStatus(
    'Pasien lain membaca panggilan bukan miliknya',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: patient2.accessToken })).status,
    [403],
  );

  expectStatus(
    'Pasien lain membatalkan panggilan bukan miliknya',
    (
      await http('PATCH', `/emergency-calls/${callA.id}/status`, {
        token: patient2.accessToken,
        body: { status: 'cancelled' },
      })
    ).status,
    [403],
  );

  const myCalls = await http('GET', '/emergency-calls', { token: patient2.accessToken });
  const listBocor = myCalls.body.calls.some((c: any) => c.id === callA.id);
  if (!listBocor) {
    passed++;
    console.log('  PASS  Daftar panggilan pasien lain tidak memuat panggilan orang lain');
  } else {
    failed++;
    console.log('  FAIL  BOCOR: daftar panggilan memuat panggilan pasien lain');
  }

  // ------------------------------------------------------------------------
  console.log('\n--- Batasan peran sopir ---');
  // ------------------------------------------------------------------------

  expectStatus(
    'Sopir membaca panggilan yang bukan tugasnya',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: driverB.accessToken })).status,
    [403],
  );

  expectStatus(
    'Sopir mengubah status panggilan yang bukan tugasnya',
    (
      await http('PATCH', `/emergency-calls/${callA.id}/status`, {
        token: driverA.accessToken,
        body: { status: 'en_route' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'Sopir mengakses daftar kelola sopir',
    (await http('GET', '/drivers', { token: driverA.accessToken })).status,
    [403],
  );

  expectStatus(
    'Sopir membuat akun sopir baru',
    (
      await http('POST', '/drivers', {
        token: driverA.accessToken,
        body: { fullName: 'Sopir Bayangan', phone: '081999998888', password: 'rahasia123' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'Sopir menekan SOS lewat akunnya sendiri',
    (
      await http('POST', '/emergency-calls', {
        token: driverA.accessToken,
        body: { lat: -6.59, lng: 106.79 },
      })
    ).status,
    [403],
  );

  // ------------------------------------------------------------------------
  console.log('\n--- Endpoint admin ---');
  // ------------------------------------------------------------------------

  for (const [label, token] of [
    ['Pasien', patient.accessToken],
    ['Staff RS', staffA.accessToken],
    ['Sopir', driverA.accessToken],
  ] as const) {
    expectStatus(
      `${label} membuka daftar verifikasi RS (admin)`,
      (await http('GET', '/admin/hospitals', { token })).status,
      [403],
    );
    expectStatus(
      `${label} memverifikasi RS (admin)`,
      (
        await http('PATCH', `/admin/hospitals/${hospitalB}/verify`, {
          token,
          body: { status: 'verified' },
        })
      ).status,
      [403],
    );
  }

  // ------------------------------------------------------------------------
  console.log('\n--- Token & mode tamu ---');
  // ------------------------------------------------------------------------

  expectStatus(
    'Request tanpa token sama sekali',
    (await http('GET', '/emergency-calls')).status,
    [401],
  );

  expectStatus(
    'Access token palsu',
    (await http('GET', '/auth/me', { token: 'token.yang.dipalsukan' })).status,
    [401],
  );

  // Call token satu panggilan tidak boleh membuka panggilan lain.
  const guest = await http('POST', '/emergency-calls', {
    body: {
      lat: -6.5866,
      lng: 106.7849,
      guestName: 'Tamu Uji',
      guestPhone: '081200001111',
    },
  });
  expectStatus(
    'Call token tamu dipakai membaca panggilan LAIN',
    (
      await http('GET', `/emergency-calls/${callA.id}`, {
        callToken: guest.body.callToken,
      })
    ).status,
    [403],
  );

  expectStatus(
    'Call token tamu dipakai mengubah status jadi completed (bukan cancel)',
    (
      await http('PATCH', `/emergency-calls/${guest.body.call.id}/status`, {
        callToken: guest.body.callToken,
        body: { status: 'completed' },
      })
    ).status,
    [403],
  );

  expectStatus(
    'SOS tamu tanpa nomor HP yang bisa dihubungi',
    (await http('POST', '/emergency-calls', { body: { lat: -6.59, lng: 106.79 } })).status,
    [400],
  );

  // ------------------------------------------------------------------------
  console.log('\n--- Kontrol positif (yang SEHARUSNYA berhasil) ---');
  // ------------------------------------------------------------------------

  expectStatus(
    'Staff RS A membaca panggilan RS-nya sendiri',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: staffA.accessToken })).status,
    [200],
  );
  expectStatus(
    'Pasien pemilik membaca panggilannya sendiri',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: patient.accessToken })).status,
    [200],
  );
  expectStatus(
    'Admin membaca panggilan RS mana pun',
    (await http('GET', `/emergency-calls/${callA.id}`, { token: admin.accessToken })).status,
    [200],
  );
  expectStatus(
    'Admin membuka daftar verifikasi RS',
    (await http('GET', '/admin/hospitals', { token: admin.accessToken })).status,
    [200],
  );
  expectStatus(
    'Pencarian RS terdekat bisa diakses publik',
    (await http('GET', '/hospitals/nearest?lat=-6.5971&lng=106.806')).status,
    [200],
  );

  // Bersihkan panggilan uji supaya tidak menumpuk di dashboard.
  await http('PATCH', `/emergency-calls/${callA.id}/status`, {
    token: staffA.accessToken,
    body: { status: 'cancelled', cancelReason: 'pembersihan uji rbac' },
  });
  await http('PATCH', `/emergency-calls/${guest.body.call.id}/status`, {
    callToken: guest.body.callToken,
    body: { status: 'cancelled', cancelReason: 'pembersihan uji rbac' },
  });

  console.log(`\n=== HASIL: ${passed} lulus, ${failed} gagal ===\n`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('\n[rbac] Error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
