import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/company/auth/company_forgot_password_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_auth_repository.dart';

Widget _appUnder({required FakeAuthRepository repository}) {
  // The AppBar carries a LanguageMenuButton, which reads LocaleScope —
  // needs an ancestor here or it null-check-fails.
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: CompanyForgotPasswordScreen(repository: repository),
    ),
  );
}

void main() {
  testWidgets('requires a phone number before requesting a code', (tester) async {
    var requestCalled = false;
    await tester.pumpWidget(_appUnder(repository: FakeAuthRepository(onRequestPasswordReset: (_) async => requestCalled = true)));

    await tester.tap(find.text('Send reset code'));
    await tester.pump();

    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(requestCalled, isFalse);
  });

  testWidgets('requesting a code advances to the reset-password step', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeAuthRepository()));

    await tester.enterText(find.byType(TextField).first, '0712345678');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsWidgets);
    expect(find.text('New password'), findsOneWidget);
  });

  testWidgets('rejects mismatched passwords without calling the repository', (tester) async {
    var confirmCalled = false;
    await tester.pumpWidget(
      _appUnder(repository: FakeAuthRepository(onConfirmPasswordReset: (phone, code, password) async => confirmCalled = true)),
    );

    await tester.enterText(find.byType(TextField).first, '0712345678');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(2), 'different');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pump();

    expect(find.text("Passwords don't match."), findsOneWidget);
    expect(confirmCalled, isFalse);
  });

  testWidgets('a wrong code surfaces the server error', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        repository: FakeAuthRepository(
          onConfirmPasswordReset: (phone, code, password) async => throw ApiException(
            'That code is incorrect.',
            fieldErrors: {
              'code': ['That code is incorrect.'],
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '0712345678');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '000000');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
  });

  testWidgets('a full successful reset shows the success step', (tester) async {
    String? capturedPhone;
    String? capturedCode;
    String? capturedPassword;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeAuthRepository(
          onConfirmPasswordReset: (phone, code, password) async {
            capturedPhone = phone;
            capturedCode = code;
            capturedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '0712345678');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(capturedPhone, '0712345678');
    expect(capturedCode, '123456');
    expect(capturedPassword, 'newpassword1');
    expect(find.text("You can now log in with your new password."), findsOneWidget);
    expect(find.text('Back to login'), findsOneWidget);
  });

  testWidgets('"Use a different number" returns to step 1', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeAuthRepository()));

    await tester.enterText(find.byType(TextField).first, '0712345678');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use a different number'));
    await tester.pumpAndSettle();

    expect(find.text('Send reset code'), findsOneWidget);
  });
}
