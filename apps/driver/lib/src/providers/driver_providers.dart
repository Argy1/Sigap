import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_core/mobile_core.dart';

/// Provider khusus App Sopir.

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

    _assignmentSub = socket.assignments.listen((call) => state = call);

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
        state = null;
        ref.invalidate(driverProfileProvider);
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
