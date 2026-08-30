import 'dart:io';

/// Alamat backend yang dipakai uji integrasi.
const String kBackend = 'http://localhost:4000';

/// Diisi oleh `flutter_test_config.dart` SEBELUM berkas uji dikumpulkan.
///
/// Ini penting: flag `skip:` pada `group()` dievaluasi saat uji DIDAFTARKAN,
/// bukan saat dijalankan. Memeriksanya di `setUpAll` sudah terlambat — seluruh
/// grup terlanjur ditandai dilewati. Hook `testExecutable` adalah satu-satunya
/// tempat yang dijamin berjalan lebih dulu.
bool backendAvailable = false;

/// Kembalikan akses jaringan sungguhan di dalam `flutter test`.
///
/// TestWidgetsFlutterBinding memasang HttpOverrides yang MEMBLOKIR semua
/// request keluar (setiap request dijawab 400). Itu perilaku yang benar untuk
/// uji unit — tapi uji integrasi ini justru bertujuan menembak backend asli,
/// jadi override-nya harus dilepas lebih dulu.
void allowRealNetwork() => HttpOverrides.global = null;

Future<bool> probeBackend() async {
  allowRealNetwork();
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final req = await client.getUrl(Uri.parse('$kBackend/health'));
    final res = await req.close();
    await res.drain<void>();
    client.close();
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}
