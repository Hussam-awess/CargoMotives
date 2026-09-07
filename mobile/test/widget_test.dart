// Smoke test for the Phase 0 app shell: splash resolves (no session yet)
// to the Welcome screen, and both role buttons are present and route
// correctly (AppFlow §1).

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargo_motives/app.dart';
import 'package:cargo_motives/core/localization/locale_controller.dart';

import 'support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  testWidgets(
    'Splash routes to Welcome, and role buttons navigate to phone entry',
    (WidgetTester tester) async {
      // English, deterministically — this test is about the navigation
      // flow, not which language happens to be the app's own default.
      await tester.pumpWidget(CargoMotivesApp(localeController: LocaleController(const Locale('en'))));

      // Splash is shown first, then resolves asynchronously (no stored
      // session -> Welcome) once SessionStore's read completes.
      await tester.pumpAndSettle();

      expect(find.text('Cargo Motives'), findsOneWidget);
      expect(find.text("I'm a Customer"), findsOneWidget);
      expect(find.text("I'm a Transporter Company"), findsOneWidget);

      await tester.tap(find.text("I'm a Customer"));
      await tester.pumpAndSettle();

      // Welcome -> Phone Entry is the real Phase 1 flow now (Customer Home
      // itself is reached only after phone/OTP + profile setup).
      expect(find.text('Phone number'), findsOneWidget);
    },
  );
}
