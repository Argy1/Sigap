import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_core/mobile_core.dart';

import 'backend_probe.dart';

/// Uji integrasi ApiClient terhadap backend yang BENAR-BENAR berjalan.
///
/// Kenapa ini ada: uji golden membuktikan tampilannya benar, dan uji golden-path
/// di backend membuktikan API-nya benar. Yang belum terbukti adalah lapisan di
/// antaranya — kode Dart yang mengirim request, memasang token, dan mengurai
/// JSON jadi model. Di situlah bug sunyi biasanya bersembunyi: nama field yang
/// meleset satu huruf tidak tertangkap oleh uji mana pun di atas.
///
/// Uji ini otomatis DILEWATI kalau backend tidak berjalan, supaya `flutter test`
/// tetap hijau di mesin yang belum menyalakan server.
///
/// Jalankan bersama backend:
///   cd backend && npm run dev
///   cd packages/mobile-core && flutter test

/// Penyimpanan token tiruan berbasis memori.
///
/// flutter_secure_storage memakai platform channel yang tidak tersedia di
/// lingkungan `flutter test`, jadi channel-nya distub di sini. Perhatikan bahwa
/// ini tetap memakai kelas TokenStorage yang ASLI — yang dipalsukan hanya
/// lapisan penyimpanan platformnya, bukan logika yang sedang diuji.
void _stubSecureStorage() {
  final store = <String, String>{};

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = call.arguments as Map?;
      switch (call.method) {
        case 'write':
          store[args!['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args!['key'] as String];
        case 'delete':
          store.remove(args!['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(store);
        case 'deleteAll':
          store.clear();
          return null;
        case 'containsKey':
          return store.containsKey(args!['key'] as String);
        default:
          return null;
      }
    },
  );
}

void main() {
  late ApiClient api;
  late TokenStorage tokens;

  setUpAll(_stubSecureStorage);

  setUp(() async {
    // Wajib di setiap setUp: binding uji memasang ulang HttpOverrides-nya.
    allowRealNetwork();
    tokens = TokenStorage();
    await tokens.clear();
    api = ApiClient(tokens: tokens, baseUrl: kBackend);
  });

  group('ApiClient terhadap backend nyata', skip: !backendAvailable, () {
    test('login pasien mengurai profil dengan benar', () async {
      final user = await api.login(
        identifier: '081234567890',
        password: 'password123',
      );

      expect(user.role, Role.patient);
      expect(user.fullName, isNotEmpty);
      expect(await tokens.readAccess(), isNotNull);
      expect(await tokens.readRefresh(), isNotNull);
    });

    test('kata sandi salah ditolak dengan pesan yang bisa dibaca', () async {
      await expectLater(
        api.login(identifier: '081234567890', password: 'salah'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', contains('salah')),
        ),
      );
    });

    test('pencarian RS terdekat bisa diakses tanpa login', () async {
      final hospitals = await api.nearestHospitals(
        const LatLngPoint(-6.5971, 106.8060),
      );

      expect(hospitals, isNotEmpty);
      // Urutan akhir ditentukan WAKTU TEMPUH, bukan jarak garis lurus.
      for (var i = 1; i < hospitals.length; i++) {
        expect(
          hospitals[i].durationSeconds,
          greaterThanOrEqualTo(hospitals[i - 1].durationSeconds),
          reason: 'Daftar RS harus terurut menaik berdasarkan waktu tempuh',
        );
      }
      expect(hospitals.first.position.lat, closeTo(-6.6, 0.2));
    });

    test('profil medis terbaca lengkap termasuk daftar alergi', () async {
      await api.login(identifier: '081234567890', password: 'password123');
      final medical = await api.getMedical();

      expect(medical.bloodType, 'O+');
      expect(medical.allergies, contains('Penisilin'));
    });

    test('SOS pasien membawa snapshot medis dan RS terdekat', () async {
      await api.login(identifier: '081234567890', password: 'password123');

      final result = await api.createEmergencyCall(
        location: const LatLngPoint(-6.5878, 106.7862),
        conditionNote: 'uji integrasi dart',
      );

      final call = result.call;
      expect(call.callCode, startsWith('A'));
      expect(call.status, CallStatus.pending);
      expect(call.hospitalId, isNotNull);
      expect(call.patientAddress, isNotNull);
      expect(call.isGuest, isFalse);
      // Snapshot medis harus ikut — inilah yang muncul sebagai peringatan
      // merah di layar sopir.
      expect(call.medical?.bloodType, 'O+');
      expect(call.medical?.allergies, contains('Penisilin'));
      // Pasien yang sudah login TIDAK menerima call token; dia punya sesi.
      expect(result.callToken, isNull);

      // Bereskan supaya panggilan uji tidak menumpuk di dashboard.
      final cancelled = await api.changeCallStatus(
        call.id,
        CallStatus.cancelled,
        cancelReason: 'pembersihan uji integrasi',
      );
      expect(cancelled.status, CallStatus.cancelled);
    });

    test('SOS mode tamu menghasilkan call token dan bisa dipantau', () async {
      // Tanpa login sama sekali.
      final result = await api.createEmergencyCall(
        location: const LatLngPoint(-6.5866, 106.7849),
        guestName: 'Tamu Uji Dart',
        guestPhone: '081200007777',
      );

      expect(result.callToken, isNotNull);
      expect(result.call.isGuest, isTrue);
      expect(result.call.patientName, 'Tamu Uji Dart');
      // Call token harus tersimpan otomatis agar request berikutnya memakainya.
      expect(await tokens.readCallToken(), result.callToken);

      // Membaca panggilan sendiri lewat call token harus berhasil.
      final fetched = await api.getCall(result.call.id);
      expect(fetched.id, result.call.id);

      await api.changeCallStatus(
        result.call.id,
        CallStatus.cancelled,
        cancelReason: 'pembersihan uji integrasi',
      );
    });

    test('SOS tamu tanpa nomor HP ditolak', () async {
      await expectLater(
        api.createEmergencyCall(location: const LatLngPoint(-6.59, 106.79)),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('sopir bisa mengubah ketersediaan dan membaca profilnya', () async {
      await api.login(identifier: '081211110001', password: 'password123');

      final profile = await api.myDriverProfile();
      expect(profile.hospitalId, isNotEmpty);
      expect(profile.vehiclePlate, isNotNull);

      final updated = await api.setAvailability(AvailabilityStatus.available);
      expect(updated.availabilityStatus, AvailabilityStatus.available);
    });

    test('pasien TIDAK bisa menembus endpoint sopir', () async {
      await api.login(identifier: '081234567890', password: 'password123');

      await expectLater(
        api.myDriverProfile(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });
}
