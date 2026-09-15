import 'package:flutter/widgets.dart';

import 'theme_controller.dart';

/// Exposes the app-wide ThemeController to any descendant widget (the Dark
/// mode toggle in each role's Settings screen) — mirrors LocaleScope
/// exactly, same reasoning: one piece of state every screen sits below,
/// not a per-feature dependency worth threading through constructors.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(
      scope != null,
      'No ThemeScope found in context — is this widget under CargoMotivesApp?',
    );

    return scope!.notifier!;
  }
}
