import 'package:cargo_motives/features/support/help_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a PRIORITY tag for a featured account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen(isFeatured: true)));

    expect(find.text('PRIORITY'), findsOneWidget);
  });

  testWidgets('shows no PRIORITY tag for a standard account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));

    expect(find.text('PRIORITY'), findsNothing);
  });
}
