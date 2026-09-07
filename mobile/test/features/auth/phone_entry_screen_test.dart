import 'package:cargo_motives/core/auth/session_store.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/phone_entry_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_auth_repository.dart';

Widget _appUnder({required FakeAuthRepository repository}) {
  final router = GoRouter(
    initialLocation: '/phone-entry',
    routes: [
      GoRoute(
        path: '/phone-entry',
        builder: (context, state) => PhoneEntryScreen(
          role: AccountRole.customer,
          authRepository: repository,
        ),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) =>
            Text('OTP_SCREEN:${(state.extra! as OtpScreenArgs).phoneNumber}'),
      ),
    ],
  );

  // PhoneEntryScreen's AppBar carries a LanguageMenuButton (Phase 11),
  // which reads LocaleScope — needs an ancestor here or it null-check-fails.
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
    'shows a validation error and does not call the repository when phone is empty',
    (tester) async {
      var requestCalled = false;
      final repository = FakeAuthRepository(
        onRequestOtp: (phone, role) async {
          requestCalled = true;
        },
      );

      await tester.pumpWidget(_appUnder(repository: repository));
      await tester.tap(find.text('Send code'));
      await tester.pump();

      expect(find.text('Enter your phone number.'), findsOneWidget);
      expect(requestCalled, isFalse);
    },
  );

  testWidgets('requests an OTP and navigates to the OTP screen on success', (
    tester,
  ) async {
    final repository = FakeAuthRepository(onRequestOtp: (phone, role) async {});

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), '0712345678');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('OTP_SCREEN:0712345678'), findsOneWidget);
  });

  testWidgets('shows the server error message when the request fails', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      onRequestOtp: (phone, role) async {
        throw ApiException(
          'Invalid phone number.',
          statusCode: 422,
          fieldErrors: {
            'phone_number': ['Invalid phone number.'],
          },
        );
      },
    );

    await tester.pumpWidget(_appUnder(repository: repository));
    await tester.enterText(find.byType(TextField), 'not-a-phone');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid phone number.'), findsOneWidget);
    // Should NOT have navigated away on failure.
    expect(find.text('Phone number'), findsOneWidget);
  });
}
