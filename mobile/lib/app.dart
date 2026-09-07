import 'package:flutter/material.dart';

import 'core/localization/locale_controller.dart';
import 'core/localization/locale_scope.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

class CargoMotivesApp extends StatelessWidget {
  const CargoMotivesApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    // LocaleScope makes localeController reachable from any screen (the
    // language switcher in each role's Profile tab); AnimatedBuilder is
    // what actually makes MaterialApp.router rebuild with the new locale
    // the instant setLocale() is called, without restarting the app.
    return LocaleScope(
      controller: localeController,
      child: AnimatedBuilder(
        animation: localeController,
        builder: (context, _) => MaterialApp.router(
          title: 'Cargo Motives',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: appRouter,
          locale: localeController.value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
  }
}
