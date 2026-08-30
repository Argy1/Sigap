import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'token_storage.dart';

/// Alamat backend, disuntikkan saat build:
///
///   flutter run --dart-define=API_URL=http://10.0.2.2:4000
///
/// Bawaannya `10.0.2.2` — alias localhost host dari dalam emulator Android.
/// Di Chrome/desktop, gantilah ke `http://localhost:4000`.
const String kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

/// Google Maps key. Kosong = seluruh aplikasi memakai peta fallback bergaya
/// mockup. Lihat DispatchMap.
const String kGoogleMapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

bool get hasGoogleMaps => kGoogleMapsKey.trim().isNotEmpty;

/// Error API dengan pesan yang sudah siap ditampilkan ke pengguna.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.details]);

  final int? statusCode;
  final String message;
  final Object? details;

  @override
  String toString() => message;
}

/// Client HTTP untuk seluruh aplikasi mobile.
///
/// Menangani tiga hal yang kalau dibiarkan tersebar akan jadi sumber bug:
/// menempelkan token, memperbarui token yang kedaluwarsa, dan menerjemahkan
/// error jaringan jadi pesan berbahasa Indonesia.
class ApiClient {
  ApiClient({required this.tokens, String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${baseUrl ?? kApiUrl}/api',
            connectTimeout: const Duration(seconds: 12),
            receiveTimeout: const Duration(seconds: 15),
            headers: {'Content-Type': 'application/json'},
            // Status apa pun diterima; penerjemahan error dilakukan sendiri
            // di bawah supaya pesannya konsisten.
            validateStatus: (_) => true,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final access = await tokens.readAccess();
          if (access != null) {
            options.headers['Authorization'] = 'Bearer $access';
          }
          // Mode tamu: call token menggantikan access token.
          final callToken = await tokens.readCallToken();
          if (access == null && callToken != null) {
            options.headers['X-Call-Token'] = callToken;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage tokens;

  /// Menjaga hanya ada SATU permintaan refresh saat beberapa request 401
  /// terjadi bersamaan.
  Future<bool>? _refreshing;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool allowRetry = true,
  }) async {
    late Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
    } on DioException catch (e) {
      throw ApiException(
        null,
        switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'Koneksi ke server terlalu lama. Periksa jaringan Anda.',
          DioExceptionType.connectionError =>
            'Tidak bisa terhubung ke server.\nPastikan backend berjalan di $kApiUrl',
          _ => 'Terjadi kesalahan jaringan.',
        },
      );
    }

    final status = res.statusCode ?? 500;

    // Access token kedaluwarsa -> perbarui sekali lalu ulangi.
    if (status == 401 && allowRetry && await tokens.readRefresh() != null) {
      if (await _refreshOnce()) {
        return _send(method, path, body: body, query: query, allowRetry: false);
      }
    }

    if (status >= 200 && status < 300) {
      if (res.data == null || res.data == '') return const {};
      return Map<String, dynamic>.from(res.data as Map);
    }

    final data = res.data;
    String message = 'Permintaan gagal ($status)';
    Object? details;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      message = err['message'] as String? ?? message;
      details = err['details'];
    }
    throw ApiException(status, message, details);
  }

  Future<bool> _refreshOnce() {
    return _refreshing ??= () async {
      try {
        final refresh = await tokens.readRefresh();
        if (refresh == null) return false;

        final res = await _dio.post<dynamic>(
          '/auth/refresh',
          data: {'refreshToken': refresh},
        );
        if ((res.statusCode ?? 500) >= 300) {
          await tokens.clear();
          return false;
        }
        final data = Map<String, dynamic>.from(res.data as Map);
        await tokens.saveTokens(
          access: data['accessToken'] as String,
          refresh: data['refreshToken'] as String,
        );
        return true;
      } catch (e) {
        debugPrint('[api] refresh gagal: $e');
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  // =========================================================================
  // Auth
  // =========================================================================

  Future<AuthUser> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final data = await _send('POST', '/auth/register', body: {
      'fullName': fullName,
      'phone': phone,
      'password': password,
    });
    await tokens.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final data = await _send('POST', '/auth/login', body: {
      'identifier': identifier,
      'password': password,
    });
    await tokens.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> me() async {
    final data = await _send('GET', '/auth/me');
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refresh = await tokens.readRefresh();
    try {
      await _send('POST', '/auth/logout', body: {'refreshToken': refresh});
    } catch (_) {
      // Sesi lokal tetap dibersihkan walau server tidak merespons.
    }
    await tokens.clear();
  }

  // =========================================================================
  // Profil medis
  // =========================================================================

  Future<MedicalProfile> getMedical() async {
    final data = await _send('GET', '/patients/me/medical');
    return MedicalProfile.fromJson(data['medical'] as Map<String, dynamic>);
  }

  Future<MedicalProfile> updateMedical(MedicalProfile profile) async {
    final data = await _send('PUT', '/patients/me/medical', body: {
      'bloodType': profile.bloodType,
      'allergies': profile.allergies,
      'medicalHistory': profile.medicalHistory,
      'emergencyContactName': profile.emergencyContactName,
      'emergencyContactPhone': profile.emergencyContactPhone,
    });
    return MedicalProfile.fromJson(data['medical'] as Map<String, dynamic>);
  }

  // =========================================================================
  // Rumah sakit
  // =========================================================================

  /// Publik — tidak butuh login, dipakai layar Peta dan alur mode tamu.
  Future<List<NearbyHospital>> nearestHospitals(
    LatLngPoint point, {
    int? limit,
  }) async {
    final data = await _send('GET', '/hospitals/nearest', query: {
      'lat': point.lat,
      'lng': point.lng,
      'limit': ?limit,
    });
    return (data['hospitals'] as List)
        .map((e) => NearbyHospital.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // =========================================================================
  // Panggilan darurat
  // =========================================================================

  /// Membuat SOS. Tanpa login, [guestName] & [guestPhone] wajib diisi dan
  /// hasilnya membawa `callToken` untuk memantau panggilan.
  Future<CreateCallResult> createEmergencyCall({
    required LatLngPoint location,
    String? conditionNote,
    String? guestName,
    String? guestPhone,
  }) async {
    final data = await _send('POST', '/emergency-calls', body: {
      'lat': location.lat,
      'lng': location.lng,
      if (conditionNote != null && conditionNote.isNotEmpty)
        'conditionNote': conditionNote,
      if (guestName != null && guestName.isNotEmpty) 'guestName': guestName,
      if (guestPhone != null && guestPhone.isNotEmpty) 'guestPhone': guestPhone,
    });

    final result = CreateCallResult.fromJson(data);
    if (result.callToken != null) {
      await tokens.saveCallToken(result.callToken!);
    }
    return result;
  }

  Future<EmergencyCall> getCall(String id) async {
    final data = await _send('GET', '/emergency-calls/$id');
    return EmergencyCall.fromJson(data['call'] as Map<String, dynamic>);
  }

  Future<List<EmergencyCall>> listCalls({bool activeOnly = false}) async {
    final data = await _send('GET', '/emergency-calls', query: {
      if (activeOnly) 'active': 'true',
    });
    return (data['calls'] as List)
        .map((e) => EmergencyCall.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EmergencyCall> changeCallStatus(
    String id,
    CallStatus status, {
    String? cancelReason,
  }) async {
    final data = await _send('PATCH', '/emergency-calls/$id/status', body: {
      'status': callStatusToJson(status),
      'cancelReason': ?cancelReason,
    });
    return EmergencyCall.fromJson(data['call'] as Map<String, dynamic>);
  }

  /// Sopir menolak tugas — panggilan kembali ke antrean RS.
  Future<EmergencyCall> rejectAssignment(String id) async {
    final data = await _send('POST', '/emergency-calls/$id/reject');
    return EmergencyCall.fromJson(data['call'] as Map<String, dynamic>);
  }

  // =========================================================================
  // Sopir
  // =========================================================================

  Future<DriverProfile> myDriverProfile() async {
    final data = await _send('GET', '/drivers/me');
    return DriverProfile.fromJson(data['driver'] as Map<String, dynamic>);
  }

  Future<DriverProfile> setAvailability(AvailabilityStatus status) async {
    final data = await _send('PATCH', '/drivers/me/availability', body: {
      'availabilityStatus': availabilityToJson(status),
    });
    return DriverProfile.fromJson(data['driver'] as Map<String, dynamic>);
  }

  /// Jalur cadangan pengiriman posisi. Jalur utamanya socket — lihat
  /// SocketService.pushLocation.
  Future<void> pushLocation(LatLngPoint point) async {
    await _send('PATCH', '/drivers/me/location', body: {
      'lat': point.lat,
      'lng': point.lng,
    });
  }
}
