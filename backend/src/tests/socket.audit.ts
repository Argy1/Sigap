/**
 * Audit kebocoran RBAC lewat SOCKET.
 *
 * Audit RBAC yang satunya hanya menguji HTTP — dan justru itu yang membuat satu
 * kebocoran nyata lolos: sopir sempat ikut di-join ke room rumah sakit, sehingga
 * menerima siaran SETIAP SOS milik RS itu lengkap dengan nama, nomor HP, alamat,
 * dan data medis pasien yang bukan tugasnya. Endpoint HTTP-nya rapat; salurannya
 * yang bocor.
 *
 * Berkas ini menutup celah pengujian itu: setiap uji di bawah memastikan sebuah
 * event TIDAK sampai ke pihak yang tidak berhak.
 *
 * Prasyarat: backend jalan + database sudah di-seed.
 * Jalankan: npm run test:socket
 */
import { io, type Socket } from 'socket.io-client';

const BASE = process.env.API_BASE ?? 'http://localhost:4000';
const API = `${BASE}/api`;

let passed = 0;
let failed = 0;

function check(label: string, ok: boolean, extra = ''): void {
  if (ok) {
    passed++;
    console.log(`  PASS  ${label}`);
  } else {
    failed++;
    console.log(`  FAIL  ${label} ${extra}`);
  }
}

async function http(
  method: string,
  path: string,
  opts: { body?: unknown; token?: string } = {},
) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.token) headers.Authorization = `Bearer ${opts.token}`;
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

const connect = (auth: Record<string, string>): Promise<Socket> =>
  new Promise((resolve, reject) => {
    const s = io(BASE, { auth, transports: ['websocket'] });
    s.once('ready', () => resolve(s));
    s.once('connect_error', reject);
    setTimeout(() => reject(new Error('Timeout koneksi socket')), 6000);
  });

/**
 * Kumpulkan setiap event bernama `event` yang diterima socket ini.
 *
 * Uji kebocoran bekerja terbalik dari uji biasa: kita membuktikan sesuatu TIDAK
 * datang. Karena itu event dikumpulkan selama jendela waktu tertentu, lalu
 * diperiksa isinya kosong.
 */
function collect<T = any>(socket: Socket, event: string): T[] {
  const received: T[] = [];
  socket.on(event, (payload: T) => received.push(payload));
  return received;
}

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function main(): Promise<void> {
  console.log('\n=== AUDIT SOCKET — event tidak boleh sampai ke pihak salah ===\n');

  const staffA = await login('staff@rsudbogor.id'); // RSUD Kota Bogor
  const staffB = await login('staff@rspmibogor.id'); // RS PMI Bogor
  const driverA = await login('081211110001'); // sopir RSUD
  const driverB = await login('081222220001'); // sopir PMI
  const patient = await login('081234567890');
  const patient2 = await login('081234567891');

  // Sopir harus tersedia agar bisa ditugaskan.
  await http('PATCH', '/drivers/me/availability', {
    token: driverA.accessToken,
    body: { availabilityStatus: 'available' },
  });

  const socketStaffA = await connect({ token: staffA.accessToken });
  const socketStaffB = await connect({ token: staffB.accessToken });
  const socketDriverA = await connect({ token: driverA.accessToken });
  const socketDriverB = await connect({ token: driverB.accessToken });
  const socketPatient2 = await connect({ token: patient2.accessToken });

  // Semua penerima yang TIDAK berhak mulai merekam.
  const staffBSaw = collect(socketStaffB, 'sos:new');
  const driverASawSos = collect(socketDriverA, 'sos:new');
  const driverASawUpdate = collect(socketDriverA, 'sos:updated');
  const driverBSaw = collect(socketDriverB, 'assignment:new');
  const patient2Saw = collect(socketPatient2, 'call:status');

  const staffASaw = collect(socketStaffA, 'sos:new');
  const driverAAssignments = collect(socketDriverA, 'assignment:new');

  // ---- Buat SOS yang jatuh ke RSUD (RS milik staffA) ----------------------
  const created = await http('POST', '/emergency-calls', {
    token: patient.accessToken,
    body: { lat: -6.5878, lng: 106.7862, conditionNote: 'uji audit socket' },
  });
  const call = created.body.call;
  console.log(`  (panggilan uji ${call.callCode} -> ${call.hospitalName})\n`);

  await wait(900);

  // ---- Kontrol positif: yang BERHAK memang menerima -----------------------
  console.log('--- Kontrol positif ---');
  check('Staff RS pemilik menerima sos:new', staffASaw.some((c: any) => c.id === call.id));

  // ---- Kebocoran antar RS -------------------------------------------------
  console.log('\n--- Isolasi antar rumah sakit ---');
  check(
    'Staff RS LAIN tidak menerima sos:new',
    !staffBSaw.some((c: any) => c.id === call.id),
    `bocor ${staffBSaw.length} event`,
  );

  // ---- Kebocoran ke sopir (bug yang ditemukan & diperbaiki) ---------------
  console.log('\n--- Sopir tidak boleh mendengar siaran rumah sakit ---');
  check(
    'Sopir TIDAK menerima sos:new milik RS-nya',
    driverASawSos.length === 0,
    `bocor ${driverASawSos.length} event berisi data pasien`,
  );
  check(
    'Sopir TIDAK menerima sos:updated sebelum ditugaskan',
    driverASawUpdate.length === 0,
    `bocor ${driverASawUpdate.length} event`,
  );

  // ---- Penugasan ----------------------------------------------------------
  const suggested = await http('GET', `/emergency-calls/${call.id}/suggested-drivers`, {
    token: staffA.accessToken,
  });
  const chosen =
    suggested.body.drivers.find((d: any) => d.profileId === driverA.user.id) ??
    suggested.body.drivers[0];

  await http('POST', `/emergency-calls/${call.id}/assign`, {
    token: staffA.accessToken,
    body: { driverId: chosen.id },
  });
  await wait(900);

  console.log('\n--- Penugasan hanya sampai ke sopir yang dipilih ---');
  check(
    'Sopir yang ditugaskan menerima assignment:new',
    driverAAssignments.some((c: any) => c.id === call.id),
  );
  check(
    'Sopir RS LAIN tidak menerima assignment:new',
    !driverBSaw.some((c: any) => c.id === call.id),
    `bocor ${driverBSaw.length} event`,
  );

  // ---- Kebocoran antar pasien --------------------------------------------
  console.log('\n--- Isolasi antar pasien ---');
  await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: driverA.accessToken,
    body: { status: 'en_route' },
  });
  await wait(900);

  check(
    'Pasien lain tidak menerima call:status panggilan orang lain',
    !patient2Saw.some((c: any) => c.id === call.id),
    `bocor ${patient2Saw.length} event`,
  );

  // ---- call:watch tidak bisa dipakai menembus room ------------------------
  console.log('\n--- call:watch tidak bisa dipakai menembus room ---');

  const watchResult = await new Promise<any>((resolve) => {
    socketPatient2.emit('call:watch', { callId: call.id }, resolve);
    setTimeout(() => resolve({ ok: null }), 3000);
  });
  check(
    'Pasien lain ditolak saat call:watch panggilan bukan miliknya',
    watchResult?.ok === false,
    JSON.stringify(watchResult),
  );

  const watchResultDriverB = await new Promise<any>((resolve) => {
    socketDriverB.emit('call:watch', { callId: call.id }, resolve);
    setTimeout(() => resolve({ ok: null }), 3000);
  });
  check(
    'Sopir RS lain ditolak saat call:watch',
    watchResultDriverB?.ok === false,
    JSON.stringify(watchResultDriverB),
  );

  // ---- Socket tanpa kredensial -------------------------------------------
  console.log('\n--- Handshake socket ---');
  const anonRejected = await new Promise<boolean>((resolve) => {
    const s = io(BASE, { transports: ['websocket'], reconnection: false });
    s.once('connect_error', () => {
      s.close();
      resolve(true);
    });
    s.once('ready', () => {
      s.close();
      resolve(false);
    });
    setTimeout(() => resolve(false), 4000);
  });
  check('Socket tanpa kredensial ditolak', anonRejected);

  const fakeRejected = await new Promise<boolean>((resolve) => {
    const s = io(BASE, {
      auth: { token: 'token.yang.dipalsukan' },
      transports: ['websocket'],
      reconnection: false,
    });
    s.once('connect_error', () => {
      s.close();
      resolve(true);
    });
    s.once('ready', () => {
      s.close();
      resolve(false);
    });
    setTimeout(() => resolve(false), 4000);
  });
  check('Socket dengan token palsu ditolak', fakeRejected);

  // ---- Bersihkan ----------------------------------------------------------
  await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: staffA.accessToken,
    body: { status: 'cancelled', cancelReason: 'pembersihan audit socket' },
  });

  for (const s of [
    socketStaffA,
    socketStaffB,
    socketDriverA,
    socketDriverB,
    socketPatient2,
  ]) {
    s.disconnect();
  }

  console.log(`\n=== HASIL: ${passed} lulus, ${failed} gagal ===\n`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('\n[socket-audit] Error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
