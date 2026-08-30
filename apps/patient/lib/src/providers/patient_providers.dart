import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_core/mobile_core.dart';

/// Provider khusus App Pasien.

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
      if (state != null && call.id == state!.id) state = call;
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
