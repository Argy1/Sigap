import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Buka aplikasi telepon dengan nomor sudah terisi (dialer, bukan panggilan
/// otomatis) — dipakai di tombol "Telepon RS" (App Pasien), "Telepon Sopir"
/// (layar SOS Aktif), dan "Telepon Pasien" (App Sopir).
///
/// Sengaja TIDAK butuh izin `CALL_PHONE`: `tel:` hanya membuka dialer dengan
/// nomor terisi, pengguna masih harus menekan tombol panggil sendiri.
///
/// Satu fungsi dipakai di tiga tempat berbeda supaya pesan errornya
/// konsisten, bukan diketik ulang tiap layar.
Future<void> callPhoneNumber(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  final ok = await launchUrl(uri);

  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tidak bisa membuka aplikasi telepon ke $phone')),
    );
  }
}
