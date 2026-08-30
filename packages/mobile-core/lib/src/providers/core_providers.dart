import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/token_storage.dart';
import '../models/models.dart';
import '../realtime/socket_service.dart';

/// Provider bersama App Pasien & App Sopir.

// ---------------------------------------------------------------------------
// Infrastruktur
// ---------------------------------------------------------------------------

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokens: ref.watch(tokenStorageProvider)),
);

final socketServiceProvider = Provider<SocketService>((ref) {
  final socket = SocketService();
  ref.onDispose(socket.dispose);
  return socket;
});

/// True selama socket tersambung — dipakai indikator "Sistem Aktif".
final socketConnectedProvider = StreamProvider<bool>(
  (ref) => ref.watch(socketServiceProvider).connection,
);

// ---------------------------------------------------------------------------
// Tema
// ---------------------------------------------------------------------------

/// Mode gelap adalah DEFAULT sistem desain ini, bukan mengikuti sistem operasi.
/// "Dispatch Console" dirancang gelap sebagai dasar; mode terang adalah varian.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;
}

// ---------------------------------------------------------------------------
// Autentikasi
// ---------------------------------------------------------------------------

sealed class AuthState {
  const AuthState();
}

/// Sedang memulihkan sesi dari token tersimpan.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Belum masuk. [asGuest] true kalau pengguna memilih mode tamu.
class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.asGuest = false});

  final bool asGuest;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);

  final AuthUser user;
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Pemulihan sesi dijalankan sekali saat provider pertama dibaca.
    Future.microtask(restore);
    return const AuthLoading();
  }

  ApiClient get _api => ref.read(apiClientProvider);
  TokenStorage get _tokens => ref.read(tokenStorageProvider);
  SocketService get _socket => ref.read(socketServiceProvider);

  Future<void> restore() async {
    if (!await _tokens.hasSession()) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final user = await _api.me();
      state = AuthSignedIn(user);
      await _connectSocket();
    } catch (_) {
      await _tokens.clear();
      state = const AuthSignedOut();
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final user = await _api.login(identifier: identifier, password: password);
    state = AuthSignedIn(user);
    await _connectSocket();
  }

  Future<void> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final user = await _api.register(
      fullName: fullName,
      phone: phone,
      password: password,
    );
    state = AuthSignedIn(user);
    await _connectSocket();
  }

  /// Masuk mode tamu — tanpa akun sama sekali.
  ///
  /// Tidak menghubungi server: SOS tamu baru membuat call token SAAT tombol
  /// SOS ditekan. Ini yang membuat mode tamu benar-benar nol hambatan.
  void continueAsGuest() {
    state = const AuthSignedOut(asGuest: true);
  }

  Future<void> logout() async {
    await _api.logout();
    _socket.disconnect();
    state = const AuthSignedOut();
  }

  /// Perbarui status ketersediaan sopir di state tanpa memuat ulang profil.
  void updateAvailability(AvailabilityStatus status) {
    final current = state;
    if (current is AuthSignedIn) {
      state = AuthSignedIn(current.user.copyWith(availabilityStatus: status));
    }
  }

  Future<void> _connectSocket() async {
    final access = await _tokens.readAccess();
    if (access != null) _socket.connect(accessToken: access);
  }

  /// Sambungkan socket memakai call token tamu (setelah SOS tamu dibuat).
  Future<void> connectAsGuest() async {
    final callToken = await _tokens.readCallToken();
    if (callToken != null) _socket.connect(callToken: callToken);
  }
}

// ---------------------------------------------------------------------------
// Lokasi
// ---------------------------------------------------------------------------

sealed class LocationState {
  const LocationState();
}

class LocationLoading extends LocationState {
  const LocationLoading();
}

class LocationReady extends LocationState {
  const LocationReady(this.point);

  final LatLngPoint point;
}

/// Izin ditolak / GPS mati — [message] siap ditampilkan ke pengguna.
class LocationDenied extends LocationState {
  const LocationDenied(this.message, {this.permanently = false});

  final String message;
  final bool permanently;
}

final locationProvider =
    NotifierProvider<LocationNotifier, LocationState>(LocationNotifier.new);

class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() {
    Future.microtask(refresh);
    return const LocationLoading();
  }

  /// Ambil posisi terkini, sekaligus menangani seluruh jalur izin.
  ///
  /// Lokasi adalah SATU-SATUNYA masukan wajib untuk SOS — kalau ini gagal,
  /// seluruh aplikasi kehilangan gunanya. Karena itu setiap kemungkinan
  /// kegagalan diberi pesan yang memberi tahu pengguna apa yang harus dilakukan.
  Future<void> refresh() async {
    state = const LocationLoading();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = const LocationDenied(
          'Layanan lokasi (GPS) sedang mati. Nyalakan dulu untuk mengirim SOS.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        state = const LocationDenied(
          'Izin lokasi ditolak permanen. Aktifkan lewat Pengaturan aplikasi.',
          permanently: true,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        state = const LocationDenied(
          'Izin lokasi diperlukan agar ambulans tahu harus ke mana.',
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      state = LocationReady(LatLngPoint(pos.latitude, pos.longitude));
    } catch (e) {
      state = LocationDenied('Gagal mendapatkan lokasi: $e');
    }
  }

  /// Titik terakhir yang diketahui, atau null.
  LatLngPoint? get point =>
      state is LocationReady ? (state as LocationReady).point : null;
}
