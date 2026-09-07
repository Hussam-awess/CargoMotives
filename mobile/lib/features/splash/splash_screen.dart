import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Splash Screen (AppFlow §1): checks for a valid session and routes
/// straight to that role's home, or to Welcome if there isn't one.
///
/// There's no real session yet (Auth lands in Phase 1), so this always
/// resolves to Welcome today — but it goes through SessionStore for real,
/// not a stub, so the redirect logic doesn't need rewriting once login
/// exists.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _sessionStore = SessionStore();

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final hasSession = await _sessionStore.hasValidSession();

    if (!mounted) return;

    if (!hasSession) {
      context.go('/welcome');
      return;
    }

    final role = await _sessionStore.getRole();
    if (!mounted) return;

    switch (role) {
      case AccountRole.customer:
        context.go('/customer');
      case AccountRole.transporterCompany:
        context.go('/company');
      case null:
        context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
