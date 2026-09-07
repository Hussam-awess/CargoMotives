import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The on-device half of the language preference — mirrors SessionStore's
/// shape (an injectable FlutterSecureStorage for testability). Separate
/// from the backend's User.language_preference column: this is read at
/// app launch before any network call could possibly succeed (and before
/// there's even necessarily a signed-in session at all, e.g. on Welcome),
/// so the device needs its own copy rather than depending on a fetch.
/// LocaleController is what keeps the two in sync going forward.
class LocaleStore {
  LocaleStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'language_preference';

  Future<Locale?> read() async {
    final raw = await _storage.read(key: _key);
    return switch (raw) {
      'en' => const Locale('en'),
      'sw' => const Locale('sw'),
      _ => null,
    };
  }

  Future<void> write(Locale locale) =>
      _storage.write(key: _key, value: locale.languageCode);
}
