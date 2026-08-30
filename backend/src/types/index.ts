/** Empat role sistem. Menentukan seluruh keputusan akses. */
export type Role = 'patient' | 'hospital_staff' | 'driver' | 'admin';

export type CallStatus =
  | 'pending'
  | 'confirmed'
  | 'en_route'
  | 'arrived'
  | 'completed'
  | 'cancelled';

export type AvailabilityStatus = 'available' | 'busy' | 'offline';

export type VerificationStatus = 'unverified' | 'verified' | 'rejected';

/** Payload access token. */
export interface AccessTokenPayload {
  sub: string; // profile id
  role: Role;
  hospitalId: string | null; // untuk hospital_staff & driver
  driverId: string | null; // hanya untuk role driver
}

/**
 * Payload call token — dipakai MODE TAMU.
 *
 * Tamu tidak punya akun, jadi tidak punya access token. Saat SOS tamu dibuat,
 * backend mengembalikan token ini yang cakupannya HANYA satu panggilan:
 * cukup untuk memantau status + posisi sopir, tidak bisa apa-apa lagi.
 */
export interface CallTokenPayload {
  callId: string;
  scope: 'call';
}

/** Konteks pengguna yang menempel di setiap request setelah middleware auth. */
export interface AuthContext {
  profileId: string;
  role: Role;
  hospitalId: string | null;
  driverId: string | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      /** Terisi oleh middleware `authenticate` / `optionalAuthenticate`. */
      auth?: AuthContext;
      /** Terisi oleh middleware `callTokenAuth` (mode tamu). */
      callAccess?: { callId: string };
    }
  }
}

export interface LatLng {
  lat: number;
  lng: number;
}
