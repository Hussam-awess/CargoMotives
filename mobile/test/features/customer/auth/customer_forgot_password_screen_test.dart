import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/customer/auth/customer_forgot_password_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_auth_repository.dart';

Widget _appUnder({required FakeCustomerAuthRepository repository}) {
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: CustomerForgotPasswordScreen(repository: repository),
    ),
  );
}

void main() {
  testWidgets('requires an email before requesting a code', (tester) async {
    var requestCalled = false;
    await tester.pumpWidget(_appUnder(repository: FakeCustomerAuthRepository(onRequestPasswordReset: (_) async => requestCalled = true)));

    await tester.tap(find.text('Send reset code'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(requestCalled, isFalse);
  });

  testWidgets('requesting a code advances to the reset-password step', (tester) async {
    await tester.pumpWidget(_appUnder(repository: FakeCustomerAuthRepository()));

    await tester.enterText(find.byType(TextField).first, 'amina@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsWidgets);
    expect(find.text('New password'), findsOneWidget);
  });

  testWidgets('a full successful reset shows the success step', (tester) async {
    String? capturedEmail;
    String? capturedCode;
    String? capturedPassword;
    await tester.pumpWidget(
      _appUnder(
        repository: FakeCustomerAuthRepository(
          onConfirmPasswordReset: (email, code, password) async {
            capturedEmail = email;
            capturedCode = code;
            capturedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'amina@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '123456');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(capturedEmail, 'amina@example.com');
    expect(capturedCode, '123456');
    expect(capturedPassword, 'newpassword1');
    expect(find.text("You can now log in with your new password."), findsOneWidget);
  });

  testWidgets('a wrong code surfaces the server error', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        repository: FakeCustomerAuthRepository(
          onConfirmPasswordReset: (email, code, password) async => throw ApiException(
            'That code is incorrect.',
            fieldErrors: {
              'code': ['That code is incorrect.'],
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'amina@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '000000');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword1');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
  });
}
