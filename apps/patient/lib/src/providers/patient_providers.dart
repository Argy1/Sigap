import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

/// Provider khusus App Pasien.

// ---------------------------------------------------------------------------
// Notifikasi — kategori khusus App Pasien
// ---------------------------------------------------------------------------

/// Id kategori dipakai sebagai kunci di [NotificationPrefs.categories] DAN
/// sebagai id notifikasi Android (lewat `.hashCode`) — nilainya harus stabil,
/// jangan diubah begitu sudah dipakai (nanti preferensi lama yang tersimpan
/// jadi tidak nyambung dengan kategori baru).
const String kNotifCategoryAssigned = 'patient_assigned';
const String kNotifCategoryArrived = 'patient_arrived';
const String kNotifCategoryFinished = 'patient_finished';

/// Daftar kategori yang dirender di `NotificationSettingsScreen`.
const List<NotificationCategory> patientNotificationCategories = [
  NotificationCategory(
    id: kNotifCategoryAssigned,
    label: 'Sopir Ditugaskan / Menuju Lokasi',
    description: 'Saat rumah sakit menugaskan sopir dan saat sopir berangkat.',
  ),
  NotificationCategory(
    id: kNotifCategoryArrived,
    label: 'Ambulans Tiba di Lokasi',
    description: 'Saat sopir mengonfirmasi sudah sampai di lokasi Anda.',
  ),
  NotificationCategory(
    id: kNotifCategoryFinished,
    label: 'Panggilan Selesai / Dibatalkan',
    description: 'Saat penjemputan selesai atau panggilan dibatalkan.',
  ),
];

// ---------------------------------------------------------------------------
// RS terdekat
// ---------------------------------------------------------------------------

/// Daftar RS terdekat dari posisi pengguna saat ini.
///
/// Bergantung pada [locationProvider]: begitu lokasi berubah, daftar ini
/// dihitung ulang otomatis — layar Peta dan readout "RS TERDEKAT" di Beranda
/// tidak perlu memuat ulang sendiri.
final nearestHospitalsProvider = FutureProvider<List<NearbyHospital>>((ref) async {
  final location = ref.watch(locationProvider);
  if (location is! LocationReady) return const [];
  return ref.watch(apiClientProvider).nearestHospitals(location.point);
});

// ---------------------------------------------------------------------------
// Panggilan aktif — inti layar SOS Aktif
// ---------------------------------------------------------------------------

/// Melacak SATU panggilan darurat yang sedang berjalan.
///
/// Menyatukan tiga sumber yang harus selalu sinkron:
///   1. hasil REST saat pertama dibuka,
///   2. event `call:status` dari socket (perubahan status),
///   3. event `driver:location` (posisi ambulans bergerak).
///
/// Kalau ketiganya ditangani terpisah di layar, ada jendela waktu saat layar
/// menampilkan status lama dengan posisi baru — persis jenis inkonsistensi
/// yang bikin pengguna kehilangan kepercayaan saat panik.
final activeCallProvider =
    NotifierProvider<ActiveCallNotifier, EmergencyCall?>(ActiveCallNotifier.new);

class ActiveCallNotifier extends Notifier<EmergencyCall?> {
  StreamSubscription<EmergencyCall>? _statusSub;
  StreamSubscription<DriverLocationEvent>? _locationSub;

  @override
  EmergencyCall? build() {
    final socket = ref.watch(socketServiceProvider);

    _statusSub = socket.callUpdates.listen((call) {
      // Hanya terima pembaruan untuk panggilan yang sedang dipantau.
      if (state != null && call.id == state!.id) {
        final previousStatus = state!.status;
        state = call;
        _maybeNotify(previousStatus, call);
      }
    });

    _locationSub = socket.driverLocations.listen((event) {
      final current = state;
      if (current != null && event.callId == current.id) {
        state = current.copyWith(driverLocation: event.position);
      }
    });

    ref.onDispose(() {
      _statusSub?.cancel();
      _locationSub?.cancel();
    });

    return null;
  }

  /// Notifikasi lokal saat status panggilan benar-benar BERUBAH (bukan setiap
  /// pesan socket — server bisa mengirim `call:status` walau isinya sama,
  /// mis. saat posisi sopir diperbarui bersamaan).
  ///
  /// Notifikasi lokal saja: muncul selama app masih hidup (foreground atau
  /// background), TIDAK sampai app di-*force-close* total — itu butuh push
  /// FCM yang di luar cakupan revisi ini.
  void _maybeNotify(CallStatus previous, EmergencyCall call) {
    if (previous == call.status) return;

    final String categoryId;
    final String title;
    final String body;

    switch (call.status) {
      case CallStatus.confirmed:
      case CallStatus.enRoute:
        categoryId = kNotifCategoryAssigned;
        title = 'Sopir Menuju Lokasi Anda';
        body = call.driverName != null
            ? '${call.driverName} sedang menuju lokasi Anda (SOS #${call.callCode}).'
            : 'Sopir ambulans sedang menuju lokasi Anda.';
      case CallStatus.arrived:
        categoryId = kNotifCategoryArrived;
        title = 'Ambulans Telah Tiba';
        body = 'Ambulans sudah tiba di lokasi Anda (SOS #${call.callCode}).';
      case CallStatus.completed:
      case CallStatus.cancelled:
        categoryId = kNotifCategoryFinished;
        title = call.status == CallStatus.completed
            ? 'Panggilan Selesai'
            : 'Panggilan Dibatalkan';
        body = 'SOS #${call.callCode} telah '
            '${call.status == CallStatus.completed ? 'selesai' : 'dibatalkan'}.';
      case CallStatus.pending:
        return; // Status awal — belum ada yang perlu diberitahukan.
    }

    final prefs = ref.read(notificationPrefsProvider);
    if (!prefs.isCategoryEnabled(categoryId)) return;

    // Id notifikasi tetap per kategori (bukan per panggilan) supaya
    // notifikasi status yang baru MENGGANTI yang lama, bukan menumpuk —
    // pengguna cuma peduli status TERKINI dari satu panggilan yang aktif.
    ref.read(notificationServiceProvider).show(
          id: categoryId.hashCode,
          title: title,
          body: body,
        );
  }

  /// Pasang panggilan sebagai yang sedang dipantau, lalu minta socket ikut
  /// mendengarkan room-nya.
  void track(EmergencyCall call) {
    state = call;
    ref.read(socketServiceProvider).watchCall(call.id);
  }

  void clear() => state = null;

  /// Muat panggilan aktif yang mungkin masih berjalan dari sesi sebelumnya.
  ///
  /// Penting untuk kasus nyata: pengguna menekan SOS lalu aplikasinya tertutup
  /// (baterai, tidak sengaja). Saat dibuka lagi, dia harus langsung kembali ke
  /// layar pelacakan — bukan ke beranda seolah tidak terjadi apa-apa.
  Future<void> restoreActive() async {
    try {
      final calls = await ref.read(apiClientProvider).listCalls(activeOnly: true);
      if (calls.isNotEmpty) track(calls.first);
    } catch (_) {
      // Diam-diam gagal: ini pemulihan opsional, bukan alur utama.
    }
  }

  Future<void> refresh() async {
    final current = state;
    if (current == null) return;
    try {
      state = await ref.read(apiClientProvider).getCall(current.id);
    } catch (_) {
      // Biarkan state lama; socket masih akan memperbaruinya.
    }
  }

  Future<void> cancel({String? reason}) async {
    final current = state;
    if (current == null) return;
    final updated = await ref.read(apiClientProvider).changeCallStatus(
          current.id,
          CallStatus.cancelled,
          cancelReason: reason ?? 'Dibatalkan oleh pasien',
        );
    state = updated;
  }
}

// ---------------------------------------------------------------------------
// Riwayat & profil medis
// ---------------------------------------------------------------------------

final callHistoryProvider = FutureProvider<List<EmergencyCall>>(
  (ref) => ref.watch(apiClientProvider).listCalls(),
);

final medicalProfileProvider = FutureProvider<MedicalProfile>(
  (ref) => ref.watch(apiClientProvider).getMedical(),
);

/// Tab yang sedang aktif di navigasi bawah.
final patientTabProvider = NotifierProvider<PatientTabNotifier, int>(
  PatientTabNotifier.new,
);

class PatientTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}
