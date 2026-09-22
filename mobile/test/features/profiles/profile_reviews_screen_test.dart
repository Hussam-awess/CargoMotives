import 'package:cargo_motives/features/profiles/data/profile_repository.dart';
import 'package:cargo_motives/features/profiles/profile_reviews_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileReview _review(int id, {int rating = 5, String? comment}) =>
    ProfileReview(id: id, rating: rating, comment: comment, categoryRatings: null, createdAt: DateTime(2026, 9, id));

void main() {
  testWidgets('shows an empty state when there are no reviews', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileReviewsScreen(loadPage: (page) async => [])));
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet.'), findsOneWidget);
  });

  testWidgets('shows the first page of reviews and loads more on demand', (tester) async {
    final firstPage = [_review(1, comment: 'Great experience'), _review(2, comment: 'Very professional')];
    final secondPage = [_review(3, comment: 'On time as promised')];
    var requestedPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileReviewsScreen(
          loadPage: (page) async {
            requestedPage = page;
            return page == 1 ? firstPage : (page == 2 ? secondPage : []);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Great experience'), findsOneWidget);
    expect(find.text('Very professional'), findsOneWidget);
    expect(find.text('On time as promised'), findsNothing);
    expect(find.text('Load more'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(requestedPage, 2);
    expect(find.text('On time as promised'), findsOneWidget);
  });

  testWidgets('hides the Load more button once a page comes back empty', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileReviewsScreen(loadPage: (page) async => page == 1 ? [_review(1)] : [])));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();

    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('a load failure shows a retry option', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileReviewsScreen(loadPage: (page) async => throw StateError('boom'))));
    await tester.pumpAndSettle();

    expect(find.text('Could not load reviews.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
