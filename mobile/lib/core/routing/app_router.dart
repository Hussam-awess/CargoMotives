import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/company/company_home_gate.dart';
import '../../features/customer/customer_home_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../auth/session_store.dart';

/// App-wide route table. Both '/customer' and '/company' are real as of
/// Phase 4 — CompanyHomeGate branches to verification/pending/home
/// internally, CustomerHomeShell is the Jobs/Post/Profile bottom nav
/// directly (a customer never needs Admin approval the way a company
/// does, so there's no equivalent gate to branch through).
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
      builder: (context, state) => const CustomerHomeShell(),
    ),
    GoRoute(path: '/company', builder: (context, state) => CompanyHomeGate()),
  ],
);
