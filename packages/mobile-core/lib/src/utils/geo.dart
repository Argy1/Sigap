import 'dart:math' as math;

import '../models/models.dart';

/// Perhitungan geospasial sisi klien.
///
/// Kenapa dihitung di klien, bukan minta ke server: posisi sopir masuk tiap
/// beberapa detik lewat socket. Menembak REST tiap kali hanya untuk satu angka
/// jarak akan membebani jaringan justru saat paling sibuk — dan menampilkan
/// angka yang tertinggal beberapa detik di layar live tracking terasa rusak.

const double _earthRadiusM = 6371000;

double _toRad(double deg) => deg * math.pi / 180;

/// Jarak garis lurus antara dua titik, dalam meter.
double haversineMeters(LatLngPoint a, LatLngPoint b) {
  final dLat = _toRad(b.lat - a.lat);
  final dLng = _toRad(b.lng - a.lng);
  final lat1 = _toRad(a.lat);
  final lat2 = _toRad(b.lat);

  final h = math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLng / 2), 2) * math.cos(lat1) * math.cos(lat2);
  return 2 * _earthRadiusM * math.asin(math.sqrt(h.toDouble()));
}

/// Rasio jarak jalan terhadap garis lurus untuk kota padat seperti Bogor.
/// Nilainya harus sama dengan ROAD_DETOUR_FACTOR di backend
/// (`routing.service.ts`) supaya estimasi klien dan server tidak berbeda.
const double kRoadDetourFactor = 1.35;

/// Kecepatan rata-rata ambulans di jalan kota (km/jam).
const double kAvgSpeedKmh = 32;

/// Perkiraan ETA (detik) dari jarak garis lurus.
///
/// Ini perkiraan yang SAMA dengan fallback backend. Kalau Google Maps aktif,
/// server mengirim angka yang lebih akurat — pakai angka itu kalau tersedia.
int estimateEtaSeconds(double straightMeters) {
  final roadMeters = straightMeters * kRoadDetourFactor;
  return (roadMeters / 1000 / kAvgSpeedKmh * 3600).round();
}
