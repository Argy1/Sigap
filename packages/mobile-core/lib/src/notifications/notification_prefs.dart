import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi notifikasi pengguna: satu toggle master + toggle per kategori.
///
/// Modelnya sengaja LONGGAR (`Map<String, bool>` berkunci string bebas),
/// bukan enum tertutup — App Pasien dan App Sopir punya kategori yang sama
/// sekali berbeda (status panggilan vs tugas masuk), dan keduanya berbagi
/// package ini. Kalau dipaksa satu enum, salah satu app akan punya nilai
/// yang tidak relevan untuknya.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    required this.masterEnabled,
    required this.categories,
  });

  final bool masterEnabled;
  final Map<String, bool> categories;

  /// Kategori dianggap aktif kalau master menyala DAN kategorinya sendiri
  /// menyala (atau belum pernah diset — default-nya aktif, supaya kategori
  /// baru yang ditambahkan nanti langsung berguna tanpa perlu user
  /// menyalakannya manual satu per satu).
  bool isCategoryEnabled(String categoryId) =>
      masterEnabled && (categories[categoryId] ?? true);

  NotificationPrefs copyWith({
    bool? masterEnabled,
    Map<String, bool>? categories,
  }) =>
      NotificationPrefs(
        masterEnabled: masterEnabled ?? this.masterEnabled,
        categories: categories ?? this.categories,
      );
}

/// Provider `NotificationPrefsNotifier` per app — masing-masing app
/// menyediakan instance sendiri lewat `ProviderScope(overrides: [...])` di
/// `main.dart`, dengan `storagePrefix` berbeda supaya toggle Pasien dan Sopir
/// tidak pernah bentrok kalau suatu saat berjalan di perangkat yang sama.
class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  NotificationPrefsNotifier(this.storagePrefix);

  final String storagePrefix;

  String get _masterKey => '$storagePrefix.notif.master';
  String get _categoryKeyPrefix => '$storagePrefix.notif.category.';

  @override
  NotificationPrefs build() {
    // Default aman: semua menyala. Nilai sungguhan dimuat async segera
    // setelah provider pertama dibaca — pola yang sama seperti
    // `AuthNotifier.restore()` di core_providers.dart.
    Future.microtask(_restore);
    return const NotificationPrefs(masterEnabled: true, categories: {});
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final master = prefs.getBool(_masterKey) ?? true;

    final categories = <String, bool>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_categoryKeyPrefix)) {
        final id = key.substring(_categoryKeyPrefix.length);
        categories[id] = prefs.getBool(key) ?? true;
      }
    }

    state = NotificationPrefs(masterEnabled: master, categories: categories);
  }

  Future<void> setMasterEnabled(bool value) async {
    state = state.copyWith(masterEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_masterKey, value);
  }

  Future<void> setCategoryEnabled(String categoryId, bool value) async {
    state = state.copyWith(
      categories: {...state.categories, categoryId: value},
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_categoryKeyPrefix$categoryId', value);
  }
}

/// Deskripsi satu kategori notifikasi — dipakai untuk merender daftar toggle
/// di halaman Pengaturan Notifikasi. Didefinisikan per app (lihat
/// `patient_providers.dart` / `driver_providers.dart`), bukan di sini, karena
/// kategorinya memang spesifik per app.
@immutable
class NotificationCategory {
  const NotificationCategory({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

/// Default generik (`storagePrefix: 'app'`) — SETIAP app WAJIB meng-override
/// ini di `main.dart` lewat `ProviderScope(overrides: [notificationPrefsProvider
/// .overrideWith(() => NotificationPrefsNotifier('patient'))])` (atau
/// `'driver'`) supaya toggle Pasien dan Sopir tersimpan di kunci
/// SharedPreferences yang berbeda.
final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  () => NotificationPrefsNotifier('app'),
);
