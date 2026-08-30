'use client';

import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { useAuth } from '@/components/AuthProvider';
import { Sidebar } from '@/components/dispatch/Sidebar';

/**
 * Shell aplikasi: sidebar tetap di kiri + area konten di kanan.
 *
 * Penjagaan akses di sini murni soal PENGALAMAN — mengarahkan pengguna yang
 * belum masuk ke halaman login, bukan mekanisme keamanan. Keamanan sebenarnya
 * ada di backend: setiap endpoint memeriksa role dan kepemilikan barisnya
 * sendiri. Kalau seseorang mengakali navigasi client, dia tetap tidak akan
 * mendapat satu baris data pun.
 */
export default function AppLayout({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !user) router.replace('/login');
  }, [loading, user, router]);

  if (loading || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <div className="font-mono text-[10px] uppercase tracking-[0.15em] text-[var(--text-secondary)]">
          Memuat konsol...
        </div>
      </div>
    );
  }

  return (
    <div className="console-surface flex min-h-screen bg-[var(--paper)]">
      <Sidebar />
      <main className="min-w-0 flex-1 px-6 py-5.5">{children}</main>
    </div>
  );
}
