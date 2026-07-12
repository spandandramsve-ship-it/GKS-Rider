import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT token and cached rider profile in secure storage.
///
/// All sensitive data (token, profile JSON with PII) is stored via
/// [FlutterSecureStorage] and never logged.
class Session {
  Session._();
  static final Session instance = Session._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'jwt_token';
  static const _keyRider = 'rider_profile';

  // ── Token ──────────────────────────────────────────────────────────────

  String? _cachedToken;

  Future<String?> get token async {
    _cachedToken ??= await _storage.read(key: _keyToken);
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _keyToken, value: token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: _keyToken);
  }

  // ── Rider profile (cached JSON) ───────────────────────────────────────

  Map<String, dynamic>? _cachedRider;

  Future<Map<String, dynamic>?> get rider async {
    if (_cachedRider != null) return _cachedRider;
    final raw = await _storage.read(key: _keyRider);
    if (raw != null) {
      _cachedRider = jsonDecode(raw) as Map<String, dynamic>;
    }
    return _cachedRider;
  }

  Future<void> setRider(Map<String, dynamic> rider) async {
    _cachedRider = rider;
    await _storage.write(key: _keyRider, value: jsonEncode(rider));
  }

  // ── Clear all ─────────────────────────────────────────────────────────

  Future<void> clear() async {
    _cachedToken = null;
    _cachedRider = null;
    await _storage.deleteAll();
  }
}
