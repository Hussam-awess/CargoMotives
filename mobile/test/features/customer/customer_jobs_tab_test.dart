import 'package:cargo_motives/features/auth/data/auth_repository.dart';
import 'package:cargo_motives/features/customer/customer_jobs_tab.dart';
import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/notifications/data/notification_repository.dart';
import 'package:cargo_motives/features/support/support_thread_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:cargo_motives/shared/widgets/plus_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_job_repository.dart';
import '../../support/fake_notification_repository.dart';

Widget _appUnder(Widget home) {
  return MaterialApp(
    home: home,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

Job _job({int id = 1, String status = 'open'}) {
  return Job(
    id: id,
    status: status,
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
}

void main() {
  testWidgets(
    'greets the customer by first name and shows a zero-activity dashboard',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerJobsTab(
            repository: FakeJobRepository(onList: () async => []),
            notificationRepository: FakeNotificationRepository(),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Hussam Ali',
                companyName: null,
                isFeatured: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Hussam 👋'), findsOneWidget);
      expect(find.text('No active shipment right now.'), findsOneWidget);
      expect(find.text('No recent activity.'), findsOneWidget);
      expect(find.byType(PlusBadge), findsNothing);
      expect(find.text('Go further with Cargo Motives Plus'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the Plus badge and hides the promo banner for a featured customer',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerJobsTab(
            repository: FakeJobRepository(onList: () async => []),
            notificationRepository: FakeNotificationRepository(),
            authRepository: FakeAuthRepository(
              onMe: () async => const UserProfile(
                fullName: 'Hussam Ali',
                companyName: null,
                isFeatured: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlusBadge), findsOneWidget);
      expect(find.text('Go further with Cargo Motives Plus'), findsNothing);
    },
  );

  testWidgets(
    'shows the most recently created active job in the Active Shipment card',
    (tester) async {
      await tester.pumpWidget(
        _appUnder(
          CustomerJobsTab(
            repository: FakeJobRepository(
              onList: () async => [
                _job(id: 1, status: 'completed'),
                _job(id: 2, status: 'in_transit'),
              ],
            ),
            notificationRepository: FakeNotificationRepository(),
            authRepository: FakeAuthRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CM-0002'), findsOneWidget);
      expect(find.text('Kariakoo → Mbezi Beach'), findsOneWidget);
      expect(find.text('In Transit'), findsWidgets);
    },
  );

  testWidgets(
    'shows an error state with a retry button that actually retries',
    (tester) async {
      var shouldFail = true;
      await tester.pumpWidget(
        _appUnder(
          CustomerJobsTab(
            repository: FakeJobRepository(
              onList: () async =>
                  shouldFail ? throw StateError('boom') : [_job()],
            ),
            notificationRepository: FakeNotificationRepository(),
            authRepository: FakeAuthRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load your dashboard.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('No active shipment right now.'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping a support-message notification in Recent Activity opens the support thread',
    (tester) async {
      int? markedReadId;
      await tester.pumpWidget(
        _appUnder(
          CustomerJobsTab(
            repository: FakeJobRepository(onList: () async => []),
            notificationRepository: FakeNotificationRepository(
              onList: () async => [
                AppNotification(
                  id: 7,
                  type: 'support_message',
                  title: 'Message from Cargo Motives Support',
                  body: 'Your shipment has been reviewed...',
                  relatedJobId: null,
                  readAt: null,
                  createdAt: DateTime(2026, 9, 16),
                ),
              ],
              onMarkRead: (id) async => markedReadId = id,
            ),
            authRepository: FakeAuthRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Message from Cargo Motives Support'));
      // A single pump, not pumpAndSettle: SupportThreadScreen is pushed with
      // its real default repository (no fake injected here, matching how
      // _openSupport() constructs it in the app itself), whose in-flight
      // network call never resolves in a widget test and would keep its
      // loading spinner animating forever, hanging pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(markedReadId, 7);
      expect(find.byType(SupportThreadScreen), findsOneWidget);
    },
  );

  testWidgets('filters shipments by search query', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        CustomerJobsTab(
          repository: FakeJobRepository(
            onList: () async => [_job(id: 42, status: 'open')],
          ),
          notificationRepository: FakeNotificationRepository(),
          authRepository: FakeAuthRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'CM-0042');
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo → Mbezi Beach'), findsOneWidget);
    expect(find.text('CM-0042 · Open for bids'), findsOneWidget);
  });
}
