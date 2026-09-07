import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/localization/language_menu_button.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/truck_road_animation.dart';
import '../../l10n/generated/app_localizations.dart';

/// Welcome Screen (AppFlow §1): "I'm a Customer" / "I'm a Transporter
/// Company" — the only fork in the whole app between the two role shells.
/// Transporter Company starts the phone Entry -> OTP flow (Phase 1);
/// Customer goes to its own email+password sign-up (Phase 11) — see
/// CustomerRegisterScreen for why the two roles diverge here.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: const LanguageMenuButton(),
              ),
              const Spacer(flex: 1),
              Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              const TruckRoadAnimation(),
              const Spacer(flex: 2),
              ElevatedButton(
                onPressed: () => context.go('/customer-register'),
                child: Text(l10n.iAmCustomer),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push(
                  '/phone-entry',
                  extra: AccountRole.transporterCompany,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.iAmTransporterCompany),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
