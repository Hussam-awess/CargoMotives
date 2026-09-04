import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Welcome Screen (AppFlow §1): "I'm a Customer" / "I'm a Transporter
/// Company" — the only fork in the whole app between the two role shells.
///
/// Phone Entry -> OTP -> Profile Setup (the real path into each role home)
/// is Phase 1 work. For now, picking a role goes straight to that role's
/// placeholder home, so the role-aware routing shell (this phase's actual
/// deliverable) is demonstrably wired end to end rather than asserted.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                'Cargo Motives',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'B2B container logistics for Tanzania',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                onPressed: () => context.go('/customer'),
                child: const Text("I'm a Customer"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/company'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("I'm a Transporter Company"),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
