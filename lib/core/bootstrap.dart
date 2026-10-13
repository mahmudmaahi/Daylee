import 'package:get/get.dart';

import '../core/router/app_router.dart';
import '../data/repositories/prayer_repository.dart';
import '../data/services/notification_center.dart';
import '../data/services/notification_service.dart';
import '../data/services/prayer_notification_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/weather_service.dart';
import '../data/services/location_service.dart';

/// Work that must not delay the first frame: notification setup and
/// re-planning of every scheduled reminder.
class AppBootstrap {
  AppBootstrap._();

  static DateTime? _lastSync;
  static bool _running = false;

  static Future<void> afterFirstFrame() async {
    NotificationService.onTap = (payload) {
      if (payload == 'prayer') {
        Get.toNamed(AppRoutes.prayer);
      } else if (payload == 'finance') {
        Get.toNamed(AppRoutes.money);
      }
    };
    await NotificationService.initialize();
    await resync(force: true);
  }

  /// Rebuilds all scheduled notifications. Called on start and whenever the
  /// app returns to the foreground (so the rolling prayer-time window keeps
  /// moving forward and changed permissions are picked up).
  static Future<void> resync({bool force = false}) async {
    if (_running) return;
    final last = _lastSync;
    if (!force && last != null && DateTime.now().difference(last).inMinutes < 5) {
      return;
    }
    _running = true;
    try {
      if (NotificationCenter.masterEnabled) {
        if (!StorageService.getBool('notif_permission_asked')) {
          await NotificationService.requestPermission();
          await StorageService.setBool('notif_permission_asked', true);
        }
        await PrayerNotificationService.syncAll(
          customPrayers: Get.find<PrayerRepository>().getAllPrayers(),
          muteAll: StorageService.getBool('prayer_mute_all_v1'),
        );
      } else {
        await NotificationService.cancelAll();
      }
      await NotificationCenter.syncDailyReminder();
      _lastSync = DateTime.now();

      if (LocationService.enabled) {
        // Warm the weather cache in the background.
        await WeatherService.load();
      }
    } catch (_) {
      // Scheduling problems must never crash the app.
    } finally {
      _running = false;
    }
  }
}
