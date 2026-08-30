import type { CallStatus } from '@/lib/types';

/**
 * ELEMEN TANDA TANGAN #2 — pulse-line stepper.
 *
 * Alur status digambar sebagai garis EKG/heartbeat LITERAL, bukan stepper
 * titik-garis biasa. Path di bawah disalin persis dari design-reference
 * (viewBox 0 0 240 40) — jangan diganti motif lain, ini identitas visual
 * sistem desain "Dispatch Console".
 *
 * Catatan implementasi: garisnya digambar SVG dengan preserveAspectRatio="none"
 * supaya ikut melar mengisi lebar berapa pun. Tapi checkpoint-nya digambar
 * sebagai elemen HTML, BUKAN <circle> di dalam SVG yang sama — kalau ikut di
 * dalam SVG, peregangan sumbu X akan mengubah lingkaran jadi lonjong. Di mockup
 * ponsel efeknya tidak kelihatan karena lebarnya sempit; di dashboard yang jauh
 * lebih lebar, efeknya jelas terlihat.
 */
const EKG_PATH =
  'M0,20 L22,20 L30,4 L38,34 L46,20 L88,20 L96,4 L104,34 L112,20 L154,20 L162,4 L170,34 L178,20 L220,20 L228,4 L236,34 L244,20 L240,20';

/** Posisi x tiap puncak dalam satuan viewBox, diambil dari path di atas. */
const PEAKS = [34, 108, 174, 240];
const VIEW_W = 240;

const SVG_H = 34;
/** Puncak gelombang ada di y=4 dari total tinggi viewBox 40. */
const PEAK_TOP_PX = (4 / 40) * SVG_H;

export interface PulseStep {
  label: string;
  /** Status panggilan yang menandai langkah ini sudah tercapai. */
  reachedWhen: CallStatus[];
}

/** Empat langkah golden path yang dilihat pasien & staff RS. */
export const CALL_STEPS: PulseStep[] = [
  { label: 'DIKONFIRMASI', reachedWhen: ['confirmed', 'en_route', 'arrived', 'completed'] },
  { label: 'MENUJU', reachedWhen: ['en_route', 'arrived', 'completed'] },
  { label: 'TIBA', reachedWhen: ['arrived', 'completed'] },
  { label: 'SELESAI', reachedWhen: ['completed'] },
];

export function PulseStepper({
  status,
  steps = CALL_STEPS,
  className,
}: {
  status: CallStatus;
  steps?: PulseStep[];
  className?: string;
}) {
  // Berapa langkah yang sudah tercapai oleh status saat ini.
  const doneCount = steps.filter((s) => s.reachedWhen.includes(status)).length;
  // Langkah aktif = tepat setelah yang terakhir selesai (-1 kalau sudah tuntas).
  const activeIndex = doneCount < steps.length ? doneCount : -1;
  const cancelled = status === 'cancelled';

  return (
    <div className={className}>
      {/* Padding kiri-kanan memberi ruang untuk checkpoint pertama & terakhir
          supaya tidak terpotong tepi. */}
      <div className="relative px-1.5" style={{ height: SVG_H + 6 }}>
        <svg
          viewBox={`0 0 ${VIEW_W} 40`}
          width="100%"
          height={SVG_H}
          preserveAspectRatio="none"
          className="absolute inset-x-1.5 top-1.5 w-[calc(100%-0.75rem)]"
          aria-hidden
        >
          <path
            d={EKG_PATH}
            fill="none"
            stroke="var(--border-strong)"
            strokeWidth={2}
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        </svg>

        {steps.map((s, i) => {
          const done = i < doneCount;
          const active = i === activeIndex;
          const size = active ? 10 : 7;

          const background = cancelled
            ? 'var(--siren)'
            : done
              ? 'var(--vital)'
              : active
                ? 'var(--amber)'
                : 'var(--text-tertiary)';

          return (
            <span
              key={s.label}
              className="absolute rounded-full"
              style={{
                left: `calc(0.375rem + ${((PEAKS[i] ?? VIEW_W) / VIEW_W) * 100}% - ${((PEAKS[i] ?? VIEW_W) / VIEW_W) * 0.75}rem)`,
                top: 6 + PEAK_TOP_PX,
                width: size,
                height: size,
                background,
                transform: 'translate(-50%, -50%)',
                // Denyut halus pada langkah yang sedang berjalan.
                boxShadow: active ? `0 0 0 4px color-mix(in srgb, ${background} 22%, transparent)` : undefined,
              }}
            />
          );
        })}
      </div>

      <div className="flex justify-between">
        {steps.map((s, i) => {
          const done = i < doneCount;
          const active = i === activeIndex;
          return (
            <span
              key={s.label}
              className="font-mono text-[8px] font-bold uppercase tracking-wide"
              style={{
                color: done || active ? 'var(--text-primary)' : 'var(--text-tertiary)',
              }}
            >
              {s.label}
            </span>
          );
        })}
      </div>
    </div>
  );
}
