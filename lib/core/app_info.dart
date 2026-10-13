import 'package:package_info_plus/package_info_plus.dart';

/// Version information of the installed app.
///
/// The values come from the installed package itself, which Flutter fills from
/// `version: <name>+<build>` in pubspec.yaml, so the version shown in the app
/// is always exactly the one of the APK that is running.
class AppInfo {
  AppInfo._();

  static const String name = 'DayLee';

  static String _version = '1.0.0';
  static String _build = '1';

  /// Human readable version, e.g. `1.0.0`.
  static String get version => _version;

  /// Monotonic build number (Android `versionCode`), e.g. `1`.
  static String get buildNumber => _build;

  /// e.g. `v1.0.0 (1)`.
  static String get versionLabel => 'v$_version ($_build)';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) _version = info.version;
      if (info.buildNumber.isNotEmpty) _build = info.buildNumber;
    } catch (_) {
      // Keep the defaults; never block start-up on this.
    }
  }
}
