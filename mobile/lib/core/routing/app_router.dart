import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/company/company_home_gate.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../shared/widgets/coming_soon_screen.dart';
import '../auth/session_store.dart';

/// App-wide route table. '/company' is real as of Phase 2 (CompanyHomeGate
/// branches to verification/pending/home internally); '/customer' is still
/// a placeholder pending Phase 4. Both become StatefulShellRoutes with
/// their own nested tabs once each role's real home is built (UI/UX
/// Brief §3).
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/phone-entry',
      builder: (context, state) =>
          PhoneEntryScreen(role: state.extra! as AccountRole),
    ),
    GoRoute(
      path: '/otp',
      builder: (context, state) =>
          OtpScreen(args: state.extra! as OtpScreenArgs),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Customer Home',
        subtitle:
            'Jobs / Post / Profile shell lands starting Phase 4 (Job Posting & Bidding).',
      ),
    ),
    GoRoute(path: '/company', builder: (context, state) => CompanyHomeGate()),
  ],
);
