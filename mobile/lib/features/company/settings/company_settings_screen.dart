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
import '../../../shared/data/payment_repository.dart';
import '../../../shared/payments/payment_history_screen.dart';
import '../../../shared/widgets/confirm_password_dialog.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/edit_profile_screen.dart';
import '../auth/company_forgot_password_screen.dart';
import '../../support/active_sessions_screen.dart';
import '../../support/change_password_screen.dart';
import '../../support/delete_account_screen.dart';
import '../../support/how_it_works_screen.dart';
import '../../support/settings_widgets.dart';
import '../data/company_preferences_repository.dart';
import '../data/featured_repository.dart';
import '../featured/featured_screen.dart';
import '../fleet/fleet_screen.dart';
import '../fleet/gps_connection_guide_screen.dart';
import '../followed_customers_screen.dart';
import 'company_details_screen.dart';

/// "Settings" (mockup, Transporter) — every control here is backed by the
/// server: notification categories (AuthRepository), Accepting loads /
/// auto-decline / floor rate / display currency (CompanyPreferencesRepository,
/// read back through the Plus status fetch), two-factor authentication,
/// active sessions and account deletion. "Manage trucks"/"Manage drivers"
/// point to the real Fleet screen.
class CompanySettingsScreen extends StatefulWidget {
  CompanySettingsScreen({
    super.key,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
    CompanyFeaturedRepository? featuredRepository,
    CompanyPreferencesRepository? preferencesRepository,
    PaymentRepository? paymentRepository,
  }) : authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository(),
       preferencesRepository = preferencesRepository ?? CompanyPreferencesRepository(),
       paymentRepository = paymentRepository ?? PaymentRepository(isCompany: true);

  final AuthRepository authRepository;
  final SessionStore sessionStore;
  final CompanyFeaturedRepository featuredRepository;
  final CompanyPreferencesRepository preferencesRepository;
  final PaymentRepository paymentRepository;

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  UserProfile? _profile;
  CompanyFeaturedStatus? _featuredStatus;

  /// Optimistic notification-toggle values while a save is in flight.
  final _pending = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFeaturedStatus();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.authRepository.me();
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
      final profile = await widget.authRepository.updateNotificationPreferences({category: value});
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
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
      final profile = await widget.authRepository.updateTwoFactor(enabled: enabled, currentPassword: password);
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

  /// Optimistic update with revert-on-failure, against `_featuredStatus`
  /// since these preferences are read back through the same
  /// `/company/featured/status` fetch.
  Future<void> _updatePreference({
    bool? autoDeclineBelowBudget,
    double? floorRate,
    String? displayCurrency,
    bool? acceptingLoads,
  }) async {
    final previous = _featuredStatus;
    if (previous == null) return;
    setState(
      () => _featuredStatus = previous.copyWith(
        autoDeclineBelowBudget: autoDeclineBelowBudget,
        floorRate: floorRate,
        displayCurrency: displayCurrency,
        acceptingLoads: acceptingLoads,
      ),
    );
    try {
      await widget.preferencesRepository.update(
        autoDeclineBelowBudget: autoDeclineBelowBudget,
        floorRate: floorRate,
        displayCurrency: displayCurrency,
        acceptingLoads: acceptingLoads,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _featuredStatus = previous);
      _showMessage(AppLocalizations.of(context)!.couldNotSaveSetting);
    }
  }

  Future<void> _openFloorRateDialog() async {
    final current = _featuredStatus?.floorRate;
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _FloorRateDialog(initialValue: current),
    );
    if (value != null) _updatePreference(floorRate: value);
  }

  Future<void> _openCurrencyPicker() async {
    final current = _featuredStatus?.displayCurrency ?? 'TZS';
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
                  Expanded(child: Text(currency)),
                  if (currency == current) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected != null && selected != current) {
      _updatePreference(displayCurrency: selected);
    }
  }

  void _openPaymentHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(repository: widget.paymentRepository),
      ),
    );
  }

  void _openFleet() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => FleetScreen()));
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyDetailsScreen()));
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
      _showMessage(AppLocalizations.of(context)!.couldNotOpenUri(uri.toString()));
    }
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
      await widget.authRepository.logout();
    } catch (_) {
      // Even if the server can't be reached, this device still signs out.
    } finally {
      await widget.sessionStore.clear();
      if (mounted) context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final autoDecline = _featuredStatus?.autoDeclineBelowBudget ?? false;

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
                value: _featuredStatus?.acceptingLoads ?? true,
                onChanged: (v) => _updatePreference(acceptingLoads: v),
              ),
              SettingsToggleRow(
                title: l10n.autoDeclineBelowBudgetTitle,
                subtitle: l10n.autoDeclineBelowBudgetSubtitle,
                value: autoDecline,
                onChanged: (v) => _updatePreference(autoDeclineBelowBudget: v),
                isLast: !autoDecline,
              ),
              if (autoDecline)
                SettingsNavRow(
                  title: l10n.floorRateLabel,
                  value: _featuredStatus?.floorRate == null
                      ? l10n.floorRateNotSet
                      : '${_featuredStatus!.displayCurrency} ${_featuredStatus!.floorRate!.toStringAsFixed(0)}',
                  onTap: _openFloorRateDialog,
                  isLast: true,
                ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.fleetDriversSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(title: l10n.manageTrucksLabel, onTap: _openFleet),
              SettingsNavRow(title: l10n.manageDriversLabel, onTap: _openFleet, isLast: true),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.notificationsSectionLabel),
          SettingsCard(
            children: [
              SettingsToggleRow(
                title: l10n.newMatchingLoadsTitle,
                subtitle: l10n.newMatchingLoadsSubtitle,
                value: _wants('new_job_matches'),
                onChanged: (v) => _setNotificationCategory('new_job_matches', v),
              ),
              SettingsToggleRow(
                title: l10n.bidAcceptedOrDeclinedTitle,
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
                title: l10n.driverOffRouteTitle,
                value: _wants('shipment_updates'),
                onChanged: (v) => _setNotificationCategory('shipment_updates', v),
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
                    : l10n.preferredLanesSavedCount(_featuredStatus!.preferredRoutes.length),
                onTap: _featuredStatus == null ? null : _openPreferredRoutes,
              ),
              SettingsNavRow(
                title: l10n.currencyLabel,
                value: _featuredStatus?.displayCurrency ?? 'TZS',
                onTap: _openCurrencyPicker,
              ),
              SettingsNavRow(
                title: l10n.paymentHistoryLabel,
                onTap: _openPaymentHistory,
              ),
              SettingsNavRow(
                title: _featuredStatus?.isFeatured == true
                    ? l10n.cargoMotivesPlusActiveLabel
                    : l10n.cargoMotivesPlusLabel,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompanyFeaturedScreen(repository: widget.featuredRepository),
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
                child: LanguageSwitcherTile(authRepository: widget.authRepository),
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
              ),
              SettingsNavRow(
                title: l10n.howToConnectGps,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GpsConnectionGuideScreen()),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SettingsSectionLabel(l10n.followingSectionLabel),
          SettingsCard(
            children: [
              SettingsNavRow(
                title: l10n.followedCustomersLabel,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FollowedCustomersScreen()),
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
                value: _profile == null ? null : _maskPhone(_profile!.phoneNumber),
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
                        MaterialPageRoute(builder: (_) => CompanyForgotPasswordScreen()),
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
                    builder: (_) => ActiveSessionsScreen(authRepository: widget.authRepository),
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
                  builder: (_) => DeleteAccountScreen(
                    authRepository: widget.authRepository,
                    sessionStore: widget.sessionStore,
                  ),
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

class _FloorRateDialog extends StatefulWidget {
  const _FloorRateDialog({this.initialValue});

  final double? initialValue;

  @override
  State<_FloorRateDialog> createState() => _FloorRateDialogState();
}

class _FloorRateDialogState extends State<_FloorRateDialog> {
  late final _controller = TextEditingController(
    text: widget.initialValue?.toStringAsFixed(0) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0) {
      setState(() => _error = AppLocalizations.of(context)!.enterValidAmount);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.floorRateLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: l10n.floorRateHint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelLabel),
        ),
        ElevatedButton(onPressed: _submit, child: Text(l10n.saveLabel)),
      ],
    );
  }
}
