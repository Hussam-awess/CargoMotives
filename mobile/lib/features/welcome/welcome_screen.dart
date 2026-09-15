import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/localization/language_menu_button.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Welcome / Role selection (AppFlow §1; design-import restyle): tap to
/// select Customer or Transporter, then CONTINUE — replacing the earlier
/// two-direct-buttons layout with the mockup's select-then-confirm pattern.
/// Transporter Company starts the phone Entry -> OTP flow (Phase 1);
/// Customer goes to its own email+password sign-up (Phase 11) — see
/// CustomerRegisterScreen for why the two roles diverge here.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  AccountRole? _selectedRole;

  void _continue() {
    switch (_selectedRole) {
      case AccountRole.customer:
        context.push('/customer-register');
      case AccountRole.transporterCompany:
        context.push('/phone-entry', extra: AccountRole.transporterCompany);
      case null:
        break;
    }
  }

  void _logIn() {
    if (_selectedRole == AccountRole.transporterCompany) {
      context.push('/company-login');
    } else {
      context.push('/customer-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // SingleChildScrollView, not just Padding+Column: on a short viewport
      // (a small phone, or a keyboard eating half the screen) an unscrolled
      // Column here silently overflows — see PhoneEntryScreen's build()
      // comment for the same lesson learned there first.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.topRight, child: const LanguageMenuButton()),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 46,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: AppColors.brandLogoNavy, borderRadius: BorderRadius.circular(6)),
                  child: SvgPicture.asset('assets/brand/logo_mark_reversed.svg'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.welcomeToCargoMotives,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
              Text(l10n.roleSelectionSubtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 15)),
              const SizedBox(height: 24),
              _RoleCard(
                icon: Icons.person_outline,
                title: l10n.customerRoleTitle,
                description: l10n.customerRoleDescription,
                selected: _selectedRole == AccountRole.customer,
                onTap: () => setState(() => _selectedRole = AccountRole.customer),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.local_shipping_outlined,
                title: l10n.transporterRoleTitle,
                description: l10n.transporterRoleDescription,
                selected: _selectedRole == AccountRole.transporterCompany,
                onTap: () => setState(() => _selectedRole = AccountRole.transporterCompany),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _selectedRole == null ? null : _continue,
                child: Text(l10n.continueLabel.toUpperCase()),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(onPressed: _logIn, child: Text('${l10n.alreadyHaveAnAccount} ${l10n.logIn}')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.ctaBlue : AppColors.border, width: selected ? 1.5 : 1),
          color: selected ? AppColors.ctaBlue.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.brandChip, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21)),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? AppColors.ctaBlue : AppColors.border, width: 1.5),
                          color: selected ? AppColors.ctaBlue : Colors.transparent,
                        ),
                        child: selected ? const Icon(Icons.circle, color: Colors.white, size: 6) : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(description, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
