import 'package:cargo_motives/features/company/company_home_gate.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_company_repository.dart';

Widget _appUnder(FakeCompanyRepository repository) {
  return MaterialApp(home: CompanyHomeGate(repository: repository));
}

void main() {
  testWidgets(
    'shows the verification form when nothing has been submitted yet',
    (tester) async {
      final repository = FakeCompanyRepository(onGetStatus: () async => null);

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      expect(find.text('Verify your company'), findsOneWidget);
      expect(find.text('Company Info'), findsOneWidget);
      expect(find.text('Representative Info'), findsOneWidget);
    },
  );

  testWidgets('shows a pending-review screen while under review', (
    tester,
  ) async {
    final repository = FakeCompanyRepository(
      onGetStatus: () async => const CompanyVerification(
        status: 'pending',
        rejectedReason: null,
        companyName: 'ABC Logistics',
      ),
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();

    expect(find.text('ABC Logistics is under review'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets(
    'a flagged_duplicate status is treated the same as pending review',
    (tester) async {
      final repository = FakeCompanyRepository(
        onGetStatus: () async => const CompanyVerification(
          status: 'flagged_duplicate',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      expect(find.text('ABC Logistics is under review'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the verification form with the rejection reason when rejected',
    (tester) async {
      final repository = FakeCompanyRepository(
        onGetStatus: () async => const CompanyVerification(
          status: 'rejected',
          rejectedReason: 'Business license photo is unreadable.',
          companyName: 'ABC Logistics',
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      expect(find.text('Verify your company'), findsOneWidget);
      expect(find.text('Previous submission rejected'), findsOneWidget);
      expect(
        find.text('Business license photo is unreadable.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows Company Home once approved', (tester) async {
    final repository = FakeCompanyRepository(
      onGetStatus: () async => const CompanyVerification(
        status: 'approved',
        rejectedReason: null,
        companyName: 'ABC Logistics',
      ),
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();

    expect(find.text('Company Home'), findsOneWidget);
  });

  testWidgets('"Check again" refetches the status', (tester) async {
    var callCount = 0;
    final repository = FakeCompanyRepository(
      onGetStatus: () async {
        callCount++;
        return const CompanyVerification(
          status: 'pending',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        );
      },
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();
    expect(callCount, 1);

    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(callCount, 2);
  });
}
