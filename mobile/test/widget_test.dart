// Smoke test for the app shell: splash resolves (no session yet) to the
// Welcome/Role-selection screen, and both roles route correctly — Customer
// to its own email+password sign-up (Phase 11), Transporter Company to its
// own phone+OTP sign-up (design-import restyle: tap-select-then-Continue).

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargo_motives/app.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';

import 'support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  // Splash's CircularProgressIndicator spins indefinitely by design (an
  // indeterminate loading spinner), so pumpAndSettle() never returns while
  // it's on-screen — bounded pumps cover its minimum-visible delay plus
  // fade-in plus a route-transition frame or two instead. Both roles are
  // exercised in one continuous test (rather than two separate
  // testWidgets blocks) to mirror the single real navigation session a
  // user would actually have.
  testWidgets(
    'Splash routes to Welcome, and both roles navigate correctly',
    (WidgetTester tester) async {
      // English, deterministically — this test is about the navigation
      // flow, not which language happens to be the app's own default.
      await tester.pumpWidget(CargoMotivesApp(localeController: LocaleController(const Locale('en'))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Welcome to Cargo Motives'), findsOneWidget);
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('Transporter'), findsOneWidget);

      await tester.tap(find.text('Transporter'));
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Step 1 of 3 · Account'), findsOneWidget);

      // Back to Welcome, then the Customer path — all within the same
      // pumpWidget instance (see the note above).
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Customer'));
      await tester.pump();
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Step 1 of 3 · Account'), findsNothing);
    },
  );
}
