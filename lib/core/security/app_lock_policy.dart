class AppLockPolicy {
  AppLockPolicy._();

  static const String enabledKey = 'pin_lock_enabled';
  static const String useBiometricsKey = 'lock_use_biometrics';
  static const String delaySecondsKey = 'lock_delay_seconds';
  static const String lastActiveAtMsKey = 'last_active_timestamp';
  static const String lastRouteKey = 'last_route';
  static const String lastUnlockMsKey = 'last_unlock_ms';

  static const List<int> supportedDelaySeconds = <int>[0, 60, 300, 900, 3600];

  static String delayLabel(int seconds) {
    switch (seconds) {
      case 0:
        return 'Immediately';
      case 60:
        return 'After 1 minute';
      case 300:
        return 'After 5 minutes';
      case 900:
        return 'After 15 minutes';
      case 3600:
        return 'After 1 hour';
      default:
        return 'After 1 minute';
    }
  }

  static int sanitizeDelay(int seconds) {
    if (supportedDelaySeconds.contains(seconds)) return seconds;
    return 60;
  }
}
