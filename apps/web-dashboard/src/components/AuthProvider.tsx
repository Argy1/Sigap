'use client';

import { useRouter } from 'next/navigation';
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { api, tokenStore } from '@/lib/api';
import type { AuthUser } from '@/lib/types';

interface AuthState {
  user: AuthUser | null;
  loading: boolean;
  login: (identifier: string, password: string) => Promise<AuthUser>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  // Pulihkan sesi dari token yang tersimpan saat halaman dimuat ulang.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!tokenStore.access && !tokenStore.refresh) {
        setLoading(false);
        return;
      }
      try {
        const { user } = await api.me();
        if (!cancelled) setUser(user);
      } catch {
        tokenStore.clear();
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const login = useCallback(async (identifier: string, password: string) => {
    const res = await api.login(identifier, password);

    // Dashboard ini khusus staff RS & admin. Pasien/sopir punya aplikasi
    // sendiri — menolak di sini memberi pesan yang jelas daripada membiarkan
    // mereka masuk ke halaman yang setiap endpoint-nya menjawab 403.
    if (res.user.role !== 'hospital_staff' && res.user.role !== 'admin') {
      throw new Error(
        'Akun ini bukan staff rumah sakit atau admin. Gunakan aplikasi mobile.',
      );
    }

    tokenStore.set(res.accessToken, res.refreshToken);
    setUser(res.user);
    return res.user;
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.logout();
    } catch {
      // Sesi lokal tetap dibersihkan walau permintaan ke server gagal.
    }
    tokenStore.clear();
    setUser(null);
    router.push('/login');
  }, [router]);

  const value = useMemo(
    () => ({ user, loading, login, logout }),
    [user, loading, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth harus dipakai di dalam <AuthProvider>');
  return ctx;
}
