/**
 * Uji golden path end-to-end lewat HTTP sungguhan.
 *
 * Bukan unit test — ini menjalankan alur SOS lengkap persis seperti yang akan
 * dilakukan ketiga aplikasi client, termasuk verifikasi bahwa event Socket.io
 * benar-benar sampai ke penerima yang tepat.
 *
 * Prasyarat: backend sudah jalan (`npm run dev`) dan database sudah di-seed.
 * Jalankan: npm run test:goldenpath
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

interface HttpResult<T = any> {
  status: number;
  body: T;
}

async function http<T = any>(
  method: string,
  path: string,
  opts: { body?: unknown; token?: string; callToken?: string } = {},
): Promise<HttpResult<T>> {
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

const login = async (identifier: string, password = 'password123') => {
  const r = await http('POST', '/auth/login', { body: { identifier, password } });
  if (r.status !== 200) throw new Error(`Login ${identifier} gagal: ${JSON.stringify(r.body)}`);
  return r.body as { accessToken: string; user: any };
};

/** Tunggu satu event socket, dengan batas waktu. */
function waitFor<T = any>(socket: Socket, event: string, ms = 6000): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timeout menunggu "${event}"`)), ms);
    socket.once(event, (payload: T) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

const connect = (auth: Record<string, string>): Promise<Socket> =>
  new Promise((resolve, reject) => {
    const s = io(BASE, { auth, transports: ['websocket'] });
    s.once('ready', () => resolve(s));
    s.once('connect_error', reject);
    setTimeout(() => reject(new Error('Timeout koneksi socket')), 6000);
  });

/**
 * Lokasi pasien sengaja diletakkan tepat di sekitar RSUD Kota Bogor.
 *
 * Alasannya penting: uji ini masuk sebagai staff RSUD, jadi RS terdekat HARUS
 * RSUD supaya penugasan sopir berada dalam cakupan RS yang benar. Kalau lokasi
 * diambil sembarangan, RS lain bisa menang dan uji ini gagal karena RBAC
 * bekerja dengan benar — bukan karena ada bug.
 */
const PATIENT_LOCATION = { lat: -6.5878, lng: 106.7862 };
const GUEST_LOCATION = { lat: -6.5866, lng: 106.7849 };

async function main(): Promise<void> {
  console.log('\n=== GOLDEN PATH — alur SOS end-to-end ===\n');

  // -- Langkah 0: semua aktor masuk ------------------------------------------
  const patient = await login('081234567890');
  const staff = await login('staff@rsudbogor.id');
  const driverUser = await login('081211110001');
  check('Semua aktor bisa masuk', true);

  // Sopir harus tersedia sebelum bisa ditugaskan.
  await http('PATCH', '/drivers/me/availability', {
    token: driverUser.accessToken,
    body: { availabilityStatus: 'available' },
  });

  // -- Socket: RS & sopir mendengarkan ---------------------------------------
  const staffSocket = await connect({ token: staff.accessToken });
  const driverSocket = await connect({ token: driverUser.accessToken });
  check('Socket RS & sopir terhubung', true);

  const sosNewPromise = waitFor(staffSocket, 'sos:new');

  // -- Langkah 1-2: pasien menekan SOS ---------------------------------------
  const created = await http('POST', '/emergency-calls', {
    token: patient.accessToken,
    body: { ...PATIENT_LOCATION, conditionNote: 'Dugaan serangan jantung' },
  });
  check('SOS dibuat (201)', created.status === 201, JSON.stringify(created.body));

  const call = created.body.call;
  check('Kode panggilan terbentuk', typeof call.callCode === 'string' && call.callCode.startsWith('A'));
  check('RS terdekat otomatis terpilih', call.hospitalId !== null, `-> ${call.hospitalName}`);
  check(
    'RS terpilih adalah yang benar-benar terdekat (RSUD Kota Bogor)',
    call.hospitalName === 'RSUD Kota Bogor',
    `-> ${call.hospitalName}`,
  );
  check('Alamat hasil reverse geocoding terisi', typeof call.patientAddress === 'string');
  check(
    'Data medis ikut ter-snapshot',
    call.medical?.bloodType === 'O+' && call.medical.allergies.includes('Penisilin'),
    JSON.stringify(call.medical),
  );
  check('Status awal pending', call.status === 'pending');

  // -- Langkah 3: RS menerima notifikasi realtime ----------------------------
  const sosNew: any = await sosNewPromise;
  check('RS menerima event sos:new secara realtime', sosNew.id === call.id);

  // -- Langkah 4: backend menyarankan sopir, staff memutuskan ----------------
  const suggested = await http('GET', `/emergency-calls/${call.id}/suggested-drivers`, {
    token: staff.accessToken,
  });
  check('Saran sopir terdekat tersedia', suggested.body.drivers.length > 0);
  check(
    'Saran sopir terurut berdasarkan waktu tempuh',
    suggested.body.drivers[0].durationSeconds !== null,
  );

  const assignmentPromise = waitFor(driverSocket, 'assignment:new');
  const chosenDriver = suggested.body.drivers.find(
    (d: any) => d.profileId === driverUser.user.id,
  ) ?? suggested.body.drivers[0];

  const assigned = await http('POST', `/emergency-calls/${call.id}/assign`, {
    token: staff.accessToken,
    body: { driverId: chosenDriver.id },
  });
  check('Sopir berhasil ditugaskan', assigned.status === 200 && assigned.body.call.driverId === chosenDriver.id);
  check('Status naik jadi confirmed', assigned.body.call.status === 'confirmed');

  // -- Langkah 5: sopir menerima notifikasi ----------------------------------
  const assignment: any = await assignmentPromise;
  check('Sopir menerima event assignment:new', assignment.id === call.id);

  // -- Langkah 6: live tracking ----------------------------------------------
  const patientSocket = await connect({ token: patient.accessToken });
  await new Promise<void>((resolve) =>
    patientSocket.emit('call:watch', { callId: call.id }, () => resolve()),
  );

  const locationPromise = waitFor(patientSocket, 'driver:location');
  driverSocket.emit('driver:location:push', { lat: -6.59, lng: 106.8 });
  const loc: any = await locationPromise;
  check(
    'Pasien menerima posisi sopir secara realtime',
    loc.callId === call.id && typeof loc.lat === 'number',
    JSON.stringify(loc),
  );

  // -- Langkah 7: transisi status --------------------------------------------
  const enRoute = await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: driverUser.accessToken,
    body: { status: 'en_route' },
  });
  check('Sopir mengubah status jadi en_route', enRoute.body.call.status === 'en_route');

  const arrived = await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: driverUser.accessToken,
    body: { status: 'arrived' },
  });
  check('Status jadi arrived', arrived.body.call.status === 'arrived');
  check('arrivedAt tercatat', arrived.body.call.arrivedAt !== null);

  const completed = await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: driverUser.accessToken,
    body: { status: 'completed' },
  });
  check('Status jadi completed', completed.body.call.status === 'completed');

  // Sopir harus otomatis bebas lagi.
  const driverAfter = await http('GET', '/drivers/me', { token: driverUser.accessToken });
  check(
    'Sopir otomatis kembali tersedia setelah tugas selesai',
    driverAfter.body.driver.availabilityStatus === 'available',
    driverAfter.body.driver.availabilityStatus,
  );

  // Transisi ilegal harus ditolak.
  const illegal = await http('PATCH', `/emergency-calls/${call.id}/status`, {
    token: driverUser.accessToken,
    body: { status: 'en_route' },
  });
  check('Transisi status ilegal ditolak', illegal.status === 400, `status=${illegal.status}`);

  // -- MODE TAMU: alur yang sama, tanpa login sama sekali --------------------
  console.log('\n--- Mode tamu (SOS tanpa login) ---\n');

  const guestSosPromise = waitFor(staffSocket, 'sos:new');
  const guest = await http('POST', '/emergency-calls', {
    body: {
      ...GUEST_LOCATION,
      guestName: 'Tetangga Panik',
      guestPhone: '081200009999',
      conditionNote: 'Pingsan, napas pendek',
    },
  });
  check('SOS tamu dibuat tanpa autentikasi', guest.status === 201, JSON.stringify(guest.body));
  check('Tamu menerima callToken', typeof guest.body.callToken === 'string');
  check('Panggilan ditandai sebagai tamu', guest.body.call.isGuest === true);
  check('Nama tamu dipakai sebagai nama pasien', guest.body.call.patientName === 'Tetangga Panik');

  const guestSos: any = await guestSosPromise;
  check('RS tetap menerima SOS tamu secara realtime', guestSos.id === guest.body.call.id);

  const guestRead = await http('GET', `/emergency-calls/${guest.body.call.id}`, {
    callToken: guest.body.callToken,
  });
  check('Tamu bisa memantau panggilannya pakai callToken', guestRead.status === 200);

  const guestSocket = await connect({ callToken: guest.body.callToken });
  check('Socket tamu terhubung dengan callToken', guestSocket.connected);

  const guestCancel = await http('PATCH', `/emergency-calls/${guest.body.call.id}/status`, {
    callToken: guest.body.callToken,
    body: { status: 'cancelled', cancelReason: 'Sudah dibawa keluarga' },
  });
  check('Tamu bisa membatalkan panggilannya', guestCancel.body.call.status === 'cancelled');

  for (const s of [staffSocket, driverSocket, patientSocket, guestSocket]) s.disconnect();

  console.log(`\n=== HASIL: ${passed} lulus, ${failed} gagal ===\n`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('\n[golden-path] Error:', err instanceof Error ? err.message : err);
  process.exit(1);
});
