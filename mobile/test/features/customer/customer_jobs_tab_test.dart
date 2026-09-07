import 'package:cargo_motives/features/customer/customer_jobs_tab.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_job_repository.dart';
import '../../support/fake_notification_repository.dart';

Widget _appUnder(Widget home) {
  return MaterialApp(
    home: home,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

final _job = Job(
  id: 1,
  status: 'open',
  pickupAddress: 'Kariakoo',
  pickupLat: -6.8,
  pickupLng: 39.2,
  dropoffAddress: 'Mbezi Beach',
  dropoffLat: -6.7,
  dropoffLng: 39.1,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: null,
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: null,
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: 0,
);

void main() {
  testWidgets('shows an empty state when there are no jobs', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerJobsTab(
          repository: FakeJobRepository(onList: () async => []),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No jobs yet. Tap Post to create one.'), findsOneWidget);
  });

  testWidgets('lists jobs with their status', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerJobsTab(
          repository: FakeJobRepository(onList: () async => [_job]),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
    expect(find.text('Kariakoo → Mbezi Beach'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('shows an error state with a retry button that actually retries', (tester) async {
    var shouldFail = true;
    await tester.pumpWidget(
      _appUnder(
        CustomerJobsTab(
          repository: FakeJobRepository(onList: () async => shouldFail ? throw StateError('boom') : [_job]),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your jobs.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);
  });
}
