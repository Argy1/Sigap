import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifikasi lokal — muncul selama aplikasi masih hidup di perangkat
/// (sedang dibuka ATAU di-*background*), BUKAN push yang tetap masuk saat
/// aplikasi di-*force-close* total. Itu butuh infrastruktur terpisah (Firebase
/// Cloud Messaging + endpoint kirim push di backend) yang sengaja tidak
/// dibangun di sini — di luar cakupan revisi ini.
///
/// Satu instance dipakai bersama App Pasien & App Sopir lewat
/// [notificationServiceProvider]. Setiap app memberi `channelId`/`channelName`
/// sendiri saat [init] supaya keduanya tidak berbagi channel Android yang sama
/// (kalau berbagi, mematikan notifikasi di satu app lewat pengaturan sistem
/// bisa ikut mematikan yang satunya).
class NotificationService {
  NotificationService({required this.channelId, required this.channelName});

  /// Id channel Android — mis. `sigap_patient_channel`.
  final String channelId;

  /// Nama channel yang terlihat pengguna di Pengaturan > Notifikasi > Sigap.
  final String channelName;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Panggil sekali saat app start (lihat `main.dart` tiap app).
  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );

    // Channel dibuat sekali di awal — importance tinggi karena ini konteks
    // darurat (status SOS / tugas baru), bukan notifikasi biasa yang boleh
    // ditunda sistem.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Notifikasi status darurat dari Sigap',
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  /// True kalau izin notifikasi (Android 13+/SDK 33+) sudah diberikan.
  ///
  /// Di Android <13 selalu true (izin runtime baru wajib mulai API 33), dan
  /// plugin ini mengembalikan `null` di platform lain — diperlakukan sebagai
  /// "diizinkan" (mis. sedang dijalankan bukan di Android).
  Future<bool> hasPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.areNotificationsEnabled() ?? true;
  }

  /// Minta izin notifikasi. Dipanggil LAZILY (saat user menyalakan toggle
  /// master atau menekan "Tes Notifikasi"), bukan saat app pertama dibuka —
  /// mengagetkan user dengan dialog izin di layar pertama adalah pengalaman
  /// yang buruk dan sering berujung ditolak refleks.
  Future<bool> requestPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    return await androidPlugin.requestNotificationsPermission() ?? false;
  }

  /// Tampilkan satu notifikasi. Pemanggil (provider tiap app) yang
  /// bertanggung jawab mengecek toggle master + kategori sebelum memanggil
  /// ini — service ini sendiri tidak tahu apa-apa soal preferensi pengguna.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (e) {
      // Notifikasi gagal tampil TIDAK boleh mengganggu alur SOS/tugas yang
      // sebenarnya — cukup dicatat di log debug.
      debugPrint('[notification] gagal menampilkan: $e');
    }
  }
}

/// Default generik — SETIAP app WAJIB meng-override ini di `main.dart` lewat
/// `ProviderScope(overrides: [notificationServiceProvider.overrideWithValue(
/// NotificationService(channelId: 'sigap_patient_channel', ...))])` supaya
/// App Pasien dan App Sopir punya channel Android yang benar-benar terpisah.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    channelId: 'sigap_default_channel',
    channelName: 'Sigap',
  ),
);
