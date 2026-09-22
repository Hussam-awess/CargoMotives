import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:file_picker/file_picker.dart';

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
  const UserProfile({
    required this.fullName,
    required this.companyName,
    required this.isFeatured,
    this.phoneNumber,
    this.email,
    this.avatarUrl,
    this.companyLogoUrl,
    this.notificationPreferences = const {
      'bids': true,
      'shipment_updates': true,
      'messages': true,
      'new_job_matches': true,
    },
    this.preferredCurrency = 'TZS',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      fullName: json['full_name'] as String?,
      companyName: json['company_name'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      companyLogoUrl: json['company_logo_url'] as String?,
      notificationPreferences:
          (json['notification_preferences'] as Map<String, dynamic>?)
              ?.cast<String, bool>() ??
          const {
            'bids': true,
            'shipment_updates': true,
            'messages': true,
            'new_job_matches': true,
          },
      preferredCurrency: json['preferred_currency'] as String? ?? 'TZS',
    );
  }

  final String? fullName;
  final String? companyName;
  final bool isFeatured;
  final String? phoneNumber;
  final String? email;

  /// A personal profile photo, any account_type — distinct from
  /// [companyLogoUrl] (a Customer's optional business identity) and a
  /// TransporterCompany's own logo (a different model entirely).
  final String? avatarUrl;

  /// A Customer's optional business identity (Phase 11) — null for every
  /// other account_type.
  final String? companyLogoUrl;

  /// Keys: bids, shipment_updates, messages, new_job_matches — always
  /// resolved with every key present (UserResource fills in the default of
  /// `true` server-side), never a partial map.
  final Map<String, bool> notificationPreferences;

  /// A denomination choice for this user's own future job postings —
  /// 'TZS' or 'USD'. Not a currency-conversion setting: there is no
  /// exchange-rate system behind this, see the backend migration's own
  /// docblock.
  final String preferredCurrency;
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

    return OtpVerifyResult(token: body['token'] as String);
  }

  Future<String> login({
    required String phoneNumber,
    required String password,
  }) async {
    final body = await _client.post(
      '/auth/company/login',
      data: {'phone_number': phoneNumber, 'password': password},
    );

    return body['token'] as String;
  }

  /// Deliberately returns nothing to check — the backend's own response
  /// is a generic "if that number has an account…" message either way, so
  /// there's nothing role-specific for the caller to branch on.
  Future<void> requestPasswordReset({required String phoneNumber}) {
    return _client.post(
      '/auth/company/password/forgot',
      data: {'phone_number': phoneNumber},
    );
  }

  Future<void> confirmPasswordReset({
    required String phoneNumber,
    required String code,
    required String password,
  }) {
    return _client.post(
      '/auth/company/password/reset',
      data: {
        'phone_number': phoneNumber,
        'code': code,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  /// Best-effort sync of the language switcher (Phase 10) to the backend's
  /// User.language_preference — the on-device LocaleController is the
  /// source of truth for what the app actually displays (it has to work
  /// before/without a network round-trip), this just keeps the backend
  /// record consistent with it for whichever account is signed in.
  Future<void> updateLanguagePreference(String languageCode) {
    return _client.post(
      '/auth/profile/language',
      data: {'language_preference': languageCode},
    );
  }

  /// Changeable any time from Settings (either account_type) — a
  /// denomination choice only, see UserProfile.preferredCurrency.
  Future<UserProfile> updatePreferredCurrency(String currency) async {
    final body = await _client.post(
      '/auth/profile/currency',
      data: {'preferred_currency': currency},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<UserProfile> me() async {
    final body = await _client.get('/auth/me');
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Applies immediately — full_name isn't a login credential, unlike
  /// email/phone below.
  Future<UserProfile> updateFullName(String fullName) async {
    final body = await _client.post(
      '/auth/profile/name',
      data: {'full_name': fullName},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Sends a confirmation code to [newEmail] — the email doesn't change
  /// until [confirmEmailChange] verifies it (Phase 10.16: email is the
  /// Customer's login credential). [currentPassword] proves the caller
  /// still controls the account before it can start hijacking its own
  /// login credential — a signed-in session alone isn't strong enough
  /// proof for a change this sensitive.
  Future<void> requestEmailChange(
    String newEmail, {
    required String currentPassword,
  }) {
    return _client.post(
      '/auth/profile/email/request-change',
      data: {'new_email': newEmail, 'current_password': currentPassword},
    );
  }

  Future<UserProfile> confirmEmailChange({
    required String newEmail,
    required String code,
  }) async {
    final body = await _client.post(
      '/auth/profile/email/confirm-change',
      data: {'new_email': newEmail, 'code': code},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Same shape as requestEmailChange/confirmEmailChange, for phone — the
  /// Transporter Company's login credential.
  Future<void> requestPhoneChange(
    String newPhone, {
    required String currentPassword,
  }) {
    return _client.post(
      '/auth/profile/phone/request-change',
      data: {'new_phone': newPhone, 'current_password': currentPassword},
    );
  }

  Future<UserProfile> confirmPhoneChange({
    required String newPhone,
    required String code,
  }) async {
    final body = await _client.post(
      '/auth/profile/phone/confirm-change',
      data: {'new_phone': newPhone, 'code': code},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Immediate, unverified update — only valid when phone_number isn't the
  /// caller's login credential (a Customer's own phone, not Transporter
  /// Company's). The backend rejects the other case.
  Future<UserProfile> updatePhone(String phoneNumber) async {
    final body = await _client.post(
      '/auth/profile/phone',
      data: {'phone_number': phoneNumber},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Same as [updatePhone], for email — only valid for Transporter Company
  /// (Customer's email is its login credential).
  Future<UserProfile> updateEmail(String email) async {
    final body = await _client.post(
      '/auth/profile/email',
      data: {'email': email},
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// A personal profile photo, any account_type.
  Future<UserProfile> updateAvatar(PlatformFile avatar) async {
    final formData = FormData.fromMap({'avatar': await _toMultipart(avatar)});
    final body = await _client.postForm('/auth/profile/avatar', formData);
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// A Customer's optional business identity (company_name + logo) — the
  /// same fields collected at registration, now editable afterward.
  /// Customer-only; the backend rejects every other account_type.
  Future<UserProfile> updateBusinessIdentity({
    String? companyName,
    PlatformFile? logo,
  }) async {
    final formData = FormData.fromMap({
      'company_name': companyName ?? '',
      if (logo != null) 'logo': await _toMultipart(logo),
    });
    final body = await _client.postForm('/auth/profile/business', formData);
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Merges into the existing map server-side (ProfileController::
  /// updateNotificationPreferences) — safe to call with just the one
  /// category a Settings toggle just changed.
  Future<UserProfile> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    final body = await _client.post(
      '/auth/profile/notification-preferences',
      data: preferences,
    );
    return UserProfile.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Real, authenticated "change password" — distinct from
  /// requestPasswordReset/confirmPasswordReset above, which are for when
  /// the caller does NOT know the current password. Here they must prove
  /// they do.
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) {
    return _client.post(
      '/auth/profile/password',
      data: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<void> logout() => _client.post('/auth/logout');

  String _accountTypeValue(AccountRole role) => switch (role) {
    AccountRole.customer => 'customer',
    AccountRole.transporterCompany => 'transporter_company',
  };

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    // On web, PlatformFile only ever exposes `bytes` (no real filesystem
    // path); on other platforms `path` is set and bytes may not be loaded.
    // Handle both so this works identically across targets.
    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: file.name);
    }

    return MultipartFile.fromFile(file.path!, filename: file.name);
  }
}
