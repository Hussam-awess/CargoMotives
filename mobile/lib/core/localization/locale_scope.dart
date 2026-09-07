import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

/// Exposes the app-wide LocaleController to any descendant widget (the
/// language switcher in each role's Profile tab) without threading it
/// through every screen's constructor — this app otherwise passes
/// dependencies explicitly per screen (see e.g. CompanyHomeShell), which
/// is the right call for per-feature repositories, but a poor fit for one
/// piece of state every screen sits below regardless of feature.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope != null, 'No LocaleScope found in context — is this widget under CargoMotivesApp?');

    return scope!.notifier!;
  }
}
