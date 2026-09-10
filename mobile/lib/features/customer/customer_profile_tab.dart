import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../auth/edit_profile_screen.dart';
import '../support/help_support_screen.dart';
import 'addresses/saved_addresses_screen.dart';
import 'featured/featured_screen.dart';
import 'payments/payment_history_screen.dart';
import 'settings/customer_settings_screen.dart';
import 'shipments/customer_shipments_screen.dart';

/// A deliberately minimal Profile tab, same scope call as
/// CompanyProfileTab: real (working logout), not a placeholder, but no
/// speculative settings/editing UI beyond what's actually needed yet.
/// Restyled to the mockup's Profile screen using only real data — no
/// fabricated shipment count, rating, or "years on platform" (this app
/// tracks none of those for a Customer), and no Saved addresses/Payment
/// history rows (no such features exist yet).
class CustomerProfileTab extends StatefulWidget {
  CustomerProfileTab({super.key, AuthRepository? authRepository, SessionStore? sessionStore})
    : authRepository = authRepository ?? AuthRepository(),
      sessionStore = sessionStore ?? SessionStore();

  final AuthRepository authRepository;
  final SessionStore sessionStore;

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  bool _isLoggingOut = false;
  late Future<UserProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.authRepository.me();
  }

  void _refresh() {
    setState(() => _profileFuture = widget.authRepository.me());
  }

  Future<void> _openEditProfile(UserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: profile, credential: ProfileCredential.email, authRepository: widget.authRepository),
      ),
    );
    _refresh();
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<UserProfile>(
            future: _profileFuture,
            builder: (context, snapshot) =>
                _ProfileCard(profile: snapshot.data, onTap: snapshot.data == null ? null : () => _openEditProfile(snapshot.data!)),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account'),
          const SizedBox(height: 8),
          _AccountList(
            rows: [
              _AccountRow(
                icon: Icons.local_shipping_outlined,
                label: 'My shipments',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerShipmentsScreen())),
              ),
              _AccountRow(
                icon: Icons.payments_outlined,
                label: 'Payment history',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentHistoryScreen())),
              ),
              _AccountRow(
                icon: Icons.place_outlined,
                label: 'Saved addresses',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedAddressesScreen())),
              ),
              _AccountRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerSettingsScreen(authRepository: widget.authRepository, sessionStore: widget.sessionStore),
                  ),
                ),
              ),
              _AccountRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Cargo Motives Plus',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerFeaturedScreen())),
                highlighted: true,
              ),
              _AccountRow(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoggingOut ? null : _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusError,
                side: const BorderSide(color: Color(0xFFE8CFC8)),
              ),
              child: _isLoggingOut
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, this.onTap});

  final UserProfile? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName?.trim();
    final initial = (name == null || name.isEmpty) ? '?' : name[0].toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(fontFamily: 'Barlow Condensed', fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.ctaBlue),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? '—',
                    style: const TextStyle(
                      fontFamily: 'Barlow Condensed',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (profile?.phoneNumber != null)
                    Text(profile!.phoneNumber!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  if (profile?.email != null) Text(profile!.email!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  if (profile?.isFeatured == true) ...[
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppColors.ctaBlue),
                        SizedBox(width: 5),
                        Text(
                          'Cargo Motives Plus',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ctaBlue),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLabel, letterSpacing: 0.7),
    );
  }
}

class _AccountRow {
  const _AccountRow({required this.icon, required this.label, required this.onTap, this.highlighted = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
}

class _AccountList extends StatelessWidget {
  const _AccountList({required this.rows});

  final List<_AccountRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: rows[i].onTap,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: rows[i].highlighted ? const Color(0xFFFCF8EE) : null,
                  border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.background)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: Icon(rows[i].icon, size: 15, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(rows[i].label, style: const TextStyle(fontSize: 14.5))),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
