import '../../../core/auth/session_store.dart';
import '../../../core/network/api_client.dart';

class OtpVerifyResult {
  const OtpVerifyResult({required this.token});

  final String token;
}

/// The subset of UserResource the home dashboards actually render
/// (greeting name, company name, featured badge) — not a full
/// profile-editing model.
class UserProfile {
  const UserProfile({required this.fullName, required this.companyName, required this.isFeatured, this.phoneNumber, this.email});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['full_name'] as String?,
      companyName: json['company_name'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
    );
  }

  final String? fullName;
  final String? companyName;
  final bool isFeatured;
  final String? phoneNumber;
  final String? email;
}

/// Wraps Transporter Company's phone+OTP endpoints (see backend
/// routes/api.php `auth.*`) behind typed methods, so screens never
/// construct request bodies or parse response maps themselves. Customer
/// moved to email+password in Phase 11 — see CustomerAuthRepository.
///
/// Design-import restyle: full_name/email/password are collected at
/// request-time now (mirroring CustomerAuthRepository's shape) rather than
/// at verify-time — the account is still only created once the code
/// verifies (AuthController's pending-cache pattern). A password-based
/// login() exists alongside the OTP flow now that Transporter Company has
/// a password.
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> requestOtp({
    required String phoneNumber,
    required AccountRole role,
    required String fullName,
    required String email,
    required String password,
  }) {
    return _client.post(
      '/auth/otp/request',
      data: {
        'phone_number': phoneNumber,
        'account_type': _accountTypeValue(role),
        'full_name': fullName,
        'email': email,
        'password': password,
        // The mockup's Transporter sign-up shows a single password field
        // (no separate confirm-password one) — sent to satisfy the
        // backend's shared `confirmed` validation rule without adding
        // UI friction the design doesn't call for.
        'password_confirmation': password,
      },
    );
  }

  Future<OtpVerifyResult> verifyOtp({required String phoneNumber, required AccountRole role, required String code}) async {
    final body = await _client.post(
      '/auth/otp/verify',
      data: {'phone_number': phoneNumber, 'account_type': _accountTypeValue(role), 'code': code},
    );

    return OtpVerifyResult(token: body['token'] as String);
  }

  Future<String> login({required String phoneNumber, required String password}) async {
    final body = await _client.post('/auth/company/login', data: {'phone_number': phoneNumber, 'password': password});

    return body['token'] as String;
  }

  /// Best-effort sync of the language switcher (Phase 10) to the backend's
  /// User.language_preference — the on-device LocaleController is the
  /// source of truth for what the app actually displays (it has to work
  /// before/without a network round-trip), this just keeps the backend
  /// record consistent with it for whichever account is signed in.
  Future<void> updateLanguagePreference(String languageCode) {
    return _client.post('/auth/profile/language', data: {'language_preference': languageCode});
  }

  Future<UserProfile> me() async {
    final body = await _client.get('/auth/me');
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Applies immediately — full_name isn't a login credential, unlike
  /// email/phone below.
  Future<UserProfile> updateFullName(String fullName) async {
    final body = await _client.post('/auth/profile/name', data: {'full_name': fullName});
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Sends a confirmation code to [newEmail] — the email doesn't change
  /// until [confirmEmailChange] verifies it (Phase 10.16: email is the
  /// Customer's login credential).
  Future<void> requestEmailChange(String newEmail) {
    return _client.post('/auth/profile/email/request-change', data: {'new_email': newEmail});
  }

  Future<UserProfile> confirmEmailChange({required String newEmail, required String code}) async {
    final body = await _client.post('/auth/profile/email/confirm-change', data: {'new_email': newEmail, 'code': code});
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Same shape as requestEmailChange/confirmEmailChange, for phone — the
  /// Transporter Company's login credential.
  Future<void> requestPhoneChange(String newPhone) {
    return _client.post('/auth/profile/phone/request-change', data: {'new_phone': newPhone});
  }

  Future<UserProfile> confirmPhoneChange({required String newPhone, required String code}) async {
    final body = await _client.post('/auth/profile/phone/confirm-change', data: {'new_phone': newPhone, 'code': code});
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> logout() => _client.post('/auth/logout');

  String _accountTypeValue(AccountRole role) => switch (role) {
    AccountRole.customer => 'customer',
    AccountRole.transporterCompany => 'transporter_company',
  };
}
