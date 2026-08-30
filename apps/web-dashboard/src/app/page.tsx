'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { useAuth } from '@/components/AuthProvider';

/** Root: arahkan ke tujuan yang sesuai dengan role pengguna. */
export default function RootPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    if (!user) router.replace('/login');
    else router.replace(user.role === 'admin' ? '/admin/hospitals' : '/dashboard');
  }, [user, loading, router]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--paper)]">
      <div className="font-mono text-[10px] uppercase tracking-[0.15em] text-[var(--text-secondary)]">
        Memuat konsol...
      </div>
    </div>
  );
}
