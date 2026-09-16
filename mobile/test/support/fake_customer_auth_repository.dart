import 'package:cargo_motives/features/customer/auth/data/customer_auth_repository.dart';

/// Configurable test double for CustomerAuthRepository — same pattern as
/// FakeAuthRepository: each method's behavior is supplied per-test via a
/// callback.
class FakeCustomerAuthRepository extends CustomerAuthRepository {
  FakeCustomerAuthRepository({
    this.onRegister,
    this.onVerifyRegistration,
    this.onLogin,
    this.onRequestPasswordReset,
    this.onConfirmPasswordReset,
  });

  final Future<void> Function(CustomerRegistration registration)? onRegister;
  final Future<String> Function({required String email, required String code})? onVerifyRegistration;
  final Future<String> Function({required String email, required String password})? onLogin;
  final Future<void> Function(String email)? onRequestPasswordReset;
  final Future<void> Function(String email, String code, String password)? onConfirmPasswordReset;

  @override
  Future<void> register(CustomerRegistration registration) {
    return onRegister?.call(registration) ?? Future.value();
  }

  @override
  Future<String> verifyRegistration({required String email, required String code}) {
    return onVerifyRegistration?.call(email: email, code: code) ?? Future.value('test-token');
  }

  @override
  Future<String> login({required String email, required String password}) {
    return onLogin?.call(email: email, password: password) ?? Future.value('test-token');
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    return onRequestPasswordReset?.call(email) ?? Future.value();
  }

  @override
  Future<void> confirmPasswordReset({required String email, required String code, required String password}) {
    return onConfirmPasswordReset?.call(email, code, password) ?? Future.value();
  }
}
