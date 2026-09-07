import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Welcome Screen (AppFlow §1): "I'm a Customer" / "I'm a Transporter
/// Company" — the only fork in the whole app between the two role shells.
/// Picking one starts the shared Phone Entry -> OTP flow (Phase 1).
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
              const Spacer(flex: 2),
              Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                l10n.appTagline,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () =>
                    context.push('/phone-entry', extra: AccountRole.customer),
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
