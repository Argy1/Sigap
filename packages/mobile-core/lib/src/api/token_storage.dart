import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token yang aman (Keystore di Android, Keychain di iOS).
///
/// Tiga jenis token disimpan di sini:
///   - access  : JWT pendek, dikirim di header Authorization
///   - refresh : untuk memperbarui access token tanpa login ulang
///   - call    : MODE TAMU — hanya berlaku untuk satu panggilan darurat
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _s;

  static const _kAccess = 'ambulans.access';
  static const _kRefresh = 'ambulans.refresh';
  static const _kCall = 'ambulans.callToken';

  Future<String?> readAccess() => _s.read(key: _kAccess);
  Future<String?> readRefresh() => _s.read(key: _kRefresh);
  Future<String?> readCallToken() => _s.read(key: _kCall);

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
    // Sudah punya akun -> call token tamu tidak relevan lagi.
    await _s.delete(key: _kCall);
  }

  Future<void> saveCallToken(String token) => _s.write(key: _kCall, value: token);

  Future<void> clearCallToken() => _s.delete(key: _kCall);

  Future<bool> hasSession() async => (await readAccess()) != null;

  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kCall);
  }
}
