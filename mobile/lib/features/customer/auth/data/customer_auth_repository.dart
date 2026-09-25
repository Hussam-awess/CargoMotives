import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';

import '../../../../core/device/device_name.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/two_factor_repository.dart';

/// Everything collected on the Customer sign-up form — kept as one typed
/// object (not loose parameters) so CustomerOtpScreen can hold onto it and
/// resend by calling [CustomerAuthRepository.register] again with the
/// exact same data, without the user having to retype anything.
class CustomerRegistration {
  const CustomerRegistration({
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.passwordConfirmation,
    this.companyName,
    this.logo,
    this.preferredCurrency = 'TZS',
  });

  final String fullName;
  final String email;
  final String phoneNumber;
  final String password;
  final String passwordConfirmation;
  final String? companyName;
  final PlatformFile? logo;

  /// A denomination choice for this customer's own future job postings —
  /// see users.preferred_currency's backend migration docblock. No
  /// conversion system exists behind this.
  final String preferredCurrency;
}

/// Customer signup + login (Phase 11 product decision): email + password,
/// verified once via an emailed code — see the backend's
/// CustomerAuthController for why this replaced the phone+SMS-OTP flow
/// Customer originally shared with Transporter Company (still
/// AuthRepository, unchanged, for Transporter Company).
class CustomerAuthRepository {
  CustomerAuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> register(CustomerRegistration registration) async {
    final formData = FormData.fromMap({
      'full_name': registration.fullName,
      'email': registration.email,
      'phone_number': registration.phoneNumber,
      'password': registration.password,
      'password_confirmation': registration.passwordConfirmation,
      if (registration.companyName != null &&
          registration.companyName!.isNotEmpty)
        'company_name': registration.companyName,
      if (registration.logo != null)
        'logo': await _toMultipart(registration.logo!),
      'preferred_currency': registration.preferredCurrency,
    });

    await _client.postForm('/auth/customer/register', formData);
  }

  /// Returns the new session's bearer token.
  Future<String> verifyRegistration({
    required String email,
    required String code,
  }) async {
    final body = await _client.post(
      '/auth/customer/register/verify',
      data: {'email': email, 'code': code, 'device_name': currentDeviceName()},
    );

    return body['token'] as String;
  }

  /// Returns the session's bearer token, or throws [TwoFactorRequired] when
  /// the account has two-factor on and a code is needed first.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final body = await _client.post(
      '/auth/customer/login',
      data: {'email': email, 'password': password, 'device_name': currentDeviceName()},
    );

    return TwoFactorRequired.tokenOrThrow(body);
  }

  /// Deliberately returns nothing to check — the backend's own response is
  /// a generic "if that email has an account…" message either way, so
  /// there's nothing to branch on.
  Future<void> requestPasswordReset({required String email}) {
    return _client.post(
      '/auth/customer/password/forgot',
      data: {'email': email},
    );
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String password,
  }) {
    return _client.post(
      '/auth/customer/password/reset',
      data: {
        'email': email,
        'code': code,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    // On web, PlatformFile only ever exposes `bytes` (no real filesystem
    // path); on other platforms `path` is set and bytes may not be
    // loaded. Handle both so this works identically across targets (same
    // pattern as CompanyRepository.submit()).
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
