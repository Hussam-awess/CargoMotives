import 'package:flutter/widgets.dart';

import 'locale_store.dart';

/// The app's current locale, changeable at runtime without a restart
/// (unlike the Phase 0 placeholder this replaces, which hardcoded
/// `Locale('sw')`). A ValueNotifier so MaterialApp.router can rebuild
/// just by listening to it — no new state-management package needed for
/// one piece of genuinely global state.
class LocaleController extends ValueNotifier<Locale> {
  LocaleController(super.initialLocale, {LocaleStore? store})
    : _store = store ?? LocaleStore();

  final LocaleStore _store;

  /// English default (product decision, Phase 11 — overrides the docs'
  /// original "Swahili default, English fallback," PRD §12/UI-UX Brief
  /// §2.6). Kept for a user who has never explicitly set a preference (no
  /// device, no signed-in account) — the language icon on Welcome/Login
  /// lets them switch to Kiswahili immediately if they prefer it.
  static const defaultLocale = Locale('en');

  static Future<LocaleController> load({LocaleStore? store}) async {
    final resolvedStore = store ?? LocaleStore();
    final saved = await resolvedStore.read();

    return LocaleController(saved ?? defaultLocale, store: resolvedStore);
  }

  Future<void> setLocale(Locale locale) async {
    value = locale;
    await _store.write(locale);
  }
}
