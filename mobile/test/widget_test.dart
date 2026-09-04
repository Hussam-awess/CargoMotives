// Smoke test for the Phase 0 app shell: splash resolves (no session yet)
// to the Welcome screen, and both role buttons are present and route
// correctly (AppFlow §1).

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cargo_motives/app.dart';

/// In-memory stand-in for the native secure-storage platform channel, which
/// isn't available under `flutter test` (only in on-device/integration
/// tests). Registered via FlutterSecureStoragePlatform.instance so
/// SessionStore's real code path runs unmodified in tests.
class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _values[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _values[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _values.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_values);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();
}

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
  });

  testWidgets('Splash routes to Welcome, and role buttons navigate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CargoMotivesApp());

    // Splash is shown first, then resolves asynchronously (no stored
    // session -> Welcome) once SessionStore's read completes.
    await tester.pumpAndSettle();

    expect(find.text('Cargo Motives'), findsOneWidget);
    expect(find.text("I'm a Customer"), findsOneWidget);
    expect(find.text("I'm a Transporter Company"), findsOneWidget);

    await tester.tap(find.text("I'm a Customer"));
    await tester.pumpAndSettle();

    expect(find.text('Customer Home'), findsOneWidget);
  });
}
