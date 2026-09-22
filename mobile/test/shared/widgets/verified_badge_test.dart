import 'package:cargo_motives/shared/widgets/verified_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a verified icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VerifiedBadge()));

    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('honors a custom size', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VerifiedBadge(size: 22)));

    final icon = tester.widget<Icon>(find.byIcon(Icons.verified));
    expect(icon.size, 22);
  });
}
