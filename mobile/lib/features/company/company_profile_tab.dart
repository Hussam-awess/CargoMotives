import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/data/auth_repository.dart';
import '../auth/edit_profile_screen.dart';
import '../support/help_support_screen.dart';
import 'data/company_repository.dart';
import 'data/featured_repository.dart';
import 'featured/featured_screen.dart';
import 'settings/company_settings_screen.dart';

/// A deliberately minimal Profile tab — a real screen, not a placeholder,
/// since the pieces it needs (company name, logout) already exist from
/// Phases 1-2. The fuller profile/settings surface (editing company info,
/// language, etc.) isn't called for by any phase yet, so it isn't built
/// speculatively. Restyled to the mockup's Profile screen using only real
/// data (CompanyRepository.getStatus() + AuthRepository.me()).
class CompanyProfileTab extends StatefulWidget {
  CompanyProfileTab({
    super.key,
    CompanyRepository? companyRepository,
    AuthRepository? authRepository,
    SessionStore? sessionStore,
    CompanyFeaturedRepository? featuredRepository,
  }) : companyRepository = companyRepository ?? CompanyRepository(),
       authRepository = authRepository ?? AuthRepository(),
       sessionStore = sessionStore ?? SessionStore(),
       featuredRepository = featuredRepository ?? CompanyFeaturedRepository();

  final CompanyRepository companyRepository;
  final AuthRepository authRepository;
  final SessionStore sessionStore;
  final CompanyFeaturedRepository featuredRepository;

  @override
  State<CompanyProfileTab> createState() => _CompanyProfileTabState();
}

class _CompanyProfileTabState extends State<CompanyProfileTab> {
  late Future<CompanyVerification?> _verificationFuture;
  late Future<UserProfile> _profileFuture;
  late Future<CompanyFeaturedStatus> _featuredFuture;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _verificationFuture = widget.companyRepository.getStatus();
    _profileFuture = widget.authRepository.me();
    _featuredFuture = widget.featuredRepository.status();
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

  Future<void> _openEditProfile(UserProfile profile) async {
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
    setState(() => _profileFuture = widget.authRepository.me());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<CompanyVerification?>(
            future: _verificationFuture,
            builder: (context, verificationSnapshot) => FutureBuilder<UserProfile>(
              future: _profileFuture,
              builder: (context, profileSnapshot) => FutureBuilder<CompanyFeaturedStatus>(
                future: _featuredFuture,
                builder: (context, featuredSnapshot) => _CompanyCard(
                  verification: verificationSnapshot.data,
                  profile: profileSnapshot.data,
                  isFeatured: featuredSnapshot.data?.isFeatured ?? false,
                  onTap: profileSnapshot.data == null ? null : () => _openEditProfile(profileSnapshot.data!),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account'),
          const SizedBox(height: 8),
          _AccountList(
            rows: [
              _AccountRow(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CompanySettingsScreen(authRepository: widget.authRepository, sessionStore: widget.sessionStore),
                  ),
                ),
              ),
              _AccountRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Cargo Motives Plus',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyFeaturedScreen())),
                highlighted: true,
              ),
              _AccountRow(
                icon: Icons.help_outline,
                label: 'Help & support',
                onTap: () async {
                  final status = await _featuredFuture;
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelpSupportScreen(isFeatured: status.isFeatured)));
                },
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

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.verification, required this.profile, required this.isFeatured, this.onTap});

  final CompanyVerification? verification;
  final UserProfile? profile;

  /// Company Plus status lives on TransporterCompany, never
  /// User.is_featured (that column is Customer Plus only — Phase 10.19
  /// fix: this card previously checked profile?.isFeatured here, which is
  /// always false for a transporter_company account, so the "Cargo
  /// Motives Plus" badge below could never actually show for a real
  /// subscribed company).
  final bool isFeatured;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = verification?.companyName;
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
                  if (verification != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          verification!.isApproved ? Icons.check_circle : Icons.pending_outlined,
                          size: 14,
                          color: verification!.isApproved ? AppColors.ctaBlue : AppColors.statusPending,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          verification!.isApproved ? 'Verified transporter company' : 'Verification pending',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: verification!.isApproved ? AppColors.ctaBlue : AppColors.statusPending,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isFeatured) ...[
                    const SizedBox(height: 5),
                    const Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined, size: 14, color: AppColors.accent),
                        SizedBox(width: 5),
                        Text(
                          'Cargo Motives Plus',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.accent),
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
