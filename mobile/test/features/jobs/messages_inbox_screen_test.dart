import 'package:cargo_motives/features/jobs/data/job_repository.dart';
import 'package:cargo_motives/features/jobs/data/message_repository.dart';
import 'package:cargo_motives/features/jobs/messages_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_message_repository.dart';
import '../../support/fake_support_message_repository.dart';

Job _job(int id, {required String status, String? assignedCompanyName}) => Job(
  id: id,
  status: status,
  pickupAddress: 'Kariakoo, Dar es Salaam',
  pickupLat: -6.8161,
  pickupLng: 39.2803,
  dropoffAddress: 'Mbezi Beach, Dar es Salaam',
  dropoffLat: -6.7,
  dropoffLng: 39.2,
  containerType: 'Dry Van',
  containerSize: '40ft',
  approxWeightTons: 12,
  cargoDescription: 'General cargo',
  preferredPickupWindowStart: DateTime(2026, 9, 10, 9),
  customerNotes: null,
  agreedPrice: null,
  currency: 'TZS',
  assignedCompanyName: assignedCompanyName,
  assignedTruckRegistration: null,
  assignedDriverName: null,
  proofOfDelivery: null,
  bidsCount: 0,
);

void main() {
  testWidgets('shows a conversation per non-open, non-cancelled job with its latest message', (tester) async {
    final jobs = [
      _job(1, status: 'open', assignedCompanyName: null),
      _job(2, status: 'assigned', assignedCompanyName: 'Kilimanjaro Haulers'),
      _job(3, status: 'cancelled', assignedCompanyName: 'Serengeti Movers'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesInboxScreen(
          fetchJobs: () async => jobs,
          counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter',
          messageRepository: FakeMessageRepository(
            onForJob: (jobId) async => jobId == 2
                ? [ChatMessage(id: 1, body: 'On our way', isMine: false, readAt: null, createdAt: DateTime(2026, 9, 10, 8))]
                : [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kilimanjaro Haulers'), findsOneWidget);
    expect(find.text('On our way'), findsOneWidget);
    expect(find.text('Serengeti Movers'), findsNothing);
  });

  testWidgets('shows an empty state when there are no eligible conversations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesInboxScreen(
          fetchJobs: () async => [_job(1, status: 'open')],
          counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter',
          messageRepository: FakeMessageRepository(onForJob: (_) async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('always shows the pinned Cargo Motives Support row, even before jobs load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesInboxScreen(fetchJobs: () async => [], counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter'),
      ),
    );

    // Before the async job fetch settles, the pinned Support row should
    // already be visible — it doesn't depend on the conversation list.
    expect(find.text('Cargo Motives Support'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Cargo Motives Support'), findsOneWidget);
  });

  testWidgets('tapping the Support row opens the Support thread', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesInboxScreen(
          fetchJobs: () async => [],
          counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter',
          supportMessageRepository: FakeSupportMessageRepository(onList: () async => []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cargo Motives Support'));
    await tester.pumpAndSettle();

    expect(find.text('No messages yet. Ask us anything.'), findsOneWidget);
  });

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesInboxScreen(
          fetchJobs: () async => throw StateError('boom'),
          counterpartyLabel: (job) => job.assignedCompanyName ?? 'Transporter',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load your messages.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
