import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The on-device half of the dark-mode preference — mirrors LocaleStore's
/// shape (an injectable FlutterSecureStorage for testability), read at app
/// launch before there's necessarily a signed-in session at all.
class ThemeStore {
  ThemeStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'dark_mode';

  Future<bool?> read() async {
    final raw = await _storage.read(key: _key);
    return switch (raw) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  Future<void> write(bool isDark) =>
      _storage.write(key: _key, value: isDark.toString());
}
