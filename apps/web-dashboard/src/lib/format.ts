/**
 * Pemformatan angka & waktu.
 *
 * Semua angka di UI ditampilkan dengan JetBrains Mono — itulah yang memberi
 * kesan "readout konsol" di sistem desain ini. Fungsi di sini memastikan
 * bentuk angkanya konsisten di seluruh halaman.
 */

/** 1240 -> "1.2 KM", 850 -> "850 M" */
export function formatDistance(meters: number | null | undefined): string {
  if (meters === null || meters === undefined) return '—';
  if (meters < 1000) return `${Math.round(meters)} M`;
  return `${(meters / 1000).toFixed(1)} KM`;
}

/** 420 -> "7 MNT" */
export function formatDuration(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined) return '—';
  const minutes = Math.max(1, Math.round(seconds / 60));
  if (minutes < 60) return `${minutes} MNT`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h} JAM` : `${h} JAM ${m} MNT`;
}

/** "BARU SAJA", "2 MNT LALU", "3 JAM LALU" — sesuai kartu SOS di mockup. */
export function formatRelative(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60_000);
  if (minutes < 1) return 'BARU SAJA';
  if (minutes < 60) return `${minutes} MNT LALU`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} JAM LALU`;
  const days = Math.floor(hours / 24);
  return `${days} HARI LALU`;
}

/** "12.08.2026 · 14:20" — format tanggal di layar Riwayat. */
export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} · ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** Inisial untuk avatar: "Ahmad Ridwan" -> "AR" */
export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0]!.slice(0, 2).toUpperCase();
  return (parts[0]![0]! + parts[parts.length - 1]![0]!).toUpperCase();
}

/** Koordinat gaya konsol: "-6.5971, 106.8060" */
export const formatCoords = (lat: number, lng: number) =>
  `${lat.toFixed(4)}, ${lng.toFixed(4)}`;

/** Selisih dua timestamp dalam menit — dipakai statistik waktu respons. */
export function minutesBetween(a: string | null, b: string | null): number | null {
  if (!a || !b) return null;
  return Math.round((new Date(b).getTime() - new Date(a).getTime()) / 60_000);
}
