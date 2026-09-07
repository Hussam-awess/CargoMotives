import 'package:go_router/go_router.dart';

import '../../features/auth/otp_screen.dart';
import '../../features/auth/phone_entry_screen.dart';
import '../../features/company/company_home_gate.dart';
import '../../features/customer/auth/customer_login_screen.dart';
import '../../features/customer/auth/customer_otp_screen.dart';
import '../../features/customer/auth/customer_register_screen.dart';
import '../../features/customer/auth/data/customer_auth_repository.dart';
import '../../features/customer/customer_home_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../auth/session_store.dart';

/// App-wide route table. Both '/customer' and '/company' are real as of
/// Phase 4 — CompanyHomeGate branches to verification/pending/home
/// internally, CustomerHomeShell is the Jobs/Post/Profile bottom nav
/// directly (a customer never needs Admin approval the way a company
/// does, so there's no equivalent gate to branch through).
///
/// Phase 11: Customer's own auth (register/verify/login) replaces the
/// phone+OTP flow it used to share with Transporter Company — '/phone-
/// entry' and '/otp' are Transporter Company only now.
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
      path: '/customer-register',
      builder: (context, state) => CustomerRegisterScreen(),
    ),
    GoRoute(
      path: '/customer-login',
      builder: (context, state) => CustomerLoginScreen(),
    ),
    GoRoute(
      path: '/customer-otp',
      builder: (context, state) =>
          CustomerOtpScreen(registration: state.extra! as CustomerRegistration),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerHomeShell(),
    ),
    GoRoute(path: '/company', builder: (context, state) => CompanyHomeGate()),
  ],
);
