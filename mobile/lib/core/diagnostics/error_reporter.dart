import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The single place every uncaught error ends up — framework build/layout
/// errors, and async errors nobody awaited. Today it writes a structured
/// log line (visible in `flutter logs` / logcat / Xcode); wiring a crash
/// reporting service (e.g. Firebase Crashlytics) later means changing only
/// [report], not every call site.
abstract final class ErrorReporter {
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack, context: details.context?.toDescription());
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, context: 'uncaught async error');
      return true;
    };

    // Release builds only: a broken widget shows a calm message instead of
    // a blank grey box. Debug builds keep Flutter's red error screen,
    // which is far more useful while developing.
    if (kReleaseMode) {
      ErrorWidget.builder = (_) => const _FriendlyErrorWidget();
    }
  }

  static void report(Object error, StackTrace? stack, {String? context}) {
    developer.log(
      context == null ? '$error' : '$context: $error',
      name: 'cargo_motives.error',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
  }
}

class _FriendlyErrorWidget extends StatelessWidget {
  const _FriendlyErrorWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n != null) return _message(l10n.friendlyErrorMessage);

    // A failure above MaterialApp has no Localizations (or Directionality)
    // to read the user's language from — show both rather than guess.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _message(
        '${lookupAppLocalizations(const Locale('en')).friendlyErrorMessage}\n\n'
        '${lookupAppLocalizations(const Locale('sw')).friendlyErrorMessage}',
      ),
    );
  }

  Widget _message(String text) {
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
