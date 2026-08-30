import { getIO } from './index.js';
import { ADMIN_ROOM, callRoom, driverRoom, EVENTS, hospitalRoom } from './rooms.js';

/**
 * Semua broadcast keluar lewat fungsi-fungsi di sini.
 *
 * Alasan: siapa menerima event apa jadi bisa dibaca dalam satu file, bukan
 * tersebar di controller. Kalau nanti ada bug "RS lain ikut kebagian notifikasi",
 * tempat mencarinya hanya di sini.
 */

/** SOS baru masuk -> hanya staff RS yang dipilih. */
export function emitSosNew(hospitalId: string, call: unknown): void {
  getIO()?.to(hospitalRoom(hospitalId)).emit(EVENTS.SOS_NEW, call);
}

/**
 * Perubahan pada satu panggilan. Dikirim ke RS (untuk daftar dashboard) DAN ke
 * room panggilan (untuk pasien/tamu yang sedang memantau).
 */
export function emitSosUpdated(
  hospitalId: string | null,
  callId: string,
  call: unknown,
): void {
  const io = getIO();
  if (!io) return;
  if (hospitalId) io.to(hospitalRoom(hospitalId)).emit(EVENTS.SOS_UPDATED, call);
  io.to(callRoom(callId)).emit(EVENTS.CALL_STATUS, call);
}

/** Tugas baru untuk satu sopir. */
export function emitAssignmentNew(driverId: string, call: unknown): void {
  getIO()?.to(driverRoom(driverId)).emit(EVENTS.ASSIGNMENT_NEW, call);
}

/** Tugas sopir dibatalkan atau dialihkan ke sopir lain. */
export function emitAssignmentCancelled(driverId: string, callId: string): void {
  getIO()?.to(driverRoom(driverId)).emit(EVENTS.ASSIGNMENT_CANCELLED, { callId });
}

/** RS baru mendaftar -> panel admin. */
export function emitHospitalRegistered(hospital: unknown): void {
  getIO()?.to(ADMIN_ROOM).emit(EVENTS.HOSPITAL_REGISTERED, hospital);
}
