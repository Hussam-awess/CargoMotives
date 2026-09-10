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
import '../data/featured_repository.dart';
import '../featured/featured_screen.dart';

/// "Settings" (mockup, Transporter) — mirrors CustomerSettingsScreen's
/// scope call. Real: language switcher, registered phone (AuthRepository.
/// me()), Cargo Motives Plus status/link (CompanyFeaturedRepository, the
/// same repository CompanyProfileTab already uses), Terms/Privacy,
/// Log out. Locally-stateful only: Availability/Notification toggles, the
/// dark-mode preview swatch, 2FA. "Manage trucks"/"Manage drivers" point
/// back to the real Fleet tab rather than duplicating navigation into a
/// second copy of FleetScreen here.
class CompanySettingsScreen extends StatefulWidget {
  CompanySettingsScreen({
    super.key,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
    CompanyFeaturedRepository? featuredRepository,
    this.prefs = const LocalPrefs(),
  }) : authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository();

  final AuthRepository authRepository;
  final SessionStore sessionStore;
  final CompanyFeaturedRepository featuredRepository;
  final LocalPrefs prefs;

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  bool _acceptingLoads = true;
  bool _autoDeclineBelowBudget = false;
  bool _shareGpsWithCustomers = true;
  bool _newMatchingLoads = true;
  bool _bidAcceptedOrDeclined = true;
  bool _payoutReleased = true;
  bool _driverOffRoute = false;
  bool _twoFactor = false;
  bool _darkPreview = false;
  UserProfile? _profile;
  CompanyFeaturedStatus? _featuredStatus;

  @override
  void initState() {
    super.initState();
    _loadToggles();
    _loadProfile();
    _loadFeaturedStatus();
  }

  Future<void> _loadToggles() async {
    final acceptingLoads = await widget.prefs.getBool('company_settings.accepting_loads', defaultValue: true);
    final autoDecline = await widget.prefs.getBool('company_settings.auto_decline_below_budget', defaultValue: false);
    final shareGps = await widget.prefs.getBool('company_settings.share_gps', defaultValue: true);
    final newMatchingLoads = await widget.prefs.getBool('company_settings.notif.new_matching_loads', defaultValue: true);
    final bidAcceptedOrDeclined = await widget.prefs.getBool('company_settings.notif.bid_accepted_declined', defaultValue: true);
    final payoutReleased = await widget.prefs.getBool('company_settings.notif.payout_released', defaultValue: true);
    final driverOffRoute = await widget.prefs.getBool('company_settings.notif.driver_off_route', defaultValue: false);
    final twoFactor = await widget.prefs.getBool('company_settings.two_factor', defaultValue: false);
    final darkPreview = await widget.prefs.getBool('settings.dark_preview', defaultValue: false);
    if (!mounted) return;
    setState(() {
      _acceptingLoads = acceptingLoads;
      _autoDeclineBelowBudget = autoDecline;
      _shareGpsWithCustomers = shareGps;
      _newMatchingLoads = newMatchingLoads;
      _bidAcceptedOrDeclined = bidAcceptedOrDeclined;
      _payoutReleased = payoutReleased;
      _driverOffRoute = driverOffRoute;
      _twoFactor = twoFactor;
      _darkPreview = darkPreview;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.authRepository.me();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Non-critical.
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: profile,
          credential: ProfileCredential.phone,
          showName: false,
          authRepository: widget.authRepository,
        ),
      ),
    );
    _loadProfile();
  }

  Future<void> _loadFeaturedStatus() async {
    try {
      final status = await widget.featuredRepository.status();
      if (mounted) setState(() => _featuredStatus = status);
    } catch (_) {
      // Non-critical — the Plus row just shows nothing until it loads.
    }
  }

  Future<void> _setToggle(String key, bool value, VoidCallback apply) async {
    setState(apply);
    await widget.prefs.setBool(key, value);
  }

  void _hintFleetTab(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open the Fleet tab to manage $what.')));
  }

  Future<void> _openLegal(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  Future<void> _logout() async {
    try {
      await widget.authRepository.logout();
    } finally {
      await widget.sessionStore.clear();
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
          const SettingsSectionLabel('Availability'),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: 'Accepting loads',
                subtitle: 'Turn off when your whole fleet is committed',
                value: _acceptingLoads,
                onChanged: (v) => _setToggle('company_settings.accepting_loads', v, () => _acceptingLoads = v),
              ),
              const SettingsNavRow(title: 'Search radius', value: '80 km'),
              SettingsToggleRow(
                title: 'Auto-decline below budget',
                subtitle: 'Hide loads priced under your floor rate',
                value: _autoDeclineBelowBudget,
                onChanged: (v) => _setToggle('company_settings.auto_decline_below_budget', v, () => _autoDeclineBelowBudget = v),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Fleet & drivers'),
          SettingsCard(
            children: [
              SettingsNavRow(title: 'Manage trucks', onTap: () => _hintFleetTab('trucks')),
              SettingsNavRow(title: 'Manage drivers', onTap: () => _hintFleetTab('drivers')),
              SettingsToggleRow(
                title: 'Share GPS with customers',
                subtitle: 'Only while a job is active',
                value: _shareGpsWithCustomers,
                onChanged: (v) => _setToggle('company_settings.share_gps', v, () => _shareGpsWithCustomers = v),
              ),
              const SettingsNavRow(title: 'Document expiry reminders', value: '30 days', isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Notifications'),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: 'New matching loads',
                subtitle: 'On your lanes and return legs',
                value: _newMatchingLoads,
                onChanged: (v) => _setToggle('company_settings.notif.new_matching_loads', v, () => _newMatchingLoads = v),
              ),
              SettingsToggleRow(
                title: 'Bid accepted or declined',
                value: _bidAcceptedOrDeclined,
                onChanged: (v) => _setToggle('company_settings.notif.bid_accepted_declined', v, () => _bidAcceptedOrDeclined = v),
              ),
              SettingsToggleRow(
                title: 'Payout released',
                value: _payoutReleased,
                onChanged: (v) => _setToggle('company_settings.notif.payout_released', v, () => _payoutReleased = v),
              ),
              SettingsToggleRow(
                title: 'Driver went off-route',
                value: _driverOffRoute,
                onChanged: (v) => _setToggle('company_settings.notif.driver_off_route', v, () => _driverOffRoute = v),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SettingsSectionLabel('Company & billing'),
          SettingsCard(
            children: [
              const SettingsNavRow(title: 'Payout method', value: 'M-Pesa'),
              SettingsNavRow(
                title: _featuredStatus?.isFeatured == true ? 'Cargo Motives Plus · active' : 'Cargo Motives Plus',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => CompanyFeaturedScreen(repository: widget.featuredRepository))),
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
                child: LanguageSwitcherTile(authRepository: widget.authRepository),
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
          const SettingsSectionLabel('Account'),
          SettingsCard(
            children: [
              SettingsNavRow(title: 'Registered phone', value: _profile?.phoneNumber, onTap: _profile == null ? null : _openEditProfile),
              SettingsNavRow(
                title: 'Change password',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
              ),
              SettingsToggleRow(
                title: 'Two-factor authentication',
                value: _twoFactor,
                onChanged: (v) => _setToggle('company_settings.two_factor', v, () => _twoFactor = v),
                isLast: true,
              ),
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
        ],
      ),
    );
  }
}
