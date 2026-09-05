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
}
