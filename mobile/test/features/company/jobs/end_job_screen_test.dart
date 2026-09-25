import 'package:cargo_motives/features/company/jobs/end_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_job_assignment_repository.dart';

void main() {
  testWidgets('submitting without a photo shows a validation error', (
    tester,
  ) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EndJobScreen(
          jobId: 5,
          repository: FakeJobAssignmentRepository(
            onSubmitProofOfDelivery:
                ({
                  required jobId,
                  required photos,
                  recipientName,
                  notes,
                }) async {
                  called = true;
                  throw StateError('should not be called');
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as delivered'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add at least one photo as proof of delivery.'),
      findsOneWidget,
    );
    expect(called, isFalse);
  });

  testWidgets('shows the add-photos action and optional fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EndJobScreen(
          jobId: 5,
          repository: FakeJobAssignmentRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add photos'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Who received the cargo?'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Anything worth noting?'),
      findsOneWidget,
    );
  });
}
