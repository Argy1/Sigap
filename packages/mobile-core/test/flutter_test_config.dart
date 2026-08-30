import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_probe.dart';

/// Persiapan yang dijalankan SEBELUM berkas uji mana pun dikumpulkan.
///
/// Dua hal disiapkan di sini:
///
/// 1. **Font asli dimuat.** Tanpa ini `flutter test` merender semua teks
///    sebagai kotak hitam (font "Ahem"), sehingga golden-nya tidak membuktikan
///    apa pun tentang tipografi — padahal tipografi justru salah satu hal utama
///    yang harus direplikasi dari design reference.
///
/// 2. **Ketersediaan backend diperiksa.** Harus di sini, bukan di `setUpAll`:
///    flag `skip:` pada `group()` dievaluasi saat uji DIDAFTARKAN, jadi
///    memeriksanya di setUpAll sudah terlambat.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFont('Unbounded', 'assets/fonts/Unbounded-Variable.ttf');
  await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
  await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf');

  backendAvailable = await probeBackend();
  if (!backendAvailable) {
    // ignore: avoid_print
    print(
      '\n[integrasi] Backend tidak berjalan di $kBackend. '
      'Uji integrasi API dilewati; jalankan `cd backend && npm run dev` '
      'untuk mengaktifkannya.\n',
    );
  }

  await testMain();
}

Future<void> _loadFont(String family, String path) async {
  // Nama family harus diawali "packages/mobile_core/" karena widget merujuk
  // font lewat parameter `package:` di TextStyle.
  final loader = FontLoader('packages/mobile_core/$family')
    ..addFont(
      File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  await loader.load();
}
