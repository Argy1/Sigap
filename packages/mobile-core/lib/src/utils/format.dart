import '../models/models.dart';

/// Pemformatan angka & waktu.
///
/// Semua angka ditampilkan dengan JetBrains Mono — itulah yang memberi kesan
/// "readout konsol". Fungsi di sini menjaga bentuknya konsisten di kedua app.

/// 1240 -> "1.2 KM" · 850 -> "850 M"
String formatDistance(int? meters) {
  if (meters == null) return '—';
  if (meters < 1000) return '$meters M';
  return '${(meters / 1000).toStringAsFixed(1)} KM';
}

/// 420 -> "7 MNT"
String formatDuration(int? seconds) {
  if (seconds == null) return '—';
  final minutes = (seconds / 60).round().clamp(1, 1 << 30);
  if (minutes < 60) return '$minutes MNT';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h JAM' : '$h JAM $m MNT';
}

/// Versi panjang untuk readout hero: 420 -> "7 MENIT"
String formatDurationLong(int? seconds) {
  if (seconds == null) return '—';
  final minutes = (seconds / 60).round().clamp(1, 1 << 30);
  return '$minutes MENIT';
}

/// "BARU SAJA" · "2 MNT LALU" · "3 JAM LALU"
String formatRelative(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'BARU SAJA';
  if (diff.inMinutes < 60) return '${diff.inMinutes} MNT LALU';
  if (diff.inHours < 24) return '${diff.inHours} JAM LALU';
  return '${diff.inDays} HARI LALU';
}

/// "12.08.2026 · 14:20" — format tanggal di layar Riwayat.
String formatDateTime(DateTime t) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(t.day)}.${p(t.month)}.${t.year} · ${p(t.hour)}:${p(t.minute)}';
}

/// Inisial avatar: "Ahmad Ridwan" -> "AR"
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Koordinat gaya konsol: "-6.5971, 106.8060"
String formatCoords(LatLngPoint p) =>
    '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}';

/// Selisih dua waktu dalam menit — dipakai statistik waktu respons.
int? minutesBetween(DateTime? a, DateTime? b) {
  if (a == null || b == null) return null;
  return b.difference(a).inMinutes;
}
