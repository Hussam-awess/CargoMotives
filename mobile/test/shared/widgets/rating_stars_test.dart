import 'package:cargo_motives/shared/widgets/rating_stars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows "New" when there is no rating yet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RatingStars(rating: null, count: 0)));

    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('shows "New" when a rating is somehow present but count is zero', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RatingStars(rating: 4.5, count: 0)));

    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('shows the rating and count together by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RatingStars(rating: 4.6, count: 12)));

    expect(find.text('4.6 (12)'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('hides the count when showCount is false', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RatingStars(rating: 4.6, count: 12, showCount: false)));

    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('4.6 (12)'), findsNothing);
  });
}
