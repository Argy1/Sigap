'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { useAuth } from '@/components/AuthProvider';
import { ReticleBracket } from '@/components/dispatch/ReticleBracket';

export default function LoginPage() {
  const { user, loading, login } = useAuth();
  const router = useRouter();

  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!loading && user) {
      router.replace(user.role === 'admin' ? '/admin/hospitals' : '/dashboard');
    }
  }, [loading, user, router]);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const u = await login(identifier.trim(), password);
      router.replace(u.role === 'admin' ? '/admin/hospitals' : '/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Gagal masuk');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="console-surface flex min-h-screen items-center justify-center bg-[var(--paper)] px-4">
      <div className="w-full max-w-[380px]">
        {/* Bracket reticle mengelilingi logo — elemen tanda tangan yang sama
            dengan yang mengelilingi tombol SOS di aplikasi pasien. */}
        <div className="mb-7 flex justify-center">
          <ReticleBracket size={22} className="h-[92px] w-[92px]">
            <div className="flex h-full w-full items-center justify-center">
              <div
                className="flex h-[60px] w-[60px] items-center justify-center rounded-[18px]"
                style={{
                  background: 'var(--vital-gradient)',
                  boxShadow: '0 12px 26px color-mix(in srgb, var(--vital) 30%, transparent)',
                }}
              >
                <svg
                  width="28"
                  height="28"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#04140C"
                  strokeWidth={2.3}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z" />
                </svg>
              </div>
            </div>
          </ReticleBracket>
        </div>

        <h1 className="text-center font-display text-[17px] font-extrabold text-[var(--text-primary)]">
          Dispatch Console
        </h1>
        <p className="mt-2 text-center font-mono text-[9px] uppercase tracking-[0.1em] text-[var(--text-secondary)]">
          Portal Rumah Sakit &amp; Admin Platform
        </p>

        <form onSubmit={onSubmit} className="card-surface mt-7 p-6">
          <label className="mono-label mb-2 block">Email / Nomor HP</label>
          <input
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
            autoComplete="username"
            placeholder="staff@rsudbogor.id"
            required
            className="mb-4 w-full rounded-xl border-[1.5px] border-[var(--border-strong)] bg-[var(--surface-2)] px-3.5 py-3 text-[11px] font-medium text-[var(--text-primary)] outline-none transition-colors placeholder:text-[var(--text-tertiary)] focus:border-[var(--vital)]"
          />

          <label className="mono-label mb-2 block">Kata Sandi</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            placeholder="••••••••"
            required
            className="w-full rounded-xl border-[1.5px] border-[var(--border-strong)] bg-[var(--surface-2)] px-3.5 py-3 text-[11px] font-medium text-[var(--text-primary)] outline-none transition-colors placeholder:text-[var(--text-tertiary)] focus:border-[var(--vital)]"
          />

          {error && (
            <div
              className="mt-4 rounded-xl px-3 py-2.5 text-[10px] font-semibold leading-relaxed"
              style={{
                background: 'var(--siren-tint)',
                border: '1px solid color-mix(in srgb, var(--siren-raw) 30%, transparent)',
                color: 'var(--siren)',
              }}
            >
              {error}
            </div>
          )}

          <button type="submit" disabled={busy} className="btn-vital mt-5 w-full py-3.5">
            {busy ? 'MEMPROSES...' : 'MASUK'}
          </button>

          <div className="my-4 flex items-center gap-2.5">
            <div className="h-px flex-1 bg-[var(--border-subtle)]" />
            <span className="font-mono text-[8px] font-bold tracking-[0.06em] text-[var(--text-tertiary)]">
              ATAU
            </span>
            <div className="h-px flex-1 bg-[var(--border-subtle)]" />
          </div>

          <Link
            href="/register-hospital"
            className="block text-center text-[10.5px] font-bold text-[var(--vital)] hover:underline"
          >
            Daftarkan rumah sakit baru
          </Link>
        </form>

        {/* Akun demo — memudahkan penguji & dosen mencoba tanpa bertanya dulu. */}
        <div className="mt-5 rounded-xl border border-[var(--border-subtle)] px-4 py-3">
          <div className="mono-label mb-2">Akun Demo · Sandi: password123</div>
          <div className="space-y-1 font-mono text-[9px] text-[var(--text-secondary)]">
            <div>staff@rsudbogor.id — Staff RSUD Kota Bogor</div>
            <div>staff@rspmibogor.id — Staff RS PMI Bogor</div>
            <div>admin@sigap.id — Admin platform</div>
          </div>
        </div>
      </div>
    </div>
  );
}
