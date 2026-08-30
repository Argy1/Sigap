/**
 * Penamaan room Socket.io — inilah yang menentukan siapa menerima event apa.
 * Kebocoran realtime paling sering terjadi karena room salah, jadi semua nama
 * room dibuat di sini, tidak pernah di-string-concat di tempat lain.
 */

/** Semua staff dari satu RS. */
export const hospitalRoom = (hospitalId: string) => `hospital:${hospitalId}`;

/**
 * Semua pihak yang berkepentingan pada SATU panggilan:
 * pasien (atau tamu pemegang call token) + sopir yang ditugaskan.
 */
export const callRoom = (callId: string) => `call:${callId}`;

/** Satu sopir spesifik — untuk mengirim tugas baru. */
export const driverRoom = (driverId: string) => `driver:${driverId}`;

/** Semua admin platform. */
export const ADMIN_ROOM = 'admin:platform';

/** Nama event, dikumpulkan supaya client & server tidak salah ketik. */
export const EVENTS = {
  /** Server -> RS: ada SOS baru masuk. */
  SOS_NEW: 'sos:new',
  /** Server -> RS: SOS berubah (status, sopir ditugaskan, dibatalkan). */
  SOS_UPDATED: 'sos:updated',
  /** Server -> pasien/tamu: status panggilannya berubah. */
  CALL_STATUS: 'call:status',
  /** Server -> pasien & RS: posisi terbaru sopir. */
  DRIVER_LOCATION: 'driver:location',
  /** Server -> sopir: kamu dapat tugas baru. */
  ASSIGNMENT_NEW: 'assignment:new',
  /** Server -> sopir: tugasmu dibatalkan/dialihkan. */
  ASSIGNMENT_CANCELLED: 'assignment:cancelled',
  /** Server -> admin: ada RS baru mendaftar. */
  HOSPITAL_REGISTERED: 'hospital:registered',

  /** Client (sopir) -> server: kirim posisi. */
  DRIVER_LOCATION_PUSH: 'driver:location:push',
} as const;
