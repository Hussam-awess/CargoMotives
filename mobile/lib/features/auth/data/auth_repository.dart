import '../../../core/auth/session_store.dart';
import '../../../core/network/api_client.dart';

class OtpVerifyResult {
  const OtpVerifyResult({required this.token});

  final String token;
}

/// Wraps Transporter Company's phone+OTP endpoints (see backend
/// routes/api.php `auth.*`) behind typed methods, so screens never
/// construct request bodies or parse response maps themselves. Customer
/// moved to email+password in Phase 11 — see CustomerAuthRepository.
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> requestOtp({
    required String phoneNumber,
    required AccountRole role,
  }) {
    return _client.post(
      '/auth/otp/request',
      data: {
        'phone_number': phoneNumber,
        'account_type': _accountTypeValue(role),
      },
    );
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phoneNumber,
    required AccountRole role,
    required String code,
    required String fullName,
    required String email,
  }) async {
    final body = await _client.post(
      '/auth/otp/verify',
      data: {
        'phone_number': phoneNumber,
        'account_type': _accountTypeValue(role),
        'code': code,
        'full_name': fullName,
        'email': email,
      },
    );

    return OtpVerifyResult(token: body['token'] as String);
  }

  /// Best-effort sync of the language switcher (Phase 10) to the backend's
  /// User.language_preference — the on-device LocaleController is the
  /// source of truth for what the app actually displays (it has to work
  /// before/without a network round-trip), this just keeps the backend
  /// record consistent with it for whichever account is signed in.
  Future<void> updateLanguagePreference(String languageCode) {
    return _client.post('/auth/profile/language', data: {'language_preference': languageCode});
  }

  Future<void> logout() => _client.post('/auth/logout');

  String _accountTypeValue(AccountRole role) => switch (role) {
    AccountRole.customer => 'customer',
    AccountRole.transporterCompany => 'transporter_company',
  };
}
