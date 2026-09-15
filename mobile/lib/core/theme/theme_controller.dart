import 'package:flutter/widgets.dart';

import 'theme_store.dart';

/// The app's current dark-mode preference, changeable at runtime without a
/// restart — mirrors LocaleController's shape exactly. A plain
/// `ValueNotifier<bool>` (dark or not), not a 3-way `ThemeMode`: the
/// Settings screens only ever exposed a single "Dark mode" switch (no
/// "system default" option in the mockup), so there's nothing to
/// under-build by matching that shape.
class ThemeController extends ValueNotifier<bool> {
  ThemeController(super.initialIsDark, {ThemeStore? store})
    : _store = store ?? ThemeStore();

  final ThemeStore _store;

  static Future<ThemeController> load({ThemeStore? store}) async {
    final resolvedStore = store ?? ThemeStore();
    final saved = await resolvedStore.read();

    return ThemeController(saved ?? false, store: resolvedStore);
  }

  Future<void> setDarkMode(bool isDark) async {
    value = isDark;
    await _store.write(isDark);
  }
}
