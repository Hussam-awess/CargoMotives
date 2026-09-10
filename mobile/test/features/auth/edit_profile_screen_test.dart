import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/auth/edit_profile_screen.dart';
import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

const _profile = UserProfile(fullName: 'Amina Hassan', companyName: null, isFeatured: false, email: 'amina@example.com');

void main() {
  testWidgets('saving a new name calls updateFullName and shows it', (tester) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: _profile,
          credential: ProfileCredential.email,
          authRepository: FakeAuthRepository(
            onUpdateFullName: (name) async {
              captured = name;
              return UserProfile(fullName: name, companyName: null, isFeatured: false, email: _profile.email);
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Amina J. Hassan');
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    expect(captured, 'Amina J. Hassan');
    expect(find.text('Name updated.'), findsOneWidget);
  });

  testWidgets('changing the email walks through send-code then confirm', (tester) async {
    String? requestedEmail;
    String? confirmedCode;
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: _profile,
          credential: ProfileCredential.email,
          authRepository: FakeAuthRepository(
            onRequestEmailChange: (email) async {
              requestedEmail = email;
            },
            onConfirmEmailChange: (email, code) async {
              confirmedCode = code;
              return UserProfile(fullName: _profile.fullName, companyName: null, isFeatured: false, email: email);
            },
          ),
        ),
      ),
    );

    expect(find.text('amina@example.com'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'new@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'new@example.com');
    expect(find.text('We sent a code to new@example.com.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmedCode, '123456');
    expect(find.text('Email updated.'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
  });

  testWidgets('an incorrect code shows the server error and stays on the code step', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: _profile,
          credential: ProfileCredential.email,
          authRepository: FakeAuthRepository(
            onRequestEmailChange: (_) async {},
            onConfirmEmailChange: (_, _) async => throw ApiException(
              'That code is incorrect.',
              fieldErrors: {
                'code': ['That code is incorrect.'],
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'new@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('That code is incorrect.'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('showName=false hides the name section (Company)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: const UserProfile(fullName: null, companyName: null, isFeatured: false, phoneNumber: '+255712345678'),
          credential: ProfileCredential.phone,
          showName: false,
          authRepository: FakeAuthRepository(),
        ),
      ),
    );

    expect(find.text('Full name'), findsNothing);
    expect(find.text('Save name'), findsNothing);
    expect(find.text('+255712345678'), findsOneWidget);
  });
}
