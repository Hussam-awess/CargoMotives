import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';

/// Configurable test double for AuthRepository — each method's behavior is
/// supplied per-test via a callback, so a test only wires up the one
/// endpoint it actually exercises rather than mocking a full HTTP stack for
/// a UI-behavior test.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.onRequestOtp,
    this.onVerifyOtp,
    this.onUpdateLanguagePreference,
  });

  final Future<void> Function(String phoneNumber, AccountRole role)?
  onRequestOtp;
  final Future<OtpVerifyResult> Function(
    String phoneNumber,
    AccountRole role,
    String code,
    String fullName,
    String email,
  )?
  onVerifyOtp;
  final Future<void> Function(String languageCode)? onUpdateLanguagePreference;

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required AccountRole role,
  }) {
    return onRequestOtp?.call(phoneNumber, role) ?? Future.value();
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phoneNumber,
    required AccountRole role,
    required String code,
    required String fullName,
    required String email,
  }) {
    return onVerifyOtp?.call(phoneNumber, role, code, fullName, email) ??
        Future.value(const OtpVerifyResult(token: 'test-token'));
  }

  @override
  Future<void> updateLanguagePreference(String languageCode) {
    return onUpdateLanguagePreference?.call(languageCode) ?? Future.value();
  }
}
