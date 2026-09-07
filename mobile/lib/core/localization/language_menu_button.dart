import 'package:flutter/material.dart';

import 'locale_scope.dart';

/// A compact language switcher for screens with no Profile tab to put
/// LanguageSwitcherTile in — Welcome, Phone Entry, OTP, and the Customer
/// auth screens all sit before login, so this is a plain icon button (top
/// right, per the product request) opening a two-item menu, rather than
/// the fuller SegmentedButton row LanguageSwitcherTile shows post-login.
/// Device-only: there's no signed-in account yet to sync the choice to,
/// unlike LanguageSwitcherTile's best-effort backend sync.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final current = LocaleScope.of(context).value;

    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'Language',
      onSelected: (locale) => LocaleScope.of(context).setLocale(locale),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: const Locale('en'),
          checked: current == const Locale('en'),
          child: const Text('English'),
        ),
        CheckedPopupMenuItem(
          value: const Locale('sw'),
          checked: current == const Locale('sw'),
          child: const Text('Kiswahili'),
        ),
      ],
    );
  }
}
