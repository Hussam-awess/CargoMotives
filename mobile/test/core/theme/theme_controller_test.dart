import 'package:cargo_motives/core/theme/theme_controller.dart';
import 'package:cargo_motives/core/theme/theme_store.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  test(
    'load() falls back to light (not dark) when nothing is stored',
    () async {
      final controller = await ThemeController.load();

      expect(controller.value, isFalse);
    },
  );

  test('load() returns a previously saved preference', () async {
    await ThemeStore().write(true);

    final controller = await ThemeController.load();

    expect(controller.value, isTrue);
  });

  test(
    'setDarkMode() updates the value and persists it for the next load()',
    () async {
      final controller = await ThemeController.load();

      await controller.setDarkMode(true);

      expect(controller.value, isTrue);
      final reloaded = await ThemeController.load();
      expect(reloaded.value, isTrue);
    },
  );

  test('setDarkMode() notifies listeners', () async {
    final controller = ThemeController(false);
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setDarkMode(true);

    expect(notified, isTrue);
  });
}
