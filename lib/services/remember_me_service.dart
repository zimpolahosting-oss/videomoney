import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RememberMeCredentials {
  const RememberMeCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class RememberMeService {
  RememberMeService._();

  static final RememberMeService instance = RememberMeService._();

  static const _keyEnabled = 'remember_me_enabled';
  static const _keyEmail = 'remember_me_email';
  static const _keyPassword = 'remember_me_password';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<bool> isEnabled() async {
    return (await _storage.read(key: _keyEnabled)) == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _keyEnabled, value: enabled ? 'true' : 'false');
  }

  Future<RememberMeCredentials?> readCredentials() async {
    final email = (await _storage.read(key: _keyEmail)) ?? '';
    final password = (await _storage.read(key: _keyPassword)) ?? '';
    if (email.trim().isEmpty || password.isEmpty) return null;
    return RememberMeCredentials(email: email, password: password);
  }

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: email.trim());
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyEnabled);
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
  }
}

