import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/support/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  testWidgets(
    'submitting valid fields calls changePassword and pops back to the previous screen',
    (tester) async {
      String? capturedCurrent;
      String? capturedNew;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangePasswordScreen(
                        authRepository: FakeAuthRepository(
                          onChangePassword: (currentPassword, password) async {
                            capturedCurrent = currentPassword;
                            capturedNew = password;
                          },
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'old-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'new-password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'new-password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
      await tester.pumpAndSettle();

      expect(capturedCurrent, 'old-password');
      expect(capturedNew, 'new-password123');
      expect(find.text('Password changed.'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsNothing);
    },
  );

  testWidgets(
    'a mismatched confirmation is rejected before calling the repository',
    (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(
            authRepository: FakeAuthRepository(
              onChangePassword: (_, _) async => called = true,
            ),
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'old-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'new-password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'does-not-match',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
      await tester.pump();

      expect(called, isFalse);
      expect(find.text('Passwords do not match'), findsOneWidget);
    },
  );

  testWidgets('the server error for the wrong current password is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordScreen(
          authRepository: FakeAuthRepository(
            onChangePassword: (_, _) async => throw ApiException(
              'That password is incorrect.',
              fieldErrors: {
                'current_password': ['That password is incorrect.'],
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'wrong-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'new-password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'new-password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save password'));
    await tester.pumpAndSettle();

    expect(find.text('That password is incorrect.'), findsOneWidget);
  });

  testWidgets('hides the forgot-password link when no callback is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordScreen(authRepository: FakeAuthRepository()),
      ),
    );

    expect(find.text('or forgot password?'), findsNothing);
  });

  testWidgets(
    'shows the forgot-password link and calls the given callback when tapped',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ChangePasswordScreen(
            authRepository: FakeAuthRepository(),
            onForgotPassword: () => tapped = true,
          ),
        ),
      );

      expect(find.text('or forgot password?'), findsOneWidget);

      await tester.tap(find.text('or forgot password?'));
      await tester.pump();

      expect(tapped, isTrue);
    },
  );
}
