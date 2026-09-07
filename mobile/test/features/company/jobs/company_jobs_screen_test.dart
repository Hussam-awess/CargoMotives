import 'package:cargo_motives/features/company/data/featured_repository.dart';
import 'package:cargo_motives/features/company/jobs/company_jobs_screen.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_company_featured_repository.dart';
import '../../../support/fake_company_job_repository.dart';
import '../../../support/fake_notification_repository.dart';

Widget _appUnder(Widget home) {
  return MaterialApp(
    home: home,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

final _openJob = Job(
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
  testWidgets('shows the Open tab by default with its own empty state', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CompanyJobsScreen(
          repository: FakeCompanyJobRepository(onOpen: ({usePreferredRoutes = false}) async => []),
          featuredRepository: FakeCompanyFeaturedRepository(),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No open jobs right now.'), findsOneWidget);
    expect(find.text('My preferred routes only'), findsNothing);
  });

  testWidgets('switching to My Bids and Active tabs loads their own feeds', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CompanyJobsScreen(
          repository: FakeCompanyJobRepository(
            onOpen: ({usePreferredRoutes = false}) async => [_openJob],
            onMyBids: () async => [],
            onActive: () async => [],
          ),
          featuredRepository: FakeCompanyFeaturedRepository(),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dry Van · 40ft'), findsOneWidget);

    await tester.tap(find.text('My Bids'));
    await tester.pumpAndSettle();
    expect(find.text("You haven't placed any bids yet."), findsOneWidget);

    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();
    expect(find.text('No active jobs yet.'), findsOneWidget);
  });

  testWidgets('a Featured company sees and can use the preferred-routes toggle', (tester) async {
    bool? capturedUsePreferredRoutes;
    await tester.pumpWidget(
      _appUnder(
        CompanyJobsScreen(
          repository: FakeCompanyJobRepository(
            onOpen: ({usePreferredRoutes = false}) async {
              capturedUsePreferredRoutes = usePreferredRoutes;
              return [_openJob];
            },
          ),
          featuredRepository: FakeCompanyFeaturedRepository(
            onStatus: () async =>
                const CompanyFeaturedStatus(isFeatured: true, featuredUntil: null, price: 50000, durationDays: 30, preferredRoutes: []),
          ),
          notificationRepository: FakeNotificationRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My preferred routes only'), findsOneWidget);
    expect(capturedUsePreferredRoutes, false);

    await tester.tap(find.text('My preferred routes only'));
    await tester.pumpAndSettle();

    expect(capturedUsePreferredRoutes, true);
  });
}
