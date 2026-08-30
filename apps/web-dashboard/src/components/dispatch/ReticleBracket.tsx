import { cn } from '@/lib/utils';

/**
 * ELEMEN TANDA TANGAN #1 — bracket reticle.
 *
 * Empat siku seperti bracket fokus kamera, mewakili "penguncian lokasi GPS".
 * Di mockup ini mengelilingi tombol SOS dan titik lokasi pengguna.
 *
 * Ukuran dari design-reference: siku 24x24px, border 2px, radius sudut luar 8px.
 */
export function ReticleBracket({
  children,
  size = 24,
  thickness = 2,
  color = 'var(--vital)',
  opacity = 0.5,
  className,
  inset = 0,
}: {
  children?: React.ReactNode;
  size?: number;
  thickness?: number;
  color?: string;
  opacity?: number;
  className?: string;
  inset?: number;
}) {
  const common: React.CSSProperties = {
    position: 'absolute',
    width: size,
    height: size,
    borderColor: color,
    opacity,
    pointerEvents: 'none',
  };
  const b = `${thickness}px solid`;
  const r = size / 3;

  return (
    <div className={cn('relative', className)}>
      <span
        style={{ ...common, top: inset, left: inset, borderTop: b, borderLeft: b, borderRadius: `${r}px 0 0 0` }}
      />
      <span
        style={{ ...common, top: inset, right: inset, borderTop: b, borderRight: b, borderRadius: `0 ${r}px 0 0` }}
      />
      <span
        style={{ ...common, bottom: inset, left: inset, borderBottom: b, borderLeft: b, borderRadius: `0 0 0 ${r}px` }}
      />
      <span
        style={{ ...common, bottom: inset, right: inset, borderBottom: b, borderRight: b, borderRadius: `0 0 ${r}px 0` }}
      />
      {children}
    </div>
  );
}
