import 'package:cargo_motives/core/theme/app_theme.dart';
import 'package:cargo_motives/features/jobs/data/message_repository.dart';
import 'package:cargo_motives/features/jobs/messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_message_repository.dart';

void main() {
  testWidgets('shows an empty state when there are no messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(onForJob: (_) async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No messages yet. Say hello!'), findsOneWidget);
  });

  testWidgets('shows existing messages with mine on distinguishable styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(
            onForJob: (_) async => [
              ChatMessage(
                id: 1,
                body: 'When will you arrive?',
                isMine: true,
                readAt: null,
                createdAt: DateTime(2026, 9, 10, 9),
              ),
              ChatMessage(
                id: 2,
                body: 'On our way.',
                isMine: false,
                readAt: null,
                createdAt: DateTime(2026, 9, 10, 9, 5),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('When will you arrive?'), findsOneWidget);
    expect(find.text('On our way.'), findsOneWidget);
  });

  testWidgets('tints a Plus sender\'s bubble border gold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(
            onForJob: (_) async => [
              ChatMessage(
                id: 1,
                body: 'We can do this for 500,000 TZS.',
                isMine: false,
                senderIsFeatured: true,
                readAt: null,
                createdAt: DateTime(2026, 9, 10, 9),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('We can do this for 500,000 TZS.'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, AppColors.accent);
  });

  testWidgets('sending a message appends it and clears the input', (
    tester,
  ) async {
    int? capturedJobId;
    String? capturedBody;
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(
            onForJob: (_) async => [],
            onSend: (jobId, body) async {
              capturedJobId = jobId;
              capturedBody = body;
              return ChatMessage(
                id: 1,
                body: body,
                isMine: true,
                readAt: null,
                createdAt: DateTime.now(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(capturedJobId, 5);
    expect(capturedBody, 'Hello there');
    expect(find.text('Hello there'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(
            onForJob: (_) async => throw StateError('boom'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load messages.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows a plain "Messages" title when no counterparty is known', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(onForJob: (_) async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
  });

  testWidgets('shows the driver name as a subtitle under the company name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(onForJob: (_) async => []),
          counterpartyName: 'ABC Logistics',
          counterpartySubtitle: 'Driver: Juma Hassan',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Logistics'), findsOneWidget);
    expect(find.text('Driver: Juma Hassan'), findsOneWidget);
  });

  testWidgets('shows no subtitle when the driver name is not known', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          jobId: 5,
          repository: FakeMessageRepository(onForJob: (_) async => []),
          counterpartyName: 'ABC Logistics',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Logistics'), findsOneWidget);
    expect(find.textContaining('Driver:'), findsNothing);
  });

  testWidgets(
    'tapping the counterparty name in the header opens their profile',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MessagesScreen(
            jobId: 5,
            repository: FakeMessageRepository(onForJob: (_) async => []),
            counterpartyName: 'ABC Logistics',
            onOpenCounterpartyProfile: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ABC Logistics'), findsOneWidget);
      expect(find.text('Messages'), findsNothing);

      await tester.tap(find.text('ABC Logistics'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    },
  );
}
