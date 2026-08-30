import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Muat font asli sebelum uji golden dijalankan.
///
/// Tanpa ini, `flutter test` merender semua teks sebagai kotak hitam (font
/// "Ahem"), sehingga golden-nya tidak membuktikan apa pun tentang tipografi —
/// padahal tipografi justru salah satu hal utama yang harus direplikasi dari
/// design reference.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  await _loadFont('Unbounded', 'assets/fonts/Unbounded-Variable.ttf');
  await _loadFont('Inter', 'assets/fonts/Inter-Variable.ttf');
  await _loadFont('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf');

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
