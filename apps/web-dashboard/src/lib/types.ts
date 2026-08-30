export type Role = 'patient' | 'hospital_staff' | 'driver' | 'admin';

export type CallStatus =
  | 'pending'
  | 'confirmed'
  | 'en_route'
  | 'arrived'
  | 'completed'
  | 'cancelled';

export type AvailabilityStatus = 'available' | 'busy' | 'offline';

export interface LatLng {
  lat: number;
  lng: number;
}

export interface AuthUser {
  id: string;
  role: Role;
  fullName: string;
  phone: string | null;
  email: string | null;
  hospitalId: string | null;
  hospitalName: string | null;
  driverId: string | null;
  vehiclePlate: string | null;
  availabilityStatus: AvailabilityStatus | null;
}

export interface EmergencyCall {
  id: string;
  callCode: string;
  patientId: string | null;
  hospitalId: string | null;
  hospitalName: string | null;
  driverId: string | null;
  driverName: string | null;
  driverPhone: string | null;
  vehiclePlate: string | null;
  patientName: string;
  patientPhone: string | null;
  isGuest: boolean;
  location: LatLng;
  patientAddress: string | null;
  status: CallStatus;
  conditionNote: string | null;
  cancelReason: string | null;
  medical: {
    bloodType: string | null;
    allergies: string[];
    medicalHistory: string | null;
  } | null;
  driverLocation: LatLng | null;
  createdAt: string;
  confirmedAt: string | null;
  enRouteAt: string | null;
  arrivedAt: string | null;
  completedAt: string | null;
  cancelledAt: string | null;
}

export interface Driver {
  id: string;
  profileId: string;
  hospitalId: string;
  fullName: string;
  phone: string | null;
  vehiclePlate: string | null;
  availabilityStatus: AvailabilityStatus;
  isActive: boolean;
  location: LatLng | null;
  locationUpdatedAt: string | null;
}

export interface SuggestedDriver extends Omit<Driver, 'isActive' | 'location'> {
  lat: number | null;
  lng: number | null;
  straightMeters: number | null;
  distanceMeters: number | null;
  durationSeconds: number | null;
  /** False kalau belum pernah kirim posisi ATAU posisinya sudah lewat batas usia. */
  hasFreshLocation: boolean;
}

export interface Hospital {
  id: string;
  name: string;
  address: string;
  phone: string | null;
  lat: number;
  lng: number;
  verificationStatus: 'unverified' | 'verified' | 'rejected';
  verifiedAt: string | null;
  createdAt: string;
  driverCount?: number;
}

/** Label bahasa Indonesia untuk tiap status — dipakai di seluruh UI. */
export const STATUS_LABEL: Record<CallStatus, string> = {
  pending: 'Menunggu Konfirmasi',
  confirmed: 'Sopir Ditugaskan',
  en_route: 'Sopir Menuju Lokasi',
  arrived: 'Tiba di Lokasi',
  completed: 'Selesai',
  cancelled: 'Dibatalkan',
};

export const AVAILABILITY_LABEL: Record<AvailabilityStatus, string> = {
  available: 'Tersedia',
  busy: 'Bertugas',
  offline: 'Tidak Aktif',
};

/** Panggilan yang masih butuh perhatian operator. */
export const ACTIVE_STATUSES: CallStatus[] = [
  'pending',
  'confirmed',
  'en_route',
  'arrived',
];

export const isActiveCall = (c: EmergencyCall) => ACTIVE_STATUSES.includes(c.status);
