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
import '../data/featured_repository.dart';
import '../featured/featured_screen.dart';
import '../fleet/fleet_screen.dart';
import 'company_details_screen.dart';

/// "Settings" (mockup, Transporter) — mirrors CustomerSettingsScreen's
/// scope call. Real: language switcher, registered phone (AuthRepository.
/// me()), Cargo Motives Plus status/link (CompanyFeaturedRepository, the
/// same repository CompanyProfileTab already uses), Terms/Privacy,
/// Log out. Locally-stateful only: Availability/Notification toggles, the
/// 2FA toggle. "Manage trucks"/"Manage drivers" point
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
    final acceptingLoads = await widget.prefs.getBool(
      'company_settings.accepting_loads',
      defaultValue: true,
    );
    final autoDecline = await widget.prefs.getBool(
      'company_settings.auto_decline_below_budget',
      defaultValue: false,
    );
    final shareGps = await widget.prefs.getBool(
      'company_settings.share_gps',
      defaultValue: true,
    );
    final newMatchingLoads = await widget.prefs.getBool(
      'company_settings.notif.new_matching_loads',
      defaultValue: true,
    );
    final bidAcceptedOrDeclined = await widget.prefs.getBool(
      'company_settings.notif.bid_accepted_declined',
      defaultValue: true,
    );
    final payoutReleased = await widget.prefs.getBool(
      'company_settings.notif.payout_released',
      defaultValue: true,
    );
    final driverOffRoute = await widget.prefs.getBool(
      'company_settings.notif.driver_off_route',
      defaultValue: false,
    );
    final twoFactor = await widget.prefs.getBool(
      'company_settings.two_factor',
      defaultValue: false,
    );
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

  void _openFleet() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FleetScreen()));
  }

  void _openPreferredRoutes() {
    final status = _featuredStatus;
    if (status == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreferredRoutesScreen(
          repository: widget.featuredRepository,
          initialRoutes: status.preferredRoutes,
        ),
      ),
    );
  }

  void _openCompanyDetails() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CompanyDetailsScreen()));
  }

  String _maskPhone(String? raw) {
    if (raw == null) return '—';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12) return raw;
    final national = digits.substring(digits.length - 9);
    return '+255 ${national.substring(0, 3)} ••• ${national.substring(6)}';
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SettingsSectionLabel(l10n.availabilitySectionLabel),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: l10n.acceptingLoadsTitle,
                subtitle: l10n.acceptingLoadsSubtitle,
                value: _acceptingLoads,
                onChanged: (v) => _setToggle(
                  'company_settings.accepting_loads',
                  v,
                  () => _acceptingLoads = v,
                ),
              ),
              SettingsNavRow(title: l10n.searchRadiusLabel, value: '80 km'),
              SettingsToggleRow(
                title: l10n.autoDeclineBelowBudgetTitle,
                subtitle: l10n.autoDeclineBelowBudgetSubtitle,
                value: _autoDeclineBelowBudget,
                onChanged: (v) => _setToggle(
                  'company_settings.auto_decline_below_budget',
                  v,
                  () => _autoDeclineBelowBudget = v,
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.fleetDriversSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(title: l10n.manageTrucksLabel, onTap: _openFleet),
              SettingsNavRow(title: l10n.manageDriversLabel, onTap: _openFleet),
              SettingsToggleRow(
                title: l10n.shareGpsTitle,
                subtitle: l10n.shareGpsSubtitle,
                value: _shareGpsWithCustomers,
                onChanged: (v) => _setToggle(
                  'company_settings.share_gps',
                  v,
                  () => _shareGpsWithCustomers = v,
                ),
              ),
              SettingsNavRow(
                title: l10n.documentExpiryRemindersLabel,
                value: '30 days',
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.notificationsSectionLabel),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: l10n.newMatchingLoadsTitle,
                subtitle: l10n.newMatchingLoadsSubtitle,
                value: _newMatchingLoads,
                onChanged: (v) => _setToggle(
                  'company_settings.notif.new_matching_loads',
                  v,
                  () => _newMatchingLoads = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.bidAcceptedOrDeclinedTitle,
                value: _bidAcceptedOrDeclined,
                onChanged: (v) => _setToggle(
                  'company_settings.notif.bid_accepted_declined',
                  v,
                  () => _bidAcceptedOrDeclined = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.payoutReleasedTitle,
                value: _payoutReleased,
                onChanged: (v) => _setToggle(
                  'company_settings.notif.payout_released',
                  v,
                  () => _payoutReleased = v,
                ),
              ),
              SettingsToggleRow(
                title: l10n.driverOffRouteTitle,
                value: _driverOffRoute,
                onChanged: (v) => _setToggle(
                  'company_settings.notif.driver_off_route',
                  v,
                  () => _driverOffRoute = v,
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.companyBillingSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.companyDetailsDocumentsLabel,
                onTap: _openCompanyDetails,
              ),
              SettingsNavRow(
                title: l10n.preferredLanesLabel,
                value: _featuredStatus == null
                    ? null
                    : l10n.preferredLanesSavedCount(
                        _featuredStatus!.preferredRoutes.length,
                      ),
                onTap: _featuredStatus == null ? null : _openPreferredRoutes,
              ),
              SettingsNavRow(title: l10n.payoutMethodLabel, value: 'M-Pesa'),
              SettingsNavRow(
                title: _featuredStatus?.isFeatured == true
                    ? l10n.cargoMotivesPlusActiveLabel
                    : l10n.cargoMotivesPlusLabel,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompanyFeaturedScreen(
                      repository: widget.featuredRepository,
                    ),
                  ),
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
                child: LanguageSwitcherTile(
                  authRepository: widget.authRepository,
                ),
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
          SettingsSectionLabel(l10n.accountSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.registeredPhoneLabel,
                value: _profile == null
                    ? null
                    : _maskPhone(_profile!.phoneNumber),
                onTap: _profile == null ? null : _openEditProfile,
              ),
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
                value: _twoFactor,
                onChanged: (v) => _setToggle(
                  'company_settings.two_factor',
                  v,
                  () => _twoFactor = v,
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
        ],
      ),
    );
  }
}
