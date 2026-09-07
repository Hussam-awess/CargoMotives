import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import 'locale_scope.dart';

/// Shared between both roles' Profile tabs (Customer and Company) — same
/// UI, same behavior, so it lives here once rather than being duplicated.
/// Changing it updates the on-device LocaleController immediately (the
/// whole app rebuilds in the new language right away, no restart) and
/// best-effort syncs the choice to the backend's User.language_preference
/// — a failure there is silent, the same "don't block on a non-critical
/// side effect" pattern CompanyHomeShell's hold-status check already uses.
class LanguageSwitcherTile extends StatelessWidget {
  LanguageSwitcherTile({super.key, AuthRepository? authRepository})
    : authRepository = authRepository ?? AuthRepository();

  final AuthRepository authRepository;

  Future<void> _select(BuildContext context, Locale locale) async {
    await LocaleScope.of(context).setLocale(locale);
    unawaited(authRepository.updateLanguagePreference(locale.languageCode).catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = LocaleScope.of(context).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.languageLabel, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<Locale>(
          segments: [
            ButtonSegment(value: const Locale('sw'), label: Text(l10n.languageSwahili)),
            ButtonSegment(value: const Locale('en'), label: Text(l10n.languageEnglish)),
          ],
          selected: {current},
          onSelectionChanged: (selected) => _select(context, selected.first),
        ),
      ],
    );
  }
}
