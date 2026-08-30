import type { ReactNode } from 'react';
import { initials } from '@/lib/format';
import type { AvailabilityStatus, CallStatus } from '@/lib/types';
import { AVAILABILITY_LABEL, STATUS_LABEL } from '@/lib/types';
import { cn } from '@/lib/utils';

/**
 * Primitif sistem desain "Dispatch Console" untuk web.
 * Nilainya diambil langsung dari /design-reference/web-dashboard-*.html.
 */

// ---------------------------------------------------------------------------
// ELEMEN TANDA TANGAN #3 — readout mono
// ---------------------------------------------------------------------------

/**
 * Kartu statistik: label mono huruf kapital di atas, angka besar di bawah.
 * Inilah "readout" yang memberi kesan konsol operasional.
 */
export function StatCard({
  label,
  value,
  unit,
  sub,
  tone = 'default',
}: {
  label: string;
  value: ReactNode;
  unit?: string;
  sub?: string;
  tone?: 'default' | 'siren' | 'vital' | 'amber';
}) {
  const valueColor =
    tone === 'siren'
      ? 'var(--siren)'
      : tone === 'vital'
        ? 'var(--vital)'
        : tone === 'amber'
          ? 'var(--amber-text)'
          : 'var(--text-primary)';

  return (
    <div className="card-surface flex-1 px-4 py-3.5">
      <div className="mono-label">{label}</div>
      <div
        className="mt-1.5 font-display text-[22px] font-extrabold leading-none"
        style={{ color: valueColor }}
      >
        {value}
        {unit && <span className="text-[11px] font-bold"> {unit}</span>}
      </div>
      {sub && (
        <div
          className="mt-1 font-mono text-[8px] font-bold"
          style={{ color: tone === 'siren' ? 'var(--siren)' : 'var(--vital)' }}
        >
          {sub}
        </div>
      )}
    </div>
  );
}

/** Readout kecil: label mono + nilai mono. Dipakai di panel detail. */
export function Readout({
  label,
  value,
  tone = 'vital',
  className,
}: {
  label: string;
  value: ReactNode;
  tone?: 'vital' | 'siren' | 'plain';
  className?: string;
}) {
  return (
    <div className={cn('card-surface px-3 py-2.5', className)}>
      <div className="font-mono text-[7.5px] font-bold uppercase tracking-[0.08em] text-[var(--text-secondary)]">
        {label}
      </div>
      <div
        className="mt-1 font-mono text-[13px] font-bold"
        style={{
          color:
            tone === 'siren'
              ? 'var(--siren)'
              : tone === 'plain'
                ? 'var(--text-primary)'
                : 'var(--vital)',
        }}
      >
        {value}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Chip status
// ---------------------------------------------------------------------------

/** Merah HANYA untuk darurat/batal — aturan tegas sistem desain. */
const CALL_TONE: Record<CallStatus, { bg: string; fg: string }> = {
  pending: { bg: 'var(--siren-tint)', fg: 'var(--siren)' },
  confirmed: { bg: 'var(--vital-tint)', fg: 'var(--vital)' },
  en_route: { bg: 'var(--vital-tint)', fg: 'var(--vital)' },
  arrived: { bg: 'var(--vital-tint)', fg: 'var(--vital)' },
  completed: { bg: 'var(--vital-tint)', fg: 'var(--vital)' },
  cancelled: { bg: 'var(--siren-tint)', fg: 'var(--siren)' },
};

export function StatusChip({
  status,
  className,
  size = 'sm',
}: {
  status: CallStatus;
  className?: string;
  size?: 'sm' | 'md';
}) {
  const tone = CALL_TONE[status];
  return (
    <span
      className={cn(
        'inline-block whitespace-nowrap rounded-md font-mono font-bold uppercase tracking-[0.03em]',
        size === 'sm' ? 'px-2.5 py-1 text-[7.5px]' : 'px-3.5 py-1.5 text-[9px]',
        className,
      )}
      style={{ background: tone.bg, color: tone.fg }}
    >
      {STATUS_LABEL[status]}
    </span>
  );
}

const AVAIL_TONE: Record<AvailabilityStatus, { bg: string; fg: string }> = {
  available: { bg: 'var(--vital-tint)', fg: 'var(--vital)' },
  busy: { bg: 'var(--amber-tint)', fg: 'var(--amber-text)' },
  offline: { bg: 'var(--divider)', fg: 'var(--text-secondary)' },
};

export function AvailabilityChip({ status }: { status: AvailabilityStatus }) {
  const tone = AVAIL_TONE[status];
  return (
    <span
      className="inline-block rounded-md px-2.5 py-[3px] font-mono text-[8px] font-bold uppercase tracking-[0.03em]"
      style={{ background: tone.bg, color: tone.fg }}
    >
      {AVAILABILITY_LABEL[status]}
    </span>
  );
}

export function PendingBadge({ children = 'Pending' }: { children?: ReactNode }) {
  return (
    <span
      className="inline-block rounded-[7px] px-2.5 py-1 font-mono text-[8px] font-bold uppercase"
      style={{ background: 'var(--amber-tint)', color: 'var(--amber-text)' }}
    >
      {children}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

export function Avatar({
  name,
  size = 30,
  tone = 'vital',
  className,
}: {
  name: string;
  size?: number;
  tone?: 'vital' | 'admin';
  className?: string;
}) {
  const accent = tone === 'admin' ? 'var(--admin)' : 'var(--vital)';
  return (
    <span
      className={cn(
        'flex flex-shrink-0 items-center justify-center rounded-[9px] font-display font-bold',
        className,
      )}
      style={{
        width: size,
        height: size,
        fontSize: size * 0.3,
        color: accent,
        background: 'var(--surface-2)',
        border: `1.5px solid color-mix(in srgb, ${accent} 30%, transparent)`,
      }}
    >
      {initials(name)}
    </span>
  );
}

// ---------------------------------------------------------------------------
// Kepala halaman
// ---------------------------------------------------------------------------

export function TopBar({
  title,
  subtitle,
  actions,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
}) {
  return (
    <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 className="font-display text-base font-bold tracking-[-0.01em] text-[var(--text-primary)]">
          {title}
        </h1>
        {subtitle && <div className="mono-sub mt-1">{subtitle}</div>}
      </div>
      {actions && <div className="flex items-center gap-2.5">{actions}</div>}
    </div>
  );
}

/** Panel kosong dengan pesan — dipakai saat belum ada data. */
export function EmptyState({
  title,
  description,
  icon,
}: {
  title: string;
  description?: string;
  icon?: ReactNode;
}) {
  return (
    <div className="card-surface flex flex-col items-center justify-center px-6 py-14 text-center">
      {icon && (
        <div
          className="mb-3.5 flex h-16 w-16 items-center justify-center rounded-[20px]"
          style={{ background: 'var(--vital-tint)', border: '1px solid var(--vital-border)' }}
        >
          {icon}
        </div>
      )}
      <div className="font-display text-[12.5px] font-bold text-[var(--text-primary)]">
        {title}
      </div>
      {description && (
        <div className="mt-1.5 max-w-xs text-[10px] font-medium leading-relaxed text-[var(--text-secondary)]">
          {description}
        </div>
      )}
    </div>
  );
}

/** Titik hijau berdenyut — indikator "sistem aktif / realtime tersambung". */
export function LiveDot({ connected }: { connected: boolean }) {
  return (
    <span className="flex items-center gap-2">
      <span
        className={cn('h-1.5 w-1.5 rounded-full', connected && 'live-dot')}
        style={{
          background: connected ? 'var(--vital)' : 'var(--text-tertiary)',
          boxShadow: connected ? '0 0 8px var(--vital)' : undefined,
        }}
      />
      <span className="font-mono text-[8px] font-bold uppercase tracking-[0.1em] text-[var(--text-secondary)]">
        {connected ? 'Realtime Aktif' : 'Terputus'}
      </span>
    </span>
  );
}
