import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';

/// App-wide route table. Deliberately flat and small for Phase 0 — Splash,
/// Welcome, and one placeholder route per role. As each role's real bottom-
/// nav shell is built (Phase 1+), '/customer' and '/company' become
/// StatefulShellRoutes with their own nested routes, per the Customer
/// (3-tab) / Company (4-tab) structure in the UI/UX Brief §3 — this file is
/// the one place that changes when that happens.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Customer Home',
        subtitle: 'Jobs / Post / Profile shell lands in Phase 1 (Auth).',
      ),
    ),
    GoRoute(
      path: '/company',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Company Home',
        subtitle: 'Jobs / Fleet / Earnings / Profile shell lands in Phase 1 (Auth).',
      ),
    ),
  ],
);
