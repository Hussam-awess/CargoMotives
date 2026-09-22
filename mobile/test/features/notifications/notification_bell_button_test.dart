import 'package:cargo_motives/features/notifications/data/notification_repository.dart';
import 'package:cargo_motives/features/notifications/notification_bell_button.dart';
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

void main() {
  testWidgets('shows no badge when there are no unread notifications', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        Scaffold(
          appBar: AppBar(
            actions: [NotificationBellButton(repository: FakeNotificationRepository(onUnreadCount: () async => 0))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the unread count as a badge', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        Scaffold(
          appBar: AppBar(
            actions: [NotificationBellButton(repository: FakeNotificationRepository(onUnreadCount: () async => 3))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping the bell opens the Notifications screen', (tester) async {
    await tester.pumpWidget(
      _appUnder(
        Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellButton(
                repository: FakeNotificationRepository(onUnreadCount: () async => 1, onList: () async => []),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('passes onOpenSupport/onOpenFleet through to the Notifications screen', (tester) async {
    var openedSupport = false;
    var openedFleet = false;
    await tester.pumpWidget(
      _appUnder(
        Scaffold(
          appBar: AppBar(
            actions: [
              NotificationBellButton(
                repository: FakeNotificationRepository(
                  onUnreadCount: () async => 0,
                  onList: () async => [
                    AppNotification(
                      id: 1,
                      type: 'support_message',
                      title: 'Message from Cargo Motives Support',
                      body: 'Your shipment has been reviewed...',
                      relatedJobId: null,
                      readAt: DateTime.now(),
                      createdAt: DateTime.now(),
                    ),
                  ],
                ),
                onOpenSupport: () => openedSupport = true,
                onOpenFleet: () => openedFleet = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Message from Cargo Motives Support'));
    await tester.pumpAndSettle();

    expect(openedSupport, isTrue);
    expect(openedFleet, isFalse);
  });
}
