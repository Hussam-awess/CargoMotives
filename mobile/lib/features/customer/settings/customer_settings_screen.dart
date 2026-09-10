import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/config/app_config.dart';
import '../../../core/local/local_prefs.dart';
import '../../../core/localization/language_switcher_tile.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/edit_profile_screen.dart';
import '../../support/change_password_screen.dart';
import '../../support/how_it_works_screen.dart';
import '../../support/settings_widgets.dart';

/// "Settings" (mockup) — Customer. Real: the language switcher, the
/// registered phone/email (AuthRepository.me()), Terms/Privacy (real
/// server-rendered pages), Log out. Locally-stateful only, no backend
/// field yet: notification-category toggles, the dark-mode preview swatch
/// (this app has no real dark theme — the toggle only recolors the sample
/// card below it, exactly like the mockup's own "Preview" concept, never
/// the rest of the app). Currency/distance units are shown, not editable
/// — this app only ever uses TZS and kilometres, so there's nothing to
/// choose. Change password and Delete account have no backend endpoint
/// yet; both say so honestly instead of pretending to save anything.
class CustomerSettingsScreen extends StatefulWidget {
  CustomerSettingsScreen({super.key, AuthRepository? authRepository, SessionStore? sessionStore, this.prefs = const LocalPrefs()})
    : authRepository = authRepository ?? AuthRepository(),
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
  bool _darkPreview = false;
  bool _twoFactor = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadToggles();
    _loadProfile();
  }

  Future<void> _loadToggles() async {
    final shipmentUpdates = await widget.prefs.getBool('settings.notif.shipment_updates', defaultValue: true);
    final newOffers = await widget.prefs.getBool('settings.notif.new_offers', defaultValue: true);
    final smsAlerts = await widget.prefs.getBool('settings.notif.sms_alerts', defaultValue: false);
    final promotions = await widget.prefs.getBool('settings.notif.promotions', defaultValue: false);
    final darkPreview = await widget.prefs.getBool('settings.dark_preview', defaultValue: false);
    final twoFactor = await widget.prefs.getBool('settings.two_factor', defaultValue: false);
    if (!mounted) return;
    setState(() {
      _shipmentUpdates = shipmentUpdates;
      _newOffers = newOffers;
      _smsAlerts = smsAlerts;
      _promotions = promotions;
      _darkPreview = darkPreview;
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
        builder: (_) => EditProfileScreen(profile: profile, credential: ProfileCredential.email, authRepository: _authRepository),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $uri')));
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Active sessions'),
        content: const Text('Viewing and managing active sessions isn\'t available in the app yet.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text('Account deletion isn\'t available in the app yet. Contact support to request it.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('OK'))],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SettingsSectionLabel('Notifications'),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: 'Shipment updates',
                subtitle: 'Pickup, transit, delivery',
                value: _shipmentUpdates,
                onChanged: (v) => _setToggle('settings.notif.shipment_updates', v, () => _shipmentUpdates = v),
              ),
              SettingsToggleRow(
                title: 'New offers',
                subtitle: 'When transporters bid on your cargo',
                value: _newOffers,
                onChanged: (v) => _setToggle('settings.notif.new_offers', v, () => _newOffers = v),
              ),
              SettingsToggleRow(
                title: 'SMS alerts',
                subtitle: 'Charges may apply',
                value: _smsAlerts,
                onChanged: (v) => _setToggle('settings.notif.sms_alerts', v, () => _smsAlerts = v),
              ),
              SettingsToggleRow(
                title: 'Promotions',
                value: _promotions,
                onChanged: (v) => _setToggle('settings.notif.promotions', v, () => _promotions = v),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Appearance & language'),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: 'Dark mode',
                subtitle: 'Easier at night and on long hauls',
                value: _darkPreview,
                onChanged: (v) => _setToggle('settings.dark_preview', v, () => _darkPreview = v),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: LanguageSwitcherTile(authRepository: _authRepository),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                child: _DarkPreviewCard(dark: _darkPreview),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Learn'),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: 'How Cargo Motives works',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HowItWorksScreen())),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Preferences'),
          const SettingsCard(
            children: [
              SettingsNavRow(title: 'Currency', value: 'TZS'),
              SettingsNavRow(title: 'Distance units', value: 'Kilometres', isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Account'),
          SettingsCard(
            children: [
              SettingsNavRow(title: 'Registered phone', value: _profile == null ? null : _maskPhone(_profile!.phoneNumber)),
              SettingsNavRow(title: 'Email', value: _profile?.email, onTap: _profile == null ? null : _openEditProfile, isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Security'),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: 'Change password',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              ),
              SettingsToggleRow(
                title: 'Two-factor authentication',
                subtitle: 'SMS code on new devices',
                value: _twoFactor,
                onChanged: (v) => _setToggle('settings.two_factor', v, () => _twoFactor = v),
              ),
              SettingsNavRow(title: 'Active sessions', onTap: _showActiveSessionsUnavailable, isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Legal'),
          SettingsCard(
            children: [
              SettingsNavRow(title: 'Terms of service', onTap: () => _openLegal('/legal/terms')),
              SettingsNavRow(title: 'Privacy policy', onTap: () => _openLegal('/legal/privacy'), isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                side: const BorderSide(color: Color(0xFFE8CFC8)),
              ),
              child: const Text('Log out'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Cargo Motives v1.0.0 · build 1',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _confirmDeleteAccount,
              child: const Text('Delete account', style: TextStyle(color: AppColors.statusError)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkPreviewCard extends StatelessWidget {
  const _DarkPreviewCard({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : AppColors.surface,
        border: Border.all(color: dark ? AppColors.primary : AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CM-0421',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: dark ? AppColors.lightBlue : AppColors.textSecondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(4)),
                child: const Text(
                  'In Transit',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ctaBluePressed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dar es Salaam → Arusha',
            style: TextStyle(
              fontFamily: 'Barlow Condensed',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.1) : AppColors.infoTint,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              'Track Shipment',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dark ? Colors.white : AppColors.ctaBlue),
            ),
          ),
        ],
      ),
    );
  }
}
