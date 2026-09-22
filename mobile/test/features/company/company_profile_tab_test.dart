import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/company/company_profile_tab.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_company_featured_repository.dart';
import '../../support/fake_company_repository.dart';
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
  /// Phase 10.19 bug fix: the Plus badge on Company's own Profile card must
  /// be driven by TransporterCompany.is_featured (via
  /// CompanyFeaturedRepository), never by User.is_featured — that column is
  /// a Customer-only concept and is always false for a company account, so
  /// a genuinely-subscribed company's badge previously could never show.
  testWidgets('shows the Cargo Motives Plus badge for a featured company', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appUnder(
        CompanyProfileTab(
          companyRepository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'Test Transport Co',
            ),
          ),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: null,
              companyName: 'Test Transport Co',
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
          ),
          featuredRepository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: true,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Appears twice: the profile-card badge (the fix) plus the always-shown "Cargo Motives Plus" menu row.
    expect(find.text('Cargo Motives Plus'), findsNWidgets(2));
  });

  testWidgets('shows no Plus badge for a non-featured company', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CompanyProfileTab(
          companyRepository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'Test Transport Co',
            ),
          ),
          authRepository: FakeAuthRepository(
            onMe: () async => const UserProfile(
              fullName: null,
              companyName: 'Test Transport Co',
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
          ),
          featuredRepository: FakeCompanyFeaturedRepository(
            onStatus: () async => const CompanyFeaturedStatus(
              isFeatured: false,
              featuredUntil: null,
              price: 50000,
              durationDays: 30,
              preferredRoutes: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the always-shown menu row — no badge on the profile card.
    expect(find.text('Cargo Motives Plus'), findsOneWidget);
  });

  testWidgets(
    'logging out from the Profile tab asks for confirmation and cancelling stays put',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CompanyProfileTab(
            companyRepository: FakeCompanyRepository(
              onGetStatus: () async => const CompanyVerification(
                status: 'approved',
                rejectedReason: null,
                companyName: 'Test Transport Co',
              ),
            ),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: 'Test Transport Co',
                isFeatured: false,
                phoneNumber: '+255712345678',
              ),
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(CompanyProfileTab), findsOneWidget);
    },
  );

  testWidgets(
    'confirming logout from the Profile tab actually logs out and navigates to Welcome',
    (tester) async {
      var loggedOut = false;

      await tester.pumpWidget(
        _appUnderWithRouter(
          CompanyProfileTab(
            companyRepository: FakeCompanyRepository(
              onGetStatus: () async => const CompanyVerification(
                status: 'approved',
                rejectedReason: null,
                companyName: 'Test Transport Co',
              ),
            ),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: null,
                companyName: 'Test Transport Co',
                isFeatured: false,
                phoneNumber: '+255712345678',
              ),
              onLogout: () async => loggedOut = true,
            ),
            featuredRepository: FakeCompanyFeaturedRepository(),
            sessionStore: FakeSessionStore(),
          ),
        ),
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
