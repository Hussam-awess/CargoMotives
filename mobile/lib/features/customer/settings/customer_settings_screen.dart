import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/local/local_prefs.dart';
import '../../../core/localization/language_switcher_tile.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/theme/theme_scope.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/edit_profile_screen.dart';
import '../../support/change_password_screen.dart';
import '../../support/how_it_works_screen.dart';
import '../../support/settings_widgets.dart';

/// "Settings" (mockup) — Customer. Real: the language switcher, the
/// registered phone/email (AuthRepository.me()), Terms/Privacy (real
/// server-rendered pages), Log out. Dark mode is real (ThemeScope/
/// ThemeController — see core/theme), not a preview: the toggle here drives
/// the whole app's theme. Locally-stateful only, no backend field yet:
/// notification-category toggles. Currency/distance units are shown, not editable
/// — this app only ever uses TZS and kilometres, so there's nothing to
/// choose. Change password and Delete account have no backend endpoint
/// yet; both say so honestly instead of pretending to save anything.
class CustomerSettingsScreen extends StatefulWidget {
  CustomerSettingsScreen({
    super.key,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
    this.prefs = const LocalPrefs(),
  }) : authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore();

  final AuthRepository authRepository;
  final SessionStore sessionStore;
  final LocalPrefs prefs;

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  AuthRepository get _authRepository => widget.authRepository;
  SessionStore get _sessionStore => widget.sessionStore;

  bool _shipmentUpdates = true;
  bool _newOffers = true;
  bool _smsAlerts = false;
  bool _promotions = false;
  bool _twoFactor = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadToggles();
    _loadProfile();
  }

  Future<void> _loadToggles() async {
    final shipmentUpdates = await widget.prefs.getBool(
      'settings.notif.shipment_updates',
      defaultValue: true,
    );
    final newOffers = await widget.prefs.getBool(
      'settings.notif.new_offers',
      defaultValue: true,
    );
    final smsAlerts = await widget.prefs.getBool(
      'settings.notif.sms_alerts',
      defaultValue: false,
    );
    final promotions = await widget.prefs.getBool(
      'settings.notif.promotions',
      defaultValue: false,
    );
    final twoFactor = await widget.prefs.getBool(
      'settings.two_factor',
      defaultValue: false,
    );
    if (!mounted) return;
    setState(() {
      _shipmentUpdates = shipmentUpdates;
      _newOffers = newOffers;
      _smsAlerts = smsAlerts;
      _promotions = promotions;
      _twoFactor = twoFactor;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authRepository.me();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Non-critical — the phone/email row just stays blank.
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

  Future<void> _setToggle(String key, bool value, VoidCallback apply) async {
    setState(apply);
    await widget.prefs.setBool(key, value);
  }

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.couldNotOpenUri(uri.toString()),
          ),
        ),
      );
    }
  }

  String _maskPhone(String? raw) {
    if (raw == null) return '—';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12) return raw;
    final national = digits.substring(digits.length - 9);
    return '+255 ${national.substring(0, 3)} ••• ${national.substring(6)}';
  }

  Future<void> _showActiveSessionsUnavailable() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.activeSessionsLabel),
        content: Text(l10n.activeSessionsUnavailableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.okLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountLabel),
        content: Text(l10n.deleteAccountUnavailableMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.okLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) return;
  }

  Future<void> _logout() async {
    try {
      await _authRepository.logout();
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
                value: _shipmentUpdates,
                onChanged: (v) => _setToggle(
                  'settings.notif.shipment_updates',
                  v,
                  () => _shipmentUpdates = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.newOffersTitle,
                subtitle: l10n.newOffersSubtitle,
                value: _newOffers,
                onChanged: (v) => _setToggle(
                  'settings.notif.new_offers',
                  v,
                  () => _newOffers = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.smsAlertsTitle,
                subtitle: l10n.smsAlertsSubtitle,
                value: _smsAlerts,
                onChanged: (v) => _setToggle(
                  'settings.notif.sms_alerts',
                  v,
                  () => _smsAlerts = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.promotionsTitle,
                value: _promotions,
                onChanged: (v) => _setToggle(
                  'settings.notif.promotions',
                  v,
                  () => _promotions = v,
                ),
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
              SettingsNavRow(title: l10n.currencyLabel, value: 'TZS'),
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
                value: _profile == null
                    ? null
                    : _maskPhone(_profile!.phoneNumber),
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
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
              ),
              SettingsToggleRow(
                title: l10n.twoFactorAuthLabel,
                subtitle: l10n.twoFactorAuthSubtitle,
                value: _twoFactor,
                onChanged: (v) =>
                    _setToggle('settings.two_factor', v, () => _twoFactor = v),
              ),
              SettingsNavRow(
                title: l10n.activeSessionsLabel,
                onTap: _showActiveSessionsUnavailable,
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
              onPressed: _confirmDeleteAccount,
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
