import 'package:cargo_motives/features/company/company_verification_screen.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_company_repository.dart';

void main() {
  testWidgets('shows required-field validation errors and does not submit', (
    tester,
  ) async {
    var submitCalled = false;
    final repository = FakeCompanyRepository(
      onSubmit: (submission) async {
        submitCalled = true;
        return const CompanyVerification(
          status: 'pending',
          rejectedReason: null,
          companyName: 'x',
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: CompanyVerificationScreen(repository: repository)),
    );
    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);
    expect(submitCalled, isFalse);
  });

  testWidgets('shows the rejection reason banner when resubmitting', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyVerificationScreen(
          repository: FakeCompanyRepository(),
          rejectedReason: 'Documents were blurry.',
        ),
      ),
    );

    expect(find.text('Previous submission rejected'), findsOneWidget);
    expect(find.text('Documents were blurry.'), findsOneWidget);
  });

  testWidgets(
    'filling text fields but leaving attachments empty shows an attachment error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CompanyVerificationScreen(repository: FakeCompanyRepository()),
        ),
      );

      for (final field in find.byType(TextField).evaluate()) {
        final widget = field.widget as TextField;
        final label = widget.decoration?.labelText ?? '';
        // The company email field validates format now — every other
        // field accepts any non-empty text, so a plain string still works
        // for those.
        final value = label.startsWith('Company email')
            ? 'test@example.com'
            : 'test value';
        await tester.enterText(find.byWidget(field.widget), value);
      }

      await tester.ensureVisible(find.text('Submit for review'));
      await tester.tap(find.text('Submit for review'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Please attach the company registration certificate, TIN certificate, and ID document.',
        ),
        findsOneWidget,
      );
    },
  );
}
