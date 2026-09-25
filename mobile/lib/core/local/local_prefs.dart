import 'package:shared_preferences/shared_preferences.dart';

/// A thin wrapper around `SharedPreferences` for on-device-only settings
/// that have no backend field yet (notification-category toggles, a
/// locally-chosen default payment method, saved addresses, etc.). These
/// values are never synced anywhere — they exist purely so the interface
/// has somewhere real to keep state instead of resetting on every screen
/// visit, until a real backend field is built for whichever of these
/// eventually needs to be a genuine account setting.
class LocalPrefs {
  const LocalPrefs();

  Future<bool> getBool(String key, {required bool defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<List<String>> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  Future<void> setStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }
}
