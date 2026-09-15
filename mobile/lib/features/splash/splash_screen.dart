import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  // A session check on this machine resolves near-instantly (no network
  // call, just secure storage), which would otherwise make the splash
  // flash by too fast to read — a fixed minimum keeps the brand moment
  // visible regardless of how fast the real check finishes.
  static const _minimumVisible = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final results = await Future.wait([_sessionStore.hasValidSession(), Future<void>.delayed(_minimumVisible)]);
    final hasSession = results[0] as bool;

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
      backgroundColor: AppColors.brandLogoNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(scale: 0.9 + (0.1 * value), child: child),
              ),
              child: Column(
                children: [
                  SizedBox(width: 108, height: 100, child: SvgPicture.asset('assets/brand/logo_mark_reversed.svg')),
                  const SizedBox(height: 24),
                  Text(
                    'CARGO MOTIVES',
                    style: TextStyle(
                      fontFamily: 'Barlow Condensed',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.brandLogoBone,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.appTagline,
                    style: TextStyle(
                      color: AppColors.brandLogoBone.withValues(alpha: 0.75),
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: AppColors.brandLogoOrange),
          ],
        ),
      ),
    );
  }
}
