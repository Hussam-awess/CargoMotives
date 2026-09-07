// Smoke test for the app shell: splash resolves (no session yet) to the
// Welcome screen, and both role buttons route correctly — Customer to its
// own email+password sign-up (Phase 11), Transporter Company to the
// original phone+OTP flow (AppFlow §1).

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

  // Welcome's TruckRoadAnimation repeats forever by design (a decorative
  // "truck driving" loop) — pumpAndSettle() waits for every animation to
  // stop, so it never returns once that screen is on-screen. A bounded
  // pump sequence covers Splash's own transition (its minimum-visible
  // delay plus the fade-in, plus a route-transition frame or two) without
  // waiting on an animation that never settles. Both role buttons are
  // exercised in one continuous test (rather than two separate
  // testWidgets blocks) since Welcome's repeating controller is never
  // fully disposed by a bounded pump — leaving it running across a test
  // boundary was observed to leak into the next test's fake-async clock.
  testWidgets(
    'Splash routes to Welcome, and both role buttons navigate correctly',
    (WidgetTester tester) async {
      // English, deterministically — this test is about the navigation
      // flow, not which language happens to be the app's own default.
      await tester.pumpWidget(CargoMotivesApp(localeController: LocaleController(const Locale('en'))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cargo Motives'), findsOneWidget);
      expect(find.text("I'm a Customer"), findsOneWidget);
      expect(find.text("I'm a Transporter Company"), findsOneWidget);

      await tester.tap(find.text("I'm a Transporter Company"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Phone number'), findsOneWidget);

      // Back to Welcome, then the Customer path — all within the same
      // pumpWidget instance (see the note above).
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text("I'm a Customer"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create your account'), findsOneWidget);
    },
  );
}
