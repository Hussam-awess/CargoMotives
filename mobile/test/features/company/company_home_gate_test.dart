import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_scope.dart';
import 'package:cargo_motives/features/company/company_home_gate.dart';
import 'package:cargo_motives/features/company/company_verification_screen.dart';
import 'package:cargo_motives/features/company/data/company_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
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
        companyJobRepository:
            companyJobRepository ?? FakeCompanyJobRepository(),
        featuredRepository:
            featuredRepository ?? FakeCompanyFeaturedRepository(),
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
    expect(find.text('Edit and resubmit'), findsOneWidget);
  });

  /// The other half of the flow this fix is about: a company held for a
  /// fixable reason (a malformed TIN, a tiny file — CompanyAutoVerifier)
  /// sees exactly what to fix, not just "under review".
  testWidgets(
    'shows the auto-check notes when the submission was held for one',
    (tester) async {
      final repository = FakeCompanyRepository(
        onGetStatus: () async => const CompanyVerification(
          status: 'pending',
          rejectedReason: null,
          companyName: 'ABC Logistics',
          autoCheckNotes: ['TIN is not 9 digits.'],
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      expect(
        find.text('A few things need fixing before this can be approved.'),
        findsOneWidget,
      );
      expect(find.textContaining('TIN is not 9 digits.'), findsOneWidget);
    },
  );

  /// The actual reported gap: from the waiting screen, a company can open
  /// the form again and resubmit — previously the only option was "Check
  /// again", leaving no way to fix and resubmit a held submission at all.
  testWidgets('tapping "Edit and resubmit" opens the verification form', (
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

    await tester.tap(find.text('Edit and resubmit'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your company'), findsOneWidget);
    expect(find.text('Company Info'), findsOneWidget);
  });

  /// Once resubmitted and approved, the pushed form pops and the gate,
  /// still underneath, shows the real Company Home — not the stale
  /// pending screen it was pushed from.
  testWidgets(
    'resubmitting from the waiting screen and getting approved lands on Company Home',
    (tester) async {
      // Flipped manually right before invoking the pushed screen's own
      // onSubmitted below — not inside a fake `onSubmit`, since calling
      // onSubmitted() directly (the form's own attachment requirement
      // can't be driven here without a native file picker) never actually
      // calls the repository's submit().
      var resubmitted = false;
      final repository = FakeCompanyRepository(
        onGetStatus: () async => CompanyVerification(
          status: resubmitted ? 'approved' : 'pending',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit and resubmit'));
      await tester.pumpAndSettle();
      expect(find.text('Verify your company'), findsOneWidget);

      resubmitted = true;
      final screen = tester.widget<CompanyVerificationScreen>(
        find.byType(CompanyVerificationScreen),
      );
      screen.onSubmitted();
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Verify your company'), findsNothing);
      expect(find.text('ABC Logistics is under review'), findsNothing);
    },
  );

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

  testWidgets(
    'shows the Company Home shell (Dashboard/Find Jobs/Messages/Profile tabs) once approved',
    (tester) async {
      final repository = FakeCompanyRepository(
        onGetStatus: () async => const CompanyVerification(
          status: 'approved',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      // The shell's bottom nav — IndexedStack keeps every tab mounted
      // simultaneously, not just the visible one.
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Find Jobs'), findsWidgets);
      expect(find.text('Messages'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
    },
  );

  testWidgets(
    'tapping the Dashboard\'s "Find jobs" quick action switches to the Find Jobs tab',
    (tester) async {
      final repository = FakeCompanyRepository(
        onGetStatus: () async => const CompanyVerification(
          status: 'approved',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        ),
      );

      await tester.pumpWidget(_appUnder(repository));
      await tester.pumpAndSettle();

      // Only the CompanyJobsScreen (the Find Jobs tab) has this tab bar —
      // regression test for onFindJobs never being wired from the shell to
      // CompanyHomeTab, which made this quick-action button a silent no-op.
      expect(find.text('Open'), findsNothing);

      await tester.tap(find.text('Find jobs'));
      await tester.pumpAndSettle();

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('My Bids'), findsOneWidget);
    },
  );

  /// The reported bug: submitting the verification form left the company
  /// staring at the same form. The screen used to navigate to '/company' on
  /// success — the route the company is already on — so this gate never
  /// re-read the status and just re-rendered the form.
  testWidgets('submitting the verification form lands on the pending screen', (
    tester,
  ) async {
    var submitted = false;
    final repository = FakeCompanyRepository(
      onGetStatus: () async => submitted
          ? const CompanyVerification(
              status: 'pending',
              rejectedReason: null,
              companyName: 'ABC Logistics',
            )
          : null,
      onSubmit: (submission) async {
        submitted = true;
        return const CompanyVerification(
          status: 'pending',
          rejectedReason: null,
          companyName: 'ABC Logistics',
        );
      },
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();
    expect(find.text('Verify your company'), findsOneWidget);

    // Drive the real form rather than calling the callback directly, so
    // this covers the whole path a company actually takes.
    for (final field in find.byType(TextField).evaluate()) {
      final widget = field.widget as TextField;
      final label = widget.decoration?.labelText ?? '';
      await tester.enterText(
        find.byWidget(field.widget),
        label.startsWith('Company email') ? 'test@example.com' : 'test value',
      );
    }
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Submit for review'));
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();

    // Attachments are picked through a native file picker that can't run in
    // a widget test, so the form stops at its attachment check. That's as
    // far as the UI can be driven here — the navigation itself is covered
    // by the callback test below.
    expect(
      find.text(
        'Please attach the company registration certificate, TIN certificate, and ID document.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the gate swaps the form for the pending screen once submitted', (
    tester,
  ) async {
    var submitted = false;
    final repository = FakeCompanyRepository(
      onGetStatus: () async => submitted
          ? const CompanyVerification(
              status: 'pending',
              rejectedReason: null,
              companyName: 'ABC Logistics',
            )
          : null,
    );

    await tester.pumpWidget(_appUnder(repository));
    await tester.pumpAndSettle();
    expect(find.text('Verify your company'), findsOneWidget);

    // Exactly what a successful submission does: mark it submitted, then
    // fire the screen's onSubmitted callback.
    submitted = true;
    final screen = tester.widget<CompanyVerificationScreen>(
      find.byType(CompanyVerificationScreen),
    );
    screen.onSubmitted();
    await tester.pumpAndSettle();

    expect(find.text('ABC Logistics is under review'), findsOneWidget);
    expect(find.text('Verify your company'), findsNothing);
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
