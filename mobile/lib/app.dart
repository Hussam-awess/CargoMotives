import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class CargoMotivesApp extends StatelessWidget {
  const CargoMotivesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cargo Motives',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      // Swahili default, English fallback (PRD §12, UI/UX Brief §2.6).
      // GlobalMaterialLocalizations/GlobalWidgetsLocalizations/
      // GlobalCupertinoLocalizations cover framework-level strings (buttons,
      // date pickers, etc.) for both locales out of the box; Cargo Motives'
      // own translated app strings (an .arb file per locale) are added in
      // the Phase 10 localization pass — this wiring just has to exist now
      // so the app doesn't crash on its own default locale.
      locale: const Locale('sw'),
      supportedLocales: const [Locale('sw'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
