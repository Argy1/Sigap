'use client';

import { useEffect, useState } from 'react';
import { ReticleBracket } from './ReticleBracket';

/**
 * Layar boot — muncul sekali per sesi tab sebelum konten pertama dashboard,
 * memakai motif "konsol menyala" yang sama dengan kedua app Flutter (lihat
 * `packages/mobile-core/lib/src/widgets/boot_intro.dart`): reticle mengunci,
 * baris HUD mono berjalan, garis EKG (elemen tanda tangan yang sama dengan
 * `PulseStepper`) menggambar dirinya sendiri, lalu wordmark.
 *
 * Sengaja HANYA render di client dan HANYA setelah mount (bukan langsung di
 * initial state) — menghindari flash/hydration mismatch, dan supaya gerbang
 * sessionStorage-nya (satu kali per tab) tidak pernah ikut ke server render.
 */
const SESSION_KEY = 'sigap.bootIntroShown';

const BOOT_LINES = [
  'MENGHUBUNGKAN KE SERVER...',
  'MEMUAT DATA RUMAH SAKIT...',
  'KONSOL SIAP',
];

export function BootIntro() {
  const [visible, setVisible] = useState(false);
  const [closing, setClosing] = useState(false);

  // Gerbang sesi terpisah dari efek penjadwal timer di bawah — sengaja,
  // supaya double-invoke React Strict Mode di dev (mount→cleanup→mount) tidak
  // membuat efek ini `return` dini pada invoke kedua (sessionStorage sudah
  // terisi dari invoke pertama) sekaligus membatalkan jadwal auto-tutupnya.
  useEffect(() => {
    try {
      if (sessionStorage.getItem(SESSION_KEY)) return;
      sessionStorage.setItem(SESSION_KEY, '1');
    } catch {
      // Private mode / storage diblokir — tetap tampilkan intro, cuma tidak
      // "diingat" antar-halaman dalam sesi yang sama. Bukan kegagalan fatal.
    }
    setVisible(true);
  }, []);

  useEffect(() => {
    if (!visible) return;
    const finish = setTimeout(() => setClosing(true), 2000);
    return () => clearTimeout(finish);
  }, [visible]);

  useEffect(() => {
    if (!closing) return;
    const remove = setTimeout(() => setVisible(false), 260);
    return () => clearTimeout(remove);
  }, [closing]);

  if (!visible) return null;

  return (
    <div
      role="presentation"
      onClick={() => setClosing(true)}
      className="console-surface fixed inset-0 z-[999] flex cursor-pointer flex-col items-center justify-center bg-[var(--paper)] transition-opacity duration-[260ms] ease-out"
      style={{
        opacity: closing ? 0 : 1,
        backgroundImage:
          'radial-gradient(ellipse 110% 90% at 20% -10%, color-mix(in srgb, var(--vital) 9%, transparent), transparent 55%),' +
          'radial-gradient(ellipse 90% 80% at 110% -5%, color-mix(in srgb, var(--siren-raw) 7%, transparent), transparent 55%)',
      }}
    >
      <ReticleBracket size={22} className="boot-reticle-in h-[112px] w-[112px]">
        <div className="flex h-full w-full items-center justify-center">
          <div
            className="boot-icon-in flex h-[62px] w-[62px] items-center justify-center rounded-[18px]"
            style={{
              background: 'var(--vital-gradient)',
              boxShadow: '0 14px 28px color-mix(in srgb, var(--vital) 32%, transparent)',
            }}
          >
            <svg
              width="30"
              height="30"
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

      <div className="mt-6 flex flex-col items-center">
        {BOOT_LINES.map((line, i) => (
          <p
            key={line}
            className="boot-line mb-[5px] font-mono text-[10px] font-semibold tracking-[0.06em] text-[var(--text-secondary)]"
            style={{ animationDelay: `${260 + i * 260}ms` }}
          >
            {line}
          </p>
        ))}
      </div>

      <svg
        className="boot-pulse mt-5"
        width="240"
        height="34"
        viewBox="0 0 240 40"
        fill="none"
      >
        <path
          d="M0,20 L22,20 L30,4 L38,34 L46,20 L88,20 L96,4 L104,34 L112,20 L154,20 L162,4 L170,34 L178,20 L220,20 L228,4 L236,34 L244,20 L240,20"
          stroke="var(--vital)"
          strokeWidth={2.4}
          strokeLinejoin="round"
          strokeLinecap="round"
          pathLength={1}
        />
      </svg>

      <div className="boot-wordmark-in mt-5 flex flex-col items-center">
        <h1 className="font-display text-[22px] font-extrabold tracking-[0.01em] text-[var(--text-primary)]">
          Dispatch Console
        </h1>
        <p className="mt-1.5 font-mono text-[9px] uppercase tracking-[0.18em] text-[var(--text-secondary)]">
          Sigap — Platform Ambulans Kota Bogor
        </p>
      </div>

      <p className="boot-wordmark-in absolute bottom-6 font-mono text-[8px] uppercase tracking-[0.14em] text-[var(--text-tertiary)]">
        Klik untuk lewati
      </p>
    </div>
  );
}
