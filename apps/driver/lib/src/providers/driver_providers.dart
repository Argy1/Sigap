import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_core/mobile_core.dart';

/// Provider khusus App Sopir.

// ---------------------------------------------------------------------------
// Notifikasi — kategori khusus App Sopir
// ---------------------------------------------------------------------------

/// Id kategori dipakai sebagai kunci di [NotificationPrefs.categories] DAN
/// sebagai id notifikasi Android (lewat `.hashCode`) — nilainya harus stabil,
/// jangan diubah begitu sudah dipakai.
const String kNotifCategoryNewTask = 'driver_new_task';
const String kNotifCategoryTaskCancelled = 'driver_task_cancelled';

/// Daftar kategori yang dirender di `NotificationSettingsScreen`.
const List<NotificationCategory> driverNotificationCategories = [
  NotificationCategory(
    id: kNotifCategoryNewTask,
    label: 'Tugas Baru Masuk',
    description: 'Saat rumah sakit menugaskan Anda ke sebuah panggilan.',
  ),
  NotificationCategory(
    id: kNotifCategoryTaskCancelled,
    label: 'Tugas Dibatalkan/Dialihkan',
    description: 'Saat panggilan yang Anda tangani dibatalkan atau dialihkan.',
  ),
];

/// Profil sopir yang sedang masuk (plat, status ketersediaan, RS).
final driverProfileProvider = FutureProvider<DriverProfile>(
  (ref) => ref.watch(apiClientProvider).myDriverProfile(),
);

/// Riwayat penjemputan sopir ini.
final driverHistoryProvider = FutureProvider<List<EmergencyCall>>(
  (ref) => ref.watch(apiClientProvider).listCalls(),
);

/// Tab yang sedang aktif (Beranda / Riwayat / Akun).
final driverTabProvider =
    NotifierProvider<DriverTabNotifier, int>(DriverTabNotifier.new);

class DriverTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

// ---------------------------------------------------------------------------
// Tugas aktif
// ---------------------------------------------------------------------------

/// Tugas yang sedang dipegang sopir ini.
///
/// Menyatukan tiga sumber: pemuatan awal lewat REST, event `assignment:new`
/// (tugas baru masuk), dan `sos:updated` (mis. pasien membatalkan saat sopir
/// sudah di jalan — sopir harus tahu SEGERA, bukan setelah tiba di lokasi).
final currentAssignmentProvider =
    NotifierProvider<CurrentAssignmentNotifier, EmergencyCall?>(
  CurrentAssignmentNotifier.new,
);

class CurrentAssignmentNotifier extends Notifier<EmergencyCall?> {
  StreamSubscription<EmergencyCall>? _assignmentSub;
  StreamSubscription<EmergencyCall>? _updateSub;
  StreamSubscription<String>? _cancelSub;

  @override
  EmergencyCall? build() {
    final socket = ref.watch(socketServiceProvider);

    _assignmentSub = socket.assignments.listen((call) {
      state = call;
      // Langsung ikut memantau room panggilan ini. Sopir sengaja TIDAK di-join
      // ke room rumah sakit (itu akan membocorkan seluruh SOS milik RS), jadi
      // room panggilan inilah satu-satunya jalur dia menerima perubahan status
      // — termasuk kalau pasien membatalkan saat dia masih menimbang.
      socket.watchCall(call.id);
      _notifyIfEnabled(
        kNotifCategoryNewTask,
        title: 'Tugas Baru Masuk',
        body: 'SOS #${call.callCode} — ${call.patientName}. '
            'Buka aplikasi untuk menerima atau menolak.',
      );
    });

    _updateSub = socket.callUpdates.listen((call) {
      if (state != null && call.id == state!.id) {
        // Panggilan yang sudah tuntas tidak lagi jadi "tugas aktif".
        state = call.status.isActive ? call : null;
        if (!call.status.isActive) {
          ref.invalidate(driverProfileProvider);
          ref.invalidate(driverHistoryProvider);
        }
      }
    });

    _cancelSub = socket.assignmentCancelled.listen((callId) {
      if (state?.id == callId) {
        final cancelledCode = state!.callCode;
        state = null;
        ref.invalidate(driverProfileProvider);
        _notifyIfEnabled(
          kNotifCategoryTaskCancelled,
          title: 'Tugas Dibatalkan',
          body: 'SOS #$cancelledCode tidak lagi menjadi tugas Anda.',
        );
      }
    });

    ref.onDispose(() {
      _assignmentSub?.cancel();
      _updateSub?.cancel();
      _cancelSub?.cancel();
    });

    Future.microtask(restore);
    return null;
  }

  /// Notifikasi lokal — muncul selama app masih hidup (foreground atau
  /// background), TIDAK sampai app di-*force-close* total. Cek preferensi
  /// kategori dulu; kalau nonaktif, tidak ada apa pun yang terjadi.
  void _notifyIfEnabled(
    String categoryId, {
    required String title,
    required String body,
  }) {
    final prefs = ref.read(notificationPrefsProvider);
    if (!prefs.isCategoryEnabled(categoryId)) return;

    // Id notifikasi tetap per kategori supaya notifikasi baru MENGGANTI yang
    // lama, bukan menumpuk.
    ref.read(notificationServiceProvider).show(
          id: categoryId.hashCode,
          title: title,
          body: body,
        );
  }

  /// Muat tugas yang mungkin sedang berjalan — penting kalau aplikasi sopir
  /// sempat tertutup di tengah penjemputan.
  Future<void> restore() async {
    try {
      final calls =
          await ref.read(apiClientProvider).listCalls(activeOnly: true);
      final mine = calls.where((c) => c.status.isActive).toList();
      if (mine.isNotEmpty) {
        state = mine.first;
        ref.read(socketServiceProvider).watchCall(mine.first.id);
      }
    } catch (_) {
      // Pemulihan opsional — jangan sampai kegagalannya memblokir aplikasi.
    }
  }

  Future<void> accept() async {
    final call = state;
    if (call == null) return;
    // Menerima tugas = mulai berangkat.
    final updated = await ref
        .read(apiClientProvider)
        .changeCallStatus(call.id, CallStatus.enRoute);
    state = updated;
    ref.read(socketServiceProvider).watchCall(call.id);
  }

  Future<void> reject() async {
    final call = state;
    if (call == null) return;
    await ref.read(apiClientProvider).rejectAssignment(call.id);
    state = null;
    ref.invalidate(driverProfileProvider);
  }

  Future<void> markArrived() async {
    final call = state;
    if (call == null) return;
    state = await ref
        .read(apiClientProvider)
        .changeCallStatus(call.id, CallStatus.arrived);
  }

  Future<void> complete() async {
    final call = state;
    if (call == null) return;
    await ref
        .read(apiClientProvider)
        .changeCallStatus(call.id, CallStatus.completed);
    state = null;
    ref.invalidate(driverProfileProvider);
    ref.invalidate(driverHistoryProvider);
  }
}

// ---------------------------------------------------------------------------
// Penyiaran lokasi
// ---------------------------------------------------------------------------

/// Mengirim posisi sopir secara berkala selama ada tugas aktif.
///
/// Inilah yang membuat live tracking di App Pasien benar-benar hidup.
///
/// Dua keputusan penting:
/// 1. Hanya menyala saat ada tugas aktif. Menyiarkan posisi sopir sepanjang
///    hari boros baterai dan tidak ada yang membutuhkannya.
/// 2. Dikirim lewat socket, bukan REST. Pada interval 5 detik, membuka
///    koneksi HTTP baru tiap kali membebani jaringan justru saat paling sibuk.
final locationBroadcastProvider =
    NotifierProvider<LocationBroadcastNotifier, bool>(
  LocationBroadcastNotifier.new,
);

class LocationBroadcastNotifier extends Notifier<bool> {
  StreamSubscription<Position>? _positionSub;

  @override
  bool build() {
    final assignment = ref.watch(currentAssignmentProvider);
    final hasActiveTask = assignment != null && assignment.status.isActive;

    ref.onDispose(() {
      _positionSub?.cancel();
      _positionSub = null;
    });

    if (hasActiveTask) {
      Future.microtask(_start);
      return true;
    }

    Future.microtask(_stop);
    return false;
  }

  Future<void> _start() async {
    if (_positionSub != null) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final socket = ref.read(socketServiceProvider);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // Kirim ulang setelah bergerak 10 m — cukup halus untuk terlihat
        // bergerak di peta, tanpa membanjiri socket saat berhenti di lampu
        // merah.
        distanceFilter: 10,
      ),
    ).listen((pos) {
      socket.pushLocation(LatLngPoint(pos.latitude, pos.longitude));
    });
  }

  void _stop() {
    _positionSub?.cancel();
    _positionSub = null;
  }
}
