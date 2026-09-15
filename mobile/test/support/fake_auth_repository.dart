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
  final Future<void> Function(String newEmail)? onRequestEmailChange;
  final Future<UserProfile> Function(String newEmail, String code)?
  onConfirmEmailChange;
  final Future<void> Function(String newPhone)? onRequestPhoneChange;
  final Future<UserProfile> Function(String newPhone, String code)?
  onConfirmPhoneChange;
  final Future<UserProfile> Function(String phoneNumber)? onUpdatePhone;
  final Future<UserProfile> Function(String email)? onUpdateEmail;
  final Future<UserProfile> Function(PlatformFile avatar)? onUpdateAvatar;
  final Future<UserProfile> Function(String? companyName, PlatformFile? logo)?
  onUpdateBusinessIdentity;
  final Future<UserProfile> Function(Map<String, bool> preferences)?
  onUpdateNotificationPreferences;

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
  Future<void> requestEmailChange(String newEmail) {
    return onRequestEmailChange?.call(newEmail) ?? Future.value();
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
  Future<void> requestPhoneChange(String newPhone) {
    return onRequestPhoneChange?.call(newPhone) ?? Future.value();
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
