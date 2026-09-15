import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/auth/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

const _profile = UserProfile(
  fullName: 'Amina Hassan',
  companyName: null,
  isFeatured: false,
  email: 'amina@example.com',
  phoneNumber: '+255712345678',
);

void main() {
  testWidgets('saving a new name calls updateFullName and shows it', (
    tester,
  ) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(
          profile: _profile,
          credential: ProfileCredential.email,
          authRepository: FakeAuthRepository(
            onUpdateFullName: (name) async {
              captured = name;
              return UserProfile(
                fullName: name,
                companyName: null,
                isFeatured: false,
                email: _profile.email,
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('nameField')),
      'Amina J. Hassan',
    );
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    expect(captured, 'Amina J. Hassan');
    expect(find.text('Name updated.'), findsOneWidget);
  });

  testWidgets('changing the email walks through send-code then confirm', (
    tester,
  ) async {
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
              return UserProfile(
                fullName: _profile.fullName,
                companyName: null,
                isFeatured: false,
                email: email,
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('amina@example.com'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('credentialNewValueField')),
      'new@example.com',
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(requestedEmail, 'new@example.com');
    expect(find.text('We sent a code to new@example.com.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('credentialCodeField')),
      '123456',
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(confirmedCode, '123456');
    expect(find.text('Email updated.'), findsOneWidget);
    expect(find.text('new@example.com'), findsOneWidget);
  });

  testWidgets(
    'an incorrect code shows the server error and stays on the code step',
    (tester) async {
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
      await tester.enterText(
        find.byKey(const Key('credentialNewValueField')),
        'new@example.com',
      );
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('credentialCodeField')),
        '000000',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('That code is incorrect.'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    },
  );

  testWidgets(
    'a Company profile shows the name section too (the account holder, not the business)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: const UserProfile(
              fullName: 'Juma Mrisho',
              companyName: null,
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
            credential: ProfileCredential.phone,
            authRepository: FakeAuthRepository(),
          ),
        ),
      );

      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Save name'), findsOneWidget);
      expect(find.text('+255712345678'), findsOneWidget);
    },
  );

  testWidgets(
    'a Customer can update their phone number (the non-credential field) with no code',
    (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: _profile,
            credential: ProfileCredential.email,
            authRepository: FakeAuthRepository(
              onUpdatePhone: (phone) async {
                captured = phone;
                return UserProfile(
                  fullName: _profile.fullName,
                  companyName: null,
                  isFeatured: false,
                  phoneNumber: phone,
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Phone number'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('secondaryField')),
        '+255700111000',
      );
      await tester.ensureVisible(find.text('Save phone number'));
      await tester.tap(find.text('Save phone number'));
      await tester.pumpAndSettle();

      expect(captured, '+255700111000');
      expect(find.text('Phone number updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'a Company can update their email (the non-credential field) with no code',
    (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: const UserProfile(
              fullName: 'Juma Mrisho',
              companyName: null,
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
            credential: ProfileCredential.phone,
            authRepository: FakeAuthRepository(
              onUpdateEmail: (email) async {
                captured = email;
                return const UserProfile(
                  fullName: 'Juma Mrisho',
                  companyName: null,
                  isFeatured: false,
                  email: 'juma@example.com',
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('secondaryField')),
        'juma@example.com',
      );
      await tester.ensureVisible(find.text('Save email'));
      await tester.tap(find.text('Save email'));
      await tester.pumpAndSettle();

      expect(captured, 'juma@example.com');
      expect(find.text('Email updated.'), findsOneWidget);
    },
  );

  testWidgets(
    'a Customer sees a Business details section; a Company does not',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: _profile,
            credential: ProfileCredential.email,
            authRepository: FakeAuthRepository(),
          ),
        ),
      );
      expect(find.text('Business details (optional)'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: const UserProfile(
              fullName: 'Juma Mrisho',
              companyName: null,
              isFeatured: false,
              phoneNumber: '+255712345678',
            ),
            credential: ProfileCredential.phone,
            authRepository: FakeAuthRepository(),
          ),
        ),
      );
      expect(find.text('Business details (optional)'), findsNothing);
    },
  );

  testWidgets(
    'saving business details calls updateBusinessIdentity with the new company name',
    (tester) async {
      String? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(
            profile: _profile,
            credential: ProfileCredential.email,
            authRepository: FakeAuthRepository(
              onUpdateBusinessIdentity: (companyName, logo) async {
                captured = companyName;
                return UserProfile(
                  fullName: _profile.fullName,
                  companyName: companyName,
                  isFeatured: false,
                );
              },
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('companyNameField')));
      await tester.enterText(
        find.byKey(const Key('companyNameField')),
        'Amina Logistics',
      );
      await tester.ensureVisible(find.text('Save business details'));
      await tester.tap(find.text('Save business details'));
      await tester.pumpAndSettle();

      expect(captured, 'Amina Logistics');
      expect(find.text('Business details updated.'), findsOneWidget);
    },
  );
}
