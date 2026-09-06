import 'package:flutter/foundation.dart';

/// Where the app is running matters for the default API URL: an Android
/// emulator can't reach the host machine via `localhost` (that resolves to
/// the emulator itself) — it needs the special `10.0.2.2` alias instead.
/// Everything else (web, iOS simulator, desktop) can use `localhost`
/// directly since they share the host's network namespace.
///
/// Override with `--dart-define=API_BASE_URL=https://...` for a real
/// device on the same network, staging, or production — never hardcode a
/// deployment-specific URL here.
abstract final class AppConfig {
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://localhost:8000';
  }

  /// Reverb (TRD §4's one WebSocket service) connection details. The app
  /// key is a public identifier, not a secret — the same way a Stripe
  /// "publishable key" is safe to embed client-side — so a hardcoded
  /// local-dev default is fine here, same reasoning as apiBaseUrl.
  static String get reverbHost {
    const override = String.fromEnvironment('REVERB_HOST');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }

    return 'localhost';
  }

  static int get reverbPort => const int.fromEnvironment('REVERB_PORT', defaultValue: 8080);

  static bool get reverbUseTls => const bool.fromEnvironment('REVERB_USE_TLS');

  static String get reverbAppKey {
    const override = String.fromEnvironment('REVERB_APP_KEY');

    return override.isNotEmpty ? override : '1lvsdpetjyj7kgmqris1';
  }
}
