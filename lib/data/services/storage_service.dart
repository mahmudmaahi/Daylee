import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper around SharedPreferences for app-wide settings.
/// Used for: theme mode, onboarding state, user preferences.
class StorageService {
  StorageService._();

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Theme ──────────────────────────────────────────────────
  static const _themeKey = 'is_dark_mode';

  static bool get isDarkMode => _prefs.getBool(_themeKey) ?? false;

  static Future<void> setDarkMode(bool value) =>
      _prefs.setBool(_themeKey, value);

  // ── Generic helpers ────────────────────────────────────────
  static bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  static Future<void> setBool(String key, bool value) =>
      _prefs.setBool(key, value);

  static String getString(String key, {String fallback = ''}) =>
      _prefs.getString(key) ?? fallback;

  static Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  static int getInt(String key, {int fallback = 0}) =>
      _prefs.getInt(key) ?? fallback;

  static Future<void> setInt(String key, int value) =>
      _prefs.setInt(key, value);

  static double getDouble(String key, {double fallback = 0.0}) =>
      _prefs.getDouble(key) ?? fallback;

  static Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  static List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? <String>[];

  static Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  static Object? getValue(String key) => _prefs.get(key);

  static Future<void> setValue(String key, Object? value) async {
    if (value == null) {
      await _prefs.remove(key);
      return;
    }
    if (value is bool) {
      await _prefs.setBool(key, value);
      return;
    }
    if (value is int) {
      await _prefs.setInt(key, value);
      return;
    }
    if (value is double) {
      await _prefs.setDouble(key, value);
      return;
    }
    if (value is String) {
      await _prefs.setString(key, value);
      return;
    }
    if (value is List<String>) {
      await _prefs.setStringList(key, value);
      return;
    }
    throw ArgumentError('Unsupported preference value type for key: $key');
  }

  static Set<String> getKeys() => _prefs.getKeys();

  static Future<bool> remove(String key) => _prefs.remove(key);

  static Future<void> clearExcept(Set<String> keepKeys) async {
    final keys = _prefs.getKeys().toList(growable: false);
    for (final key in keys) {
      if (keepKeys.contains(key)) continue;
      await _prefs.remove(key);
    }
  }
}
