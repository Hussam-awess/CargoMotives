import 'package:cargo_motives/features/notifications/data/notification_repository.dart';
import 'package:cargo_motives/features/notifications/notifications_screen.dart';
import 'package:cargo_motives/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_repository.dart';

Widget _appUnder(Widget home) {
  return MaterialApp(
    home: home,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  );
}

AppNotification _notification({int id = 1, DateTime? readAt, int? relatedJobId}) {
  return AppNotification(
    id: id,
    type: 'new_bid',
    title: 'New bid received',
    body: 'Someone bid on your job.',
    relatedJobId: relatedJobId,
    readAt: readAt,
    createdAt: DateTime(2026, 9, 7),
  );
}

void main() {
  testWidgets('shows an empty state when there are no notifications', (tester) async {
    await tester.pumpWidget(
      _appUnder(NotificationsScreen(repository: FakeNotificationRepository(onList: () async => []))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet.'), findsOneWidget);
  });

  testWidgets('lists notifications with title and body', (tester) async {
    await tester.pumpWidget(
      _appUnder(NotificationsScreen(repository: FakeNotificationRepository(onList: () async => [_notification()]))),
    );
    await tester.pumpAndSettle();

    expect(find.text('New bid received'), findsOneWidget);
    expect(find.text('Someone bid on your job.'), findsOneWidget);
  });

  testWidgets('tapping an unread notification marks it read', (tester) async {
    int? markedReadId;
    await tester.pumpWidget(
      _appUnder(
        NotificationsScreen(
          repository: FakeNotificationRepository(
            onList: () async => [_notification(readAt: null)],
            onMarkRead: (id) async => markedReadId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New bid received'));
    await tester.pumpAndSettle();

    expect(markedReadId, 1);
  });

  testWidgets('tapping a notification with a related job calls onTapJob', (tester) async {
    int? tappedJobId;
    await tester.pumpWidget(
      _appUnder(
        NotificationsScreen(
          repository: FakeNotificationRepository(onList: () async => [_notification(relatedJobId: 42)]),
          onTapJob: (jobId) => tappedJobId = jobId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New bid received'));
    await tester.pumpAndSettle();

    expect(tappedJobId, 42);
  });

  testWidgets('mark all read button calls the repository and refreshes', (tester) async {
    var markAllReadCalled = false;
    await tester.pumpWidget(
      _appUnder(
        NotificationsScreen(
          repository: FakeNotificationRepository(
            onList: () async => [_notification(readAt: null)],
            onMarkAllRead: () async => markAllReadCalled = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(markAllReadCalled, isTrue);
  });
}
