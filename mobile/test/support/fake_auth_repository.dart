import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:file_picker/file_picker.dart';

/// Configurable test double for AuthRepository — each method's behavior is
/// supplied per-test via a callback, so a test only wires up the one
/// endpoint it actually exercises rather than mocking a full HTTP stack for
/// a UI-behavior test.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.onRequestOtp,
    this.onVerifyOtp,
    this.onLogin,
    this.onUpdateLanguagePreference,
    this.onMe,
    this.onUpdateFullName,
    this.onRequestEmailChange,
    this.onConfirmEmailChange,
    this.onRequestPhoneChange,
    this.onConfirmPhoneChange,
    this.onUpdatePhone,
    this.onUpdateEmail,
    this.onUpdateAvatar,
    this.onUpdateBusinessIdentity,
    this.onUpdateNotificationPreferences,
    this.onRequestPasswordReset,
    this.onConfirmPasswordReset,
    this.onChangePassword,
    this.onUpdatePreferredCurrency,
    this.onLogout,
    this.onUpdateTwoFactor,
    this.onSessions,
    this.onRevokeSession,
    this.onRevokeOtherSessions,
    this.onDeleteAccount,
  });

  final Future<void> Function(
    String phoneNumber,
    AccountRole role,
    String fullName,
    String email,
    String password,
  )?
  onRequestOtp;
  final Future<OtpVerifyResult> Function(
    String phoneNumber,
    AccountRole role,
    String code,
  )?
  onVerifyOtp;
  final Future<String> Function(String phoneNumber, String password)? onLogin;
  final Future<void> Function(String languageCode)? onUpdateLanguagePreference;
  final Future<UserProfile> Function()? onMe;
  final Future<UserProfile> Function(String fullName)? onUpdateFullName;
  final Future<void> Function(String newEmail, String currentPassword)?
  onRequestEmailChange;
  final Future<UserProfile> Function(String newEmail, String code)?
  onConfirmEmailChange;
  final Future<void> Function(String newPhone, String currentPassword)?
  onRequestPhoneChange;
  final Future<UserProfile> Function(String newPhone, String code)?
  onConfirmPhoneChange;
  final Future<UserProfile> Function(String phoneNumber)? onUpdatePhone;
  final Future<UserProfile> Function(String email)? onUpdateEmail;
  final Future<UserProfile> Function(PlatformFile avatar)? onUpdateAvatar;
  final Future<UserProfile> Function(String? companyName, PlatformFile? logo)?
  onUpdateBusinessIdentity;
  final Future<UserProfile> Function(Map<String, bool> preferences)?
  onUpdateNotificationPreferences;
  final Future<void> Function(String phoneNumber)? onRequestPasswordReset;
  final Future<void> Function(String phoneNumber, String code, String password)?
  onConfirmPasswordReset;
  final Future<void> Function(String currentPassword, String password)?
  onChangePassword;
  final Future<UserProfile> Function(String currency)?
  onUpdatePreferredCurrency;
  final Future<void> Function()? onLogout;

  @override
  Future<void> logout() => onLogout?.call() ?? Future.value();

  final Future<UserProfile> Function(bool enabled, String currentPassword)? onUpdateTwoFactor;
  final Future<List<ActiveSession>> Function()? onSessions;
  final Future<void> Function(int sessionId)? onRevokeSession;
  final Future<void> Function()? onRevokeOtherSessions;
  final Future<void> Function(String currentPassword)? onDeleteAccount;

  @override
  Future<UserProfile> updateTwoFactor({required bool enabled, required String currentPassword}) =>
      onUpdateTwoFactor?.call(enabled, currentPassword) ??
      Future.value(UserProfile(fullName: 'Test User', companyName: null, isFeatured: false, twoFactorEnabled: enabled));

  @override
  Future<List<ActiveSession>> sessions() => onSessions?.call() ?? Future.value(const []);

  @override
  Future<void> revokeSession(int sessionId) => onRevokeSession?.call(sessionId) ?? Future.value();

  @override
  Future<void> revokeOtherSessions() => onRevokeOtherSessions?.call() ?? Future.value();

  @override
  Future<void> deleteAccount({required String currentPassword}) =>
      onDeleteAccount?.call(currentPassword) ?? Future.value();

  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required AccountRole role,
    required String fullName,
    required String email,
    required String password,
  }) {
    return onRequestOtp?.call(phoneNumber, role, fullName, email, password) ??
        Future.value();
  }

  @override
  Future<OtpVerifyResult> verifyOtp({
    required String phoneNumber,
    required AccountRole role,
    required String code,
  }) {
    return onVerifyOtp?.call(phoneNumber, role, code) ??
        Future.value(const OtpVerifyResult(token: 'test-token'));
  }

  @override
  Future<String> login({
    required String phoneNumber,
    required String password,
  }) {
    return onLogin?.call(phoneNumber, password) ?? Future.value('test-token');
  }

  @override
  Future<void> updateLanguagePreference(String languageCode) {
    return onUpdateLanguagePreference?.call(languageCode) ?? Future.value();
  }

  @override
  Future<UserProfile> me() {
    return onMe?.call() ??
        Future.value(
          const UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
          ),
        );
  }

  @override
  Future<UserProfile> updateFullName(String fullName) {
    return onUpdateFullName?.call(fullName) ??
        Future.value(
          UserProfile(fullName: fullName, companyName: null, isFeatured: false),
        );
  }

  @override
  Future<void> requestEmailChange(
    String newEmail, {
    required String currentPassword,
  }) {
    return onRequestEmailChange?.call(newEmail, currentPassword) ??
        Future.value();
  }

  @override
  Future<UserProfile> confirmEmailChange({
    required String newEmail,
    required String code,
  }) {
    return onConfirmEmailChange?.call(newEmail, code) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            email: newEmail,
          ),
        );
  }

  @override
  Future<void> requestPhoneChange(
    String newPhone, {
    required String currentPassword,
  }) {
    return onRequestPhoneChange?.call(newPhone, currentPassword) ??
        Future.value();
  }

  @override
  Future<UserProfile> confirmPhoneChange({
    required String newPhone,
    required String code,
  }) {
    return onConfirmPhoneChange?.call(newPhone, code) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            phoneNumber: newPhone,
          ),
        );
  }

  @override
  Future<UserProfile> updatePhone(String phoneNumber) {
    return onUpdatePhone?.call(phoneNumber) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            phoneNumber: phoneNumber,
          ),
        );
  }

  @override
  Future<UserProfile> updateEmail(String email) {
    return onUpdateEmail?.call(email) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            email: email,
          ),
        );
  }

  @override
  Future<UserProfile> updateAvatar(PlatformFile avatar) {
    return onUpdateAvatar?.call(avatar) ??
        Future.value(
          const UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            avatarUrl: 'https://example.com/a.jpg',
          ),
        );
  }

  @override
  Future<UserProfile> updateBusinessIdentity({
    String? companyName,
    PlatformFile? logo,
  }) {
    return onUpdateBusinessIdentity?.call(companyName, logo) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: companyName,
            isFeatured: false,
          ),
        );
  }

  @override
  Future<void> requestPasswordReset({required String phoneNumber}) {
    return onRequestPasswordReset?.call(phoneNumber) ?? Future.value();
  }

  @override
  Future<void> confirmPasswordReset({
    required String phoneNumber,
    required String code,
    required String password,
  }) {
    return onConfirmPasswordReset?.call(phoneNumber, code, password) ??
        Future.value();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) {
    return onChangePassword?.call(currentPassword, password) ?? Future.value();
  }

  @override
  Future<UserProfile> updatePreferredCurrency(String currency) {
    return onUpdatePreferredCurrency?.call(currency) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            preferredCurrency: currency,
          ),
        );
  }

  @override
  Future<UserProfile> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) {
    return onUpdateNotificationPreferences?.call(preferences) ??
        Future.value(
          UserProfile(
            fullName: 'Test User',
            companyName: null,
            isFeatured: false,
            notificationPreferences: {
              'bids': true,
              'shipment_updates': true,
              'messages': true,
              'new_job_matches': true,
              ...preferences,
            },
          ),
        );
  }
}
