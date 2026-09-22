import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/customer_profile_tab.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_session_store.dart';

Widget _appUnder(Widget home) {
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}

/// A GoRouter-backed variant — only the logout test below needs real
/// navigation (`_logout()` calls `context.go('/welcome')` on success).
Widget _appUnderWithRouter(Widget profileTab) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (context, state) => profileTab),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const Text('WELCOME_SCREEN'),
      ),
    ],
  );
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    ),
  );
}

void main() {
  testWidgets(
    'logging out from the Profile tab asks for confirmation and cancelling stays put',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerProfileTab(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Log out'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerProfileTab), findsOneWidget);
    },
  );

  testWidgets(
    'confirming logout from the Profile tab actually logs out and navigates to Welcome',
    (tester) async {
      var loggedOut = false;

      await tester.pumpWidget(
        _appUnderWithRouter(
          CustomerProfileTab(
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Amina Hassan',
                companyName: null,
                isFeatured: false,
              ),
              onLogout: () async => loggedOut = true,
            ),
            sessionStore: FakeSessionStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Log out'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      // Two "Log out" texts now exist: the dialog's confirm button and the
      // Profile tab's own button underneath — the confirm action is last.
      await tester.tap(find.text('Log out').last);
      await tester.pumpAndSettle();

      expect(loggedOut, isTrue);
      expect(find.text('WELCOME_SCREEN'), findsOneWidget);
    },
  );
}
