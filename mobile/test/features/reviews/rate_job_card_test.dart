import 'package:cargo_motives/features/reviews/rate_job_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the prompt copy and calls onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RateJobCard(onTap: () => tapped = true)),
      ),
    );

    expect(find.text('Rate your experience'), findsOneWidget);

    await tester.tap(find.byType(RateJobCard));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
