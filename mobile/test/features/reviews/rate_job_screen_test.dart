import 'package:cargo_motives/core/network/api_exception.dart';
import 'package:cargo_motives/features/reviews/rate_job_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_review_repository.dart';

void main() {
  testWidgets('shows the customer-facing category labels for customerRatingTransporter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(jobId: 10, direction: RatingDirection.customerRatingTransporter, repository: FakeReviewRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('On-time pickup'), findsOneWidget);
    expect(find.text('Vehicle condition'), findsOneWidget);
    expect(find.text('Professionalism'), findsOneWidget);
    expect(find.text('Communication'), findsNothing);
  });

  testWidgets('shows the transporter-facing category labels for transporterRatingCustomer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(jobId: 10, direction: RatingDirection.transporterRatingCustomer, repository: FakeReviewRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Communication'), findsOneWidget);
    expect(find.text('Accurate cargo information'), findsOneWidget);
    expect(find.text('Payment promptness'), findsOneWidget);
    expect(find.text('On-time pickup'), findsNothing);
  });

  testWidgets('submitting without a star rating shows an error and does not call the repository', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(
          jobId: 10,
          direction: RatingDirection.customerRatingTransporter,
          repository: FakeReviewRepository(onSubmit: ({required jobId, required rating, comment, categoryRatings}) async => called = true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit rating'));
    await tester.pump();

    expect(called, isFalse);
    expect(find.text('Choose a star rating.'), findsOneWidget);
  });

  testWidgets('choosing a star rating and submitting sends it, with no category ratings or comment', (tester) async {
    int? capturedRating;
    String? capturedComment;
    Map<String, int>? capturedCategoryRatings;

    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(
          jobId: 10,
          direction: RatingDirection.customerRatingTransporter,
          repository: FakeReviewRepository(
            onSubmit: ({required jobId, required rating, comment, categoryRatings}) async {
              capturedRating = rating;
              capturedComment = comment;
              capturedCategoryRatings = categoryRatings;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The main rating row renders first in the tree — its 5 star_border
    // icons are indices 0-4; tapping index 3 sets a 4-star rating.
    await tester.tap(find.byIcon(Icons.star_border).at(3));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit rating'));
    await tester.pumpAndSettle();

    expect(capturedRating, 4);
    expect(capturedComment, isNull);
    expect(capturedCategoryRatings, isNull);
  });

  testWidgets('a written comment is included when provided', (tester) async {
    String? capturedComment;

    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(
          jobId: 10,
          direction: RatingDirection.customerRatingTransporter,
          repository: FakeReviewRepository(
            onSubmit: ({required jobId, required rating, comment, categoryRatings}) async => capturedComment = comment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border).at(4));
    await tester.enterText(find.byType(TextField), 'Great service.');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit rating'));
    await tester.pumpAndSettle();

    expect(capturedComment, 'Great service.');
  });

  testWidgets('a server error is shown and the form stays open', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RateJobScreen(
          jobId: 10,
          direction: RatingDirection.customerRatingTransporter,
          repository: FakeReviewRepository(
            onSubmit: ({required jobId, required rating, comment, categoryRatings}) async =>
                throw ApiException('You have already rated this job.'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border).at(0));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit rating'));
    await tester.pumpAndSettle();

    expect(find.text('You have already rated this job.'), findsOneWidget);
    expect(find.byType(RateJobScreen), findsOneWidget);
  });

  testWidgets('a successful submission pops back with true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RateJobScreen(
                        jobId: 10,
                        direction: RatingDirection.customerRatingTransporter,
                        repository: FakeReviewRepository(),
                      ),
                    ),
                  );
                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('submitted')));
                  }
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.star_border).at(2));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit rating'));
    await tester.pumpAndSettle();

    expect(find.byType(RateJobScreen), findsNothing);
    expect(find.text('submitted'), findsOneWidget);
  });
}
