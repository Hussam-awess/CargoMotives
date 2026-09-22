import 'package:cargo_motives/core/auth/session_store.dart';

/// A no-op SessionStore for widget tests — the real one reads/writes
/// through flutter_secure_storage's platform channel, which isn't
/// available in a plain widget test and would throw.
class FakeSessionStore extends SessionStore {
  FakeSessionStore() : super(storage: null);

  @override
  Future<bool> hasValidSession() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<AccountRole?> getRole() async => null;

  @override
  Future<void> save({required String token, required AccountRole role}) async {}

  @override
  Future<void> clear() async {}
}
