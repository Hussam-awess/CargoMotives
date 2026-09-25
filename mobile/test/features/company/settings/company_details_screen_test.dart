import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/features/company/settings/company_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_company_repository.dart';

void main() {
  testWidgets('shows the company\'s real submitted details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDetailsScreen(
          repository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'ABC Logistics',
              registrationNumber: 'REG-1234',
              tin: 'TIN-5678',
              physicalAddress: 'Kariakoo, Dar es Salaam',
              companyPhone: '+255700111002',
              companyEmail: 'ops@abclogistics.test',
              repFullName: 'Amina Hassan',
              repPosition: 'Operations Manager',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Logistics'), findsOneWidget);
    expect(find.text('REG-1234'), findsOneWidget);
    expect(find.text('TIN-5678'), findsOneWidget);
    expect(find.text('Kariakoo, Dar es Salaam'), findsOneWidget);
    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('Operations Manager'), findsOneWidget);
  });

  testWidgets('shows an error state when the company has no verification yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDetailsScreen(repository: FakeCompanyRepository(onGetStatus: () async => null)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your company details.'), findsOneWidget);
  });

  testWidgets('shows "Not set" and a Set action when no pin exists yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDetailsScreen(
          repository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'ABC Logistics',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not set'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Set'), findsOneWidget);
  });

  testWidgets('shows "Pin set" and an Edit action once a pin exists', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDetailsScreen(
          repository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'ABC Logistics',
              physicalLat: -6.8161,
              physicalLng: 39.2803,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pin set'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
  });

  testWidgets('tapping Set opens the location picker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CompanyDetailsScreen(
          repository: FakeCompanyRepository(
            onGetStatus: () async => const CompanyVerification(
              status: 'approved',
              rejectedReason: null,
              companyName: 'ABC Logistics',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Set'));
    await tester.pumpAndSettle();

    expect(find.text('Company location'), findsOneWidget);
  });
}
