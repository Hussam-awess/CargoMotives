import 'package:flutter/material.dart';

import 'core/localization/locale_controller.dart';
import 'core/localization/locale_scope.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_scope.dart';
import 'l10n/generated/app_localizations.dart';

class CargoMotivesApp extends StatelessWidget {
  const CargoMotivesApp({
    super.key,
    required this.localeController,
    required this.themeController,
  });

  final LocaleController localeController;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    // LocaleScope/ThemeScope make both controllers reachable from any
    // screen (the language switcher and the Dark mode toggle, both in each
    // role's Settings/Profile screens); AnimatedBuilder is what actually
    // makes MaterialApp.router rebuild the instant setLocale()/
    // setDarkMode() is called, without restarting the app.
    return LocaleScope(
      controller: localeController,
      child: ThemeScope(
        controller: themeController,
        child: AnimatedBuilder(
          animation: Listenable.merge([localeController, themeController]),
          builder: (context, _) {
            final isDark = themeController.value;

            return MaterialApp.router(
              title: 'Cargo Motives',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: appRouter,
              locale: localeController.value,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              // Tablet support without a second, tablet-specific design: every
              // screen is built phone-first (a single column sized for ~390px),
              // so on a genuinely wider screen (a tablet — there's no desktop
              // app) that column is capped at a phone-ish width and centered
              // rather than stretching edge-to-edge or leaving it sparse. Has
              // no effect at real phone widths, since the constraint only ever
              // binds above 600 — a Material breakpoint (compact vs. medium),
              // not an arbitrary number.
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();

                // Constructing AppTheme.light/.dark above (for the theme:/
                // darkTheme: params) each leave AppColors's internal
                // brightness flag pointed at whichever was built last — reset
                // it here, right before any descendant screen widget builds,
                // to the theme actually in effect. See AppColors's own
                // docblock for why this indirection exists at all.
                AppColors.setBrightness(
                  isDark ? Brightness.dark : Brightness.light,
                );

                return ColoredBox(
                  color: AppColors.background,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: child,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
