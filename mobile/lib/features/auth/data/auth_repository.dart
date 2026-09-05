import '../../../core/auth/session_store.dart';
import '../../../core/network/api_client.dart';

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.token,
    required this.requiresProfileSetup,
  });

  final String token;
  final bool requiresProfileSetup;
}

/// Wraps the Phase 1 auth endpoints (see backend routes/api.php `auth.*`)
/// behind typed methods, so screens never construct request bodies or parse
/// response maps themselves.
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
  }) async {
    final body = await _client.post(
      '/auth/otp/verify',
      data: {
        'phone_number': phoneNumber,
        'account_type': _accountTypeValue(role),
        'code': code,
      },
    );

    return OtpVerifyResult(
      token: body['token'] as String,
      requiresProfileSetup: body['requires_profile_setup'] as bool? ?? false,
    );
  }

  Future<void> completeProfile({required String fullName}) {
    return _client.post('/auth/profile', data: {'full_name': fullName});
  }

  String _accountTypeValue(AccountRole role) => switch (role) {
    AccountRole.customer => 'customer',
    AccountRole.transporterCompany => 'transporter_company',
  };
}
