import 'package:cargo_motives/core/localization/locale_controller.dart';
import 'package:cargo_motives/core/localization/locale_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage_platform.dart';

void main() {
  setUp(() {
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  test('load() falls back to the Swahili default when nothing is stored', () async {
    final controller = await LocaleController.load();

    expect(controller.value, LocaleController.defaultLocale);
  });

  test('load() returns a previously saved locale', () async {
    await LocaleStore().write(const Locale('en'));

    final controller = await LocaleController.load();

    expect(controller.value, const Locale('en'));
  });

  test('setLocale() updates the value and persists it for the next load()', () async {
    final controller = await LocaleController.load();

    await controller.setLocale(const Locale('en'));

    expect(controller.value, const Locale('en'));
    final reloaded = await LocaleController.load();
    expect(reloaded.value, const Locale('en'));
  });

  test('setLocale() notifies listeners', () async {
    final controller = LocaleController(LocaleController.defaultLocale);
    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setLocale(const Locale('en'));

    expect(notified, isTrue);
  });
}
