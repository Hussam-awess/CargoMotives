import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/language_switcher_tile.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/theme_scope.dart';
import '../../../shared/widgets/confirm_password_dialog.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/edit_profile_screen.dart';
import '../auth/customer_forgot_password_screen.dart';
import '../../support/active_sessions_screen.dart';
import '../../support/change_password_screen.dart';
import '../../support/delete_account_screen.dart';
import '../../support/how_it_works_screen.dart';
import '../../support/settings_widgets.dart';

/// "Settings" (mockup) — Customer. Every control here is backed by the
/// server: notification categories (including the opt-in SMS alerts and
/// Promotions), two-factor authentication, active sessions, account
/// deletion, currency, language, Terms/Privacy and Log out. Dark mode is
/// real too (ThemeScope/ThemeController), stored on the device. Distance
/// units stay shown, not editable — this app only ever uses kilometres.
class CustomerSettingsScreen extends StatefulWidget {
  CustomerSettingsScreen({
    super.key,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
  }) : authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  AuthRepository get _authRepository => widget.authRepository;
  SessionStore get _sessionStore => widget.sessionStore;

  UserProfile? _profile;

  /// Optimistic toggle values shown while a save is in flight — keyed by
  /// category, cleared once the server answers (success or failure).
  final _pending = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authRepository.me();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Non-critical — the toggles show their defaults until it loads.
    }
  }

  bool _wants(String category) =>
      _pending[category] ?? _profile?.wants(category) ?? UserProfile.defaultNotificationPreferences[category] ?? true;

  Future<void> _setNotificationCategory(String category, bool value) async {
    setState(() => _pending[category] = value);
    try {
      final profile = await _authRepository.updateNotificationPreferences({category: value});
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Falls back to the last server-confirmed value below — the toggle
      // never claims a preference the server didn't actually save.
      if (mounted) _showMessage(AppLocalizations.of(context)!.couldNotSaveSetting);
    } finally {
      if (mounted) setState(() => _pending.remove(category));
    }
  }

  Future<void> _setTwoFactor(bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final password = await showConfirmPasswordDialog(context);
    if (password == null || !mounted) return;

    try {
      final profile = await _authRepository.updateTwoFactor(enabled: enabled, currentPassword: password);
      if (!mounted) return;
      setState(() => _profile = profile);
      _showMessage(enabled ? l10n.twoFactorEnabledMessage : l10n.twoFactorDisabledMessage);
    } on ApiException catch (e) {
      if (mounted) _showMessage(e.firstErrorFor('current_password') ?? e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCurrencyPicker() async {
    final current = _profile?.preferredCurrency ?? 'TZS';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.currencyLabel),
        children: [
          for (final currency in const ['TZS', 'USD'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(currency),
              child: Row(
                children: [
                  if (currency == current)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(currency),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;

    try {
      final profile = await _authRepository.updatePreferredCurrency(selected);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) _showMessage(AppLocalizations.of(context)!.couldNotUpdateCurrency);
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: profile,
          credential: ProfileCredential.email,
          authRepository: _authRepository,
        ),
      ),
    );
    _loadProfile();
  }

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showMessage(AppLocalizations.of(context)!.couldNotOpenUri(uri.toString()));
    }
  }

  String _maskPhone(String? raw) {
    if (raw == null) return '—';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12) return raw;
    final national = digits.substring(digits.length - 9);
    return '+255 ${national.substring(0, 3)} ••• ${national.substring(6)}';
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logOutLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _authRepository.logout();
    } catch (_) {
      // Even if the server can't be reached, this device still signs out.
    } finally {
      await _sessionStore.clear();
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSectionLabel(l10n.notificationsSectionLabel),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: l10n.shipmentUpdatesTitle,
                subtitle: l10n.shipmentUpdatesSubtitle,
                value: _wants('shipment_updates'),
                onChanged: (v) => _setNotificationCategory('shipment_updates', v),
              ),
              // 'New offers' is a customer's own wording for the backend's
              // 'bids' category (a company bidding on their job).
              SettingsToggleRow(
                title: l10n.newOffersTitle,
                subtitle: l10n.newOffersSubtitle,
                value: _wants('bids'),
                onChanged: (v) => _setNotificationCategory('bids', v),
              ),
              SettingsToggleRow(
                title: l10n.newMessagesTitle,
                subtitle: l10n.newMessagesSubtitle,
                value: _wants('messages'),
                onChanged: (v) => _setNotificationCategory('messages', v),
              ),
              SettingsToggleRow(
                title: l10n.smsAlertsTitle,
                subtitle: l10n.smsAlertsSubtitle,
                value: _wants('sms_alerts'),
                onChanged: (v) => _setNotificationCategory('sms_alerts', v),
              ),
              SettingsToggleRow(
                title: l10n.promotionsTitle,
                subtitle: l10n.promotionsSubtitle,
                value: _wants('promotions'),
                onChanged: (v) => _setNotificationCategory('promotions', v),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.appearanceLanguageSectionLabel),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: l10n.darkModeTitle,
                subtitle: l10n.darkModeSubtitle,
                value: ThemeScope.of(context).value,
                onChanged: (v) => ThemeScope.of(context).setDarkMode(v),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: LanguageSwitcherTile(authRepository: _authRepository),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.learnSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.howCargoMotivesWorks,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HowItWorksScreen()),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.preferencesSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.currencyLabel,
                value: _profile?.preferredCurrency ?? 'TZS',
                onTap: _openCurrencyPicker,
              ),
              SettingsNavRow(
                title: l10n.distanceUnitsLabel,
                value: l10n.kilometresValue,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.accountSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.registeredPhoneLabel,
                value: _profile == null ? null : _maskPhone(_profile!.phoneNumber),
                onTap: _profile == null ? null : _openEditProfile,
              ),
              SettingsNavRow(
                title: l10n.emailHint,
                value: _profile?.email,
                onTap: _profile == null ? null : _openEditProfile,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.securitySectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.changePasswordLabel,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangePasswordScreen(
                      onForgotPassword: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerForgotPasswordScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SettingsToggleRow(
                title: l10n.twoFactorAuthLabel,
                subtitle: l10n.twoFactorAuthSubtitle,
                value: _profile?.twoFactorEnabled ?? false,
                onChanged: _setTwoFactor,
              ),
              SettingsNavRow(
                title: l10n.activeSessionsLabel,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActiveSessionsScreen(authRepository: _authRepository),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.legalSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.termsOfServiceLabel,
                onTap: () => _openLegal('/legal/terms'),
              ),
              SettingsNavRow(
                title: l10n.privacyPolicyLabel,
                onTap: () => _openLegal('/legal/privacy'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                side: BorderSide(color: AppColors.dangerBorder),
              ),
              child: Text(l10n.logOutLabel),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Cargo Motives v1.0.0 · build 1',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeleteAccountScreen(authRepository: _authRepository, sessionStore: _sessionStore),
                ),
              ),
              child: Text(
                l10n.deleteAccountLabel,
                style: const TextStyle(color: AppColors.statusError),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
