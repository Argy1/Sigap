'use client';

import { API_URL } from './config';
import type {
  AuthUser,
  Driver,
  EmergencyCall,
  Hospital,
  SuggestedDriver,
} from './types';

/**
 * Client HTTP untuk backend Express.
 *
 * Penyimpanan token: access token di memori + localStorage, refresh token di
 * localStorage. Untuk dashboard operasional internal ini, kesederhanaan dan
 * kemudahan menjalankan lebih diutamakan daripada pola cookie httpOnly —
 * dicatat di sini supaya keputusannya eksplisit, bukan kelalaian.
 * Kalau nanti dashboard dibuka ke internet publik, pindahkan refresh token ke
 * cookie httpOnly lewat route handler Next.js.
 */

const ACCESS_KEY = 'sigap.accessToken';
const REFRESH_KEY = 'sigap.refreshToken';

let accessToken: string | null = null;

export const tokenStore = {
  get access(): string | null {
    if (accessToken) return accessToken;
    if (typeof window === 'undefined') return null;
    accessToken = window.localStorage.getItem(ACCESS_KEY);
    return accessToken;
  },
  get refresh(): string | null {
    if (typeof window === 'undefined') return null;
    return window.localStorage.getItem(REFRESH_KEY);
  },
  set(access: string, refresh: string) {
    accessToken = access;
    window.localStorage.setItem(ACCESS_KEY, access);
    window.localStorage.setItem(REFRESH_KEY, refresh);
  },
  clear() {
    accessToken = null;
    if (typeof window === 'undefined') return;
    window.localStorage.removeItem(ACCESS_KEY);
    window.localStorage.removeItem(REFRESH_KEY);
  },
};

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
  }
}

/** Menjaga hanya ada SATU permintaan refresh saat beberapa request 401 bersamaan. */
let refreshInFlight: Promise<boolean> | null = null;

async function tryRefresh(): Promise<boolean> {
  if (refreshInFlight) return refreshInFlight;

  refreshInFlight = (async () => {
    const refresh = tokenStore.refresh;
    if (!refresh) return false;
    try {
      const res = await fetch(`${API_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: refresh }),
      });
      if (!res.ok) {
        tokenStore.clear();
        return false;
      }
      const data = await res.json();
      tokenStore.set(data.accessToken, data.refreshToken);
      return true;
    } catch {
      return false;
    } finally {
      refreshInFlight = null;
    }
  })();

  return refreshInFlight;
}

async function request<T>(
  method: string,
  path: string,
  body?: unknown,
  retry = true,
): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const token = tokenStore.access;
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`${API_URL}/api${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  // Access token kedaluwarsa -> perbarui sekali lalu ulangi permintaan.
  if (res.status === 401 && retry && tokenStore.refresh) {
    if (await tryRefresh()) return request<T>(method, path, body, false);
  }

  if (res.status === 204) return undefined as T;

  const text = await res.text();
  const data = text ? JSON.parse(text) : null;

  if (!res.ok) {
    throw new ApiError(
      res.status,
      data?.error?.message ?? `Permintaan gagal (${res.status})`,
      data?.error?.details,
    );
  }
  return data as T;
}

export const api = {
  // --- Auth ---------------------------------------------------------------
  login: (identifier: string, password: string) =>
    request<{ accessToken: string; refreshToken: string; user: AuthUser }>(
      'POST',
      '/auth/login',
      { identifier, password },
    ),

  me: () => request<{ user: AuthUser }>('GET', '/auth/me'),

  logout: () => request<void>('POST', '/auth/logout', { refreshToken: tokenStore.refresh }),

  // --- Panggilan darurat --------------------------------------------------
  listCalls: (params?: { status?: string; active?: boolean }) => {
    const q = new URLSearchParams();
    if (params?.status) q.set('status', params.status);
    if (params?.active) q.set('active', 'true');
    const qs = q.toString();
    return request<{ calls: EmergencyCall[] }>('GET', `/emergency-calls${qs ? `?${qs}` : ''}`);
  },

  getCall: (id: string) => request<{ call: EmergencyCall }>('GET', `/emergency-calls/${id}`),

  suggestedDrivers: (id: string) =>
    request<{ drivers: SuggestedDriver[] }>('GET', `/emergency-calls/${id}/suggested-drivers`),

  assignDriver: (id: string, driverId: string) =>
    request<{ call: EmergencyCall }>('POST', `/emergency-calls/${id}/assign`, { driverId }),

  changeStatus: (id: string, status: string, cancelReason?: string) =>
    request<{ call: EmergencyCall }>('PATCH', `/emergency-calls/${id}/status`, {
      status,
      ...(cancelReason ? { cancelReason } : {}),
    }),

  // --- Sopir --------------------------------------------------------------
  listDrivers: () => request<{ drivers: Driver[] }>('GET', '/drivers'),

  createDriver: (input: {
    fullName: string;
    phone: string;
    password: string;
    vehiclePlate?: string;
  }) => request<{ driver: Driver }>('POST', '/drivers', input),

  updateDriver: (
    id: string,
    input: Partial<{
      fullName: string;
      vehiclePlate: string | null;
      availabilityStatus: string;
      isActive: boolean;
      password: string;
    }>,
  ) => request<{ driver: Driver }>('PATCH', `/drivers/${id}`, input),

  deleteDriver: (id: string) => request<void>('DELETE', `/drivers/${id}`),

  // --- Rumah sakit --------------------------------------------------------
  getHospital: (id: string) => request<{ hospital: Hospital }>('GET', `/hospitals/${id}`),

  updateHospital: (
    id: string,
    input: Partial<{ name: string; address: string; phone: string | null; lat: number; lng: number }>,
  ) => request<{ hospital: Hospital }>('PATCH', `/hospitals/${id}`, input),

  registerHospital: (input: {
    name: string;
    address: string;
    lat: number;
    lng: number;
    phone?: string;
    staff: { fullName: string; email: string; password: string };
  }) => request<{ hospital: Hospital; message: string }>('POST', '/hospitals/register', input),

  // --- Admin --------------------------------------------------------------
  adminHospitals: (status?: string) =>
    request<{ hospitals: Hospital[] }>(
      'GET',
      `/admin/hospitals${status ? `?status=${status}` : ''}`,
    ),

  verifyHospital: (id: string, status: 'verified' | 'rejected') =>
    request<{ hospital: Hospital }>('PATCH', `/admin/hospitals/${id}/verify`, { status }),
};
