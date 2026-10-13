import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around flutter_local_notifications: initialisation,
/// permissions, channels and scheduling helpers shared by every feature.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static void Function(String payload)? onTap;

  static const String prayerChannelId = 'prayer_reminders_v2';
  static const String financeChannelId = 'finance_alerts_v1';

  static const AndroidNotificationChannel _prayerChannel =
      AndroidNotificationChannel(
        prayerChannelId,
        'Prayer reminders',
        description: 'Prayer time alerts and custom prayer reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

  static const AndroidNotificationChannel _financeChannel =
      AndroidNotificationChannel(
        financeChannelId,
        'Spending reminders',
        description: 'Daily expense reminder and budget alerts',
        importance: Importance.high,
      );

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Safe to call repeatedly. Never throws: notifications must not be able to
  /// stop the app from starting.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone));
      } catch (_) {
        // Asia/Dhaka is UTC+6 with no DST; a sane fallback for this app.
        tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
      }

      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        init,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) onTap?.call(payload);
        },
      );

      final android = _android;
      await android?.createNotificationChannel(_prayerChannel);
      await android?.createNotificationChannel(_financeChannel);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  // ── Permissions ─────────────────────────────────────────────

  /// Asks for the notification permission (Android 13+ / iOS).
  static Future<bool> requestPermission() async {
    await initialize();
    try {
      final android = _android;
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> notificationsAllowed() async {
    await initialize();
    try {
      final android = _android;
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Android 12+ requires the user to grant "Alarms & reminders" for exact
  /// alarms. Without it we fall back to inexact scheduling (can be minutes
  /// late), so the UI tells the user how to fix it.
  static bool? _exactCache;
  static DateTime? _exactCachedAt;

  static Future<bool> exactAlarmsAllowed({bool refresh = true}) async {
    await initialize();
    final at = _exactCachedAt;
    if (!refresh &&
        _exactCache != null &&
        at != null &&
        DateTime.now().difference(at).inSeconds < 30) {
      return _exactCache!;
    }
    try {
      _exactCache = await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      _exactCache = false;
    }
    _exactCachedAt = DateTime.now();
    return _exactCache!;
  }

  static Future<void> requestExactAlarms() async {
    await initialize();
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  // ── Scheduling ──────────────────────────────────────────────

  static NotificationDetails _details(String channelId) {
    final isPrayer = channelId == prayerChannelId;
    final channel = isPrayer ? _prayerChannel : _financeChannel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: isPrayer ? Priority.max : Priority.high,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// Schedules a notification at [when]. [repeat] makes it recur
  /// (daily / weekly / monthly) using the time components of [when].
  /// Returns false when nothing was scheduled.
  static Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    String channelId = prayerChannelId,
    DateTimeComponents? repeat,
    String? payload,
  }) async {
    await initialize();
    if (!_initialized) return false;

    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (repeat == null && !scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      return false;
    }

    Future<void> run(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(channelId),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: repeat,
        payload: payload,
      );
    }

    try {
      final exact = await exactAlarmsAllowed(refresh: false);
      await run(
        exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return true;
    } on PlatformException {
      try {
        await run(AndroidScheduleMode.inexactAllowWhileIdle);
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String channelId = financeChannelId,
    String? payload,
  }) async {
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.show(id, title, body, _details(channelId), payload: payload);
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    await initialize();
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> cancelMany(Iterable<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  static Future<int> pendingCount() async {
    await initialize();
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return 0;
    }
  }
}
