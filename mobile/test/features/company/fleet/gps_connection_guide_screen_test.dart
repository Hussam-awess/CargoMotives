import 'package:cargo_motives/features/company/fleet/gps_connection_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a tab per GPS provider, defaulting to the first', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GpsConnectionGuideScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect your GPS provider'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.text('Log in to Wialon'), findsOneWidget);
    expect(find.text('Log in to your Traccar server'), findsNothing);
  });

  testWidgets('switching to the Traccar tab shows its own steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GpsConnectionGuideScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Traccar'));
    await tester.pumpAndSettle();

    expect(find.text('Log in to your Traccar server'), findsOneWidget);
    expect(find.text('Log in to Wialon'), findsNothing);
  });

  testWidgets(
    'the Tracksolid Pro tab explains the colon-joined credential format',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: GpsConnectionGuideScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tracksolid Pro'));
      await tester.pumpAndSettle();

      expect(find.text('Get API access'), findsOneWidget);

      // Tracksolid's steps run longer than the other two providers' — a
      // tall viewport avoids needing to scroll this tab's own list to
      // reach a step further down.
      await tester.binding.setSurfaceSize(const Size(400, 2000));
      await tester.pumpAndSettle();
      expect(find.text('Combine all four with colons'), findsOneWidget);
      expect(
        find.textContaining('appKey:appSecret:account:passwordMD5Hash'),
        findsOneWidget,
      );
    },
  );
}
