import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The two account types a signed-in session can hold (PRD §5 — Driver has
/// no account/session; Admin uses the separate web tool, not this app).
enum AccountRole { customer, transporterCompany }

/// Thin wrapper around secure, encrypted on-device storage for the signed-in
/// session (auth token + role). Nothing writes to this yet — Phase 1 (Auth)
/// is where phone/OTP login actually populates it — but the splash screen's
/// "valid session? -> role home; else Welcome" check (AppFlow §1) needs this
/// contract to exist now so later phases don't have to touch the routing
/// shell built in Phase 0.
///
/// Uses flutter_secure_storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android) rather than plain SharedPreferences, since this will hold an
/// auth token once Phase 1 lands — not appropriate for unencrypted storage.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'account_role';

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<AccountRole?> getRole() async {
    final raw = await _storage.read(key: _roleKey);
    return switch (raw) {
      'customer' => AccountRole.customer,
      'transporter_company' => AccountRole.transporterCompany,
      _ => null,
    };
  }

  Future<void> save({required String token, required AccountRole role}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(
      key: _roleKey,
      value: role == AccountRole.customer ? 'customer' : 'transporter_company',
    );
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
