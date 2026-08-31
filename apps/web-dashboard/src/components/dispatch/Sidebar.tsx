'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useTheme } from 'next-themes';
import { useEffect, useState } from 'react';
import { useAuth } from '@/components/AuthProvider';
import { cn } from '@/lib/utils';
import { Avatar } from './primitives';

/**
 * Sidebar kiri tetap — struktur sama untuk Portal RS dan Panel Admin.
 * Yang membedakan hanya WARNA AKSEN: hijau untuk RS, ungu untuk admin.
 * Itu keputusan desain yang disengaja (pembeda level akses), bukan tema acak.
 */

interface NavItem {
  href: string;
  label: string;
  icon: React.ReactNode;
}

const iconProps = {
  width: 14,
  height: 14,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 2.2,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
};

const IconHome = (
  <svg {...iconProps}>
    <path d="M3 10.5 12 3l9 7.5" />
    <path d="M5 9.5V21h14V9.5" />
  </svg>
);
const IconAmbulance = (
  <svg {...iconProps}>
    <path d="M8 19V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v13" />
    <path d="M2 19h20" />
  </svg>
);
const IconClock = (
  <svg {...iconProps}>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 7v5l3 3" />
  </svg>
);
const IconPin = (
  <svg {...iconProps}>
    <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" />
    <circle cx="12" cy="10" r="3" />
  </svg>
);

const HOSPITAL_NAV: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: IconHome },
  { href: '/drivers', label: 'Kelola Sopir', icon: IconAmbulance },
  { href: '/history', label: 'Riwayat SOS', icon: IconClock },
  { href: '/hospital', label: 'Profil RS', icon: IconPin },
];

const ADMIN_NAV: NavItem[] = [
  { href: '/admin/hospitals', label: 'Verifikasi RS', icon: IconPin },
  { href: '/admin/stats', label: 'Statistik Sistem', icon: IconHome },
];

export function Sidebar() {
  const { user, logout } = useAuth();
  const pathname = usePathname();
  const isAdmin = user?.role === 'admin';

  const nav = isAdmin ? ADMIN_NAV : HOSPITAL_NAV;
  const accent = isAdmin ? 'var(--admin-active)' : 'var(--vital)';
  const activeBg = isAdmin ? 'var(--admin-tint)' : 'var(--vital-tint)';
  const activeBorder = isAdmin ? 'var(--admin-border)' : 'var(--vital-border)';

  return (
    <aside className="flex w-[220px] flex-shrink-0 flex-col border-r border-[var(--border-subtle)] bg-[var(--sidebar)] px-4 py-5.5">
      {/* Brand */}
      <div className="mb-6 flex items-center gap-2.5">
        <div
          className="flex h-[34px] w-[34px] flex-shrink-0 items-center justify-center rounded-[10px]"
          style={{
            background: isAdmin
              ? 'linear-gradient(135deg,#9333EA,#6D28D9)'
              : 'var(--vital-gradient)',
          }}
        >
          {isAdmin ? (
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#fff"
              strokeWidth={2}
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M12 2 2 7l10 5 10-5-10-5Z" />
              <path d="M2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
          ) : (
            <svg
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="#04140C"
              strokeWidth={2.2}
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8Z" />
            </svg>
          )}
        </div>
        <div className="min-w-0">
          <div className="font-display text-[12.5px] font-bold text-[var(--text-primary)]">
            {isAdmin ? 'Admin Panel' : 'Portal RS'}
          </div>
          <div className="truncate font-mono text-[8px] uppercase tracking-[0.04em] text-[var(--text-secondary)]">
            {isAdmin ? 'Sigap · Platform Ambulans' : (user?.hospitalName ?? '—')}
          </div>
        </div>
      </div>

      {/* Navigasi */}
      <nav className="flex flex-col gap-[3px]">
        {nav.map((item) => {
          const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'flex items-center gap-2.5 rounded-[10px] px-3 py-2.5 text-[11.5px] font-semibold transition-colors',
                !active && 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]',
              )}
              style={
                active
                  ? {
                      background: activeBg,
                      color: accent,
                      border: `1px solid ${activeBorder}`,
                    }
                  : { border: '1px solid transparent' }
              }
            >
              {item.icon}
              {item.label}
            </Link>
          );
        })}
      </nav>

      <ThemeToggle />

      {/* Kaki sidebar — identitas pengguna */}
      <div className="mt-auto flex items-center gap-2.5 border-t border-[var(--border-subtle)] pt-3.5">
        <Avatar
          name={user?.fullName ?? '?'}
          size={32}
          tone={isAdmin ? 'admin' : 'vital'}
        />
        <div className="min-w-0 flex-1">
          <div className="truncate text-[10.5px] font-bold text-[var(--text-primary)]">
            {user?.fullName ?? '—'}
          </div>
          <div className="font-mono text-[7.5px] uppercase text-[var(--text-secondary)]">
            {isAdmin ? 'Super Admin' : 'Staff IGD'}
          </div>
        </div>
        <button
          type="button"
          onClick={() => void logout()}
          title="Keluar"
          className="flex h-7 w-7 items-center justify-center rounded-lg text-[var(--text-secondary)] transition-colors hover:text-[var(--siren)]"
        >
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={2.2}
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            <path d="M16 17l5-5-5-5" />
            <path d="M21 12H9" />
          </svg>
        </button>
      </div>
    </aside>
  );
}

/** Toggle gelap/terang. Gelap adalah default sistem desain ini. */
function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const isDark = resolvedTheme === 'dark';

  return (
    <button
      type="button"
      onClick={() => setTheme(isDark ? 'light' : 'dark')}
      className="mt-4 flex items-center gap-2.5 rounded-[10px] border border-[var(--border-subtle)] px-3 py-2.5 text-[11px] font-semibold text-[var(--text-secondary)] transition-colors hover:text-[var(--text-primary)]"
    >
      {/* Sebelum hydrate, tema sebenarnya belum diketahui — tampilkan ikon
          netral supaya tidak terjadi mismatch server/client. */}
      {mounted && isDark ? (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2.2}
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <circle cx="12" cy="12" r="4" />
          <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
        </svg>
      ) : (
        <svg
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2.2}
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
        </svg>
      )}
      {mounted ? (isDark ? 'Mode Terang' : 'Mode Gelap') : 'Tampilan'}
    </button>
  );
}
