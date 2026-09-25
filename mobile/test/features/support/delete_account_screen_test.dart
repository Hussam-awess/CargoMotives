import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/support/delete_account_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_session_store.dart';

Widget _appUnder(Widget screen) {
  final router = GoRouter(
    initialLocation: '/delete',
    routes: [
      GoRoute(path: '/delete', builder: (context, state) => screen),
      GoRoute(path: '/welcome', builder: (context, state) => const Text('WELCOME_SCREEN')),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

void main() {
  testWidgets('explains the consequences and requires a password', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _appUnder(DeleteAccountScreen(authRepository: FakeAuthRepository(onDeleteAccount: (_) async => called = true))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('This can\'t be undone.'), findsOneWidget);

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('deleting clears the session and returns to Welcome', (tester) async {
    String? usedPassword;
    final sessionStore = FakeSessionStore();

    await tester.pumpWidget(
      _appUnder(
        DeleteAccountScreen(
          authRepository: FakeAuthRepository(onDeleteAccount: (password) async => usedPassword = password),
          sessionStore: sessionStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(usedPassword, 'secret123');
    expect(find.text('WELCOME_SCREEN'), findsOneWidget);
  });

  testWidgets('shows why the server refused, and stays put', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        DeleteAccountScreen(
          authRepository: FakeAuthRepository(
            onDeleteAccount: (_) async => throw ApiException(
              'You still have pending bids. Withdraw them before deleting your account.',
              fieldErrors: {
                'account': ['You still have pending bids. Withdraw them before deleting your account.'],
              },
            ),
          ),
          sessionStore: FakeSessionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();

    expect(find.text('You still have pending bids. Withdraw them before deleting your account.'), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
  });
}
