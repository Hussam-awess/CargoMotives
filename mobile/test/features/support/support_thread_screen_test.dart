import 'package:cargo_motives/features/jobs/data/message_repository.dart';
import 'package:cargo_motives/features/support/support_thread_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_support_message_repository.dart';

void main() {
  testWidgets('shows an empty state when there are no messages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SupportThreadScreen(repository: FakeSupportMessageRepository(onList: () async => [])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No messages yet. Ask us anything.'), findsOneWidget);
  });

  testWidgets('shows an admin message as not-mine and a user reply as mine', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SupportThreadScreen(
          repository: FakeSupportMessageRepository(
            onList: () async => [
              ChatMessage(id: 1, body: 'Hi, how can we help?', isMine: false, readAt: null, createdAt: DateTime(2026, 9, 10, 9)),
              ChatMessage(id: 2, body: 'I need help with my account.', isMine: true, readAt: null, createdAt: DateTime(2026, 9, 10, 9, 5)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi, how can we help?'), findsOneWidget);
    expect(find.text('I need help with my account.'), findsOneWidget);
  });

  testWidgets('sending a message appends it and clears the input', (tester) async {
    String? capturedBody;
    await tester.pumpWidget(
      MaterialApp(
        home: SupportThreadScreen(
          repository: FakeSupportMessageRepository(
            onList: () async => [],
            onSend: (body) async {
              capturedBody = body;
              return ChatMessage(id: 1, body: body, isMine: true, readAt: null, createdAt: DateTime.now());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'How do I reset my password?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(capturedBody, 'How do I reset my password?');
    expect(find.text('How do I reset my password?'), findsOneWidget);
  });

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SupportThreadScreen(repository: FakeSupportMessageRepository(onList: () async => throw StateError('boom'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load messages.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
