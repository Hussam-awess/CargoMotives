import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/features/company/company_home_gate.dart';
import 'package:cargo_motives/features/company/data/commission_repository.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_commission_repository.dart';
import '../../support/fake_company_featured_repository.dart';
import '../../support/fake_company_job_repository.dart';
import '../../support/fake_company_repository.dart';
import '../../support/fake_driver_repository.dart';
import '../../support/fake_truck_repository.dart';

Widget _appUnder(
  FakeCompanyRepository repository, {
  FakeTruckRepository? truckRepository,
  FakeDriverRepository? driverRepository,
  FakeCompanyJobRepository? companyJobRepository,
  FakeCommissionRepository? commissionRepository,
  FakeCompanyFeaturedRepository? featuredRepository,
  FakeAuthRepository? authRepository,
}) {
  // The Company Home shell's Profile tab (mounted alongside every other
  // tab by the shell's IndexedStack, not just whichever one is visible)
  // now uses AppLocalizations + LocaleScope for its language switcher —
  // both need to exist here, not just the localization delegates alone.
  return LocaleScope(
    controller: LocaleController(const Locale('en')),
    child: MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: CompanyHomeGate(
        repository: repository,
        truckRepository: truckRepository ?? FakeTruckRepository(),
        driverRepository: driverRepository ?? FakeDriverRepository(),
        companyJobRepository: companyJobRepository ?? FakeCompanyJobRepository(),
        commissionRepository: commissionRepository ?? FakeCommissionRepository(),
        featuredRepository: featuredRepository ?? FakeCompanyFeaturedRepository(),
        authRepository: authRepository ?? FakeAuthRepository(),
      ),
    ),
  );
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

  testWidgets('shows the Company Home shell (Fleet tab) once approved', (
    tester,
  ) async {
    final repository = FakeCompanyRepository(
      onGetStatus: () async => const CompanyVerification(
        status: 'approved',
        rejectedReason: null,
        companyName: 'ABC Logistics',
      ),
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();

    // The shell's bottom nav — real content now (Phase 3), not the old
    // ComingSoonScreen placeholder text. Each label appears twice (that
    // tab's own AppBar title, plus the nav destination label) since
    // IndexedStack keeps every tab mounted simultaneously, not just the
    // visible one.
    expect(find.text('Jobs'), findsWidgets);
    expect(find.text('Fleet'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('shows an on-hold banner across every tab when the company is on hold', (tester) async {
    final repository = FakeCompanyRepository(
      onGetStatus: () async => const CompanyVerification(status: 'approved', rejectedReason: null, companyName: 'ABC Logistics'),
    );

    await tester.pumpWidget(
      _appUnder(
        repository,
        commissionRepository: FakeCommissionRepository(
          onSummary: () async => const CommissionSummary(outstandingBalance: 600000, commissionStanding: 'on_hold', holdThreshold: 500000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account on hold — pay your commission balance to resume bidding.'), findsOneWidget);
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
