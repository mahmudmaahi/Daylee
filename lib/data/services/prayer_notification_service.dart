import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

import '../../features/prayer_reminder/models/prayer_schedule.dart';
import 'notification_service.dart';
import 'prayer_times_service.dart';
import 'storage_service.dart';

class PrayerSyncResult {
  const PrayerSyncResult({required this.autoScheduled, required this.customScheduled});

  final int autoScheduled;
  final int customScheduled;
}

/// Schedules every prayer related notification:
///  * calculated prayer times for the next [horizonDays] days, and
///  * the user's own custom reminders (daily / weekly / custom / monthly / once).
///
/// Calculated times move a little every day, so they are scheduled as
/// individual one-off notifications and re-planned whenever the app opens.
class PrayerNotificationService {
  PrayerNotificationService._();

  static const int horizonDays = 14;

  // Id spaces (never overlap):
  //   200000..  calculated prayers  (day * 20 + prayerIndex * 2 + {0,1})
  //   1_000_000.. custom reminders  (base * 10 + {0 single, 1..7 weekday})
  static const int _autoBase = 200000;
  static const int _autoCount = horizonDays * 20;
  static const String _migrationKey = 'prayer_notifications_v2_migrated';

  static int _customBase(int notificationId) =>
      1000000 + (notificationId.abs() % 90000000);

  static int _customId(int notificationId, int slot) =>
      _customBase(notificationId) * 10 + slot;

  static Future<void> initialize() => NotificationService.initialize();

  /// Removes every scheduled notification of one custom reminder.
  static Future<void> cancelReminder(int notificationId) async {
    await NotificationService.cancelMany(
      List.generate(8, (slot) => _customId(notificationId, slot)),
    );
  }

  static Future<void> _cancelAuto() async {
    await NotificationService.cancelMany(
      List.generate(_autoCount, (i) => _autoBase + i),
    );
  }

  /// Rebuilds the whole prayer schedule. Safe to call at any time.
  static Future<PrayerSyncResult> syncAll({
    required List<PrayerSchedule> customPrayers,
    required bool muteAll,
  }) async {
    await NotificationService.initialize();

    // Older builds used another id scheme; clear their leftovers once.
    if (!StorageService.getBool(_migrationKey)) {
      await NotificationService.cancelAll();
      await StorageService.setBool(_migrationKey, true);
    }

    await _cancelAuto();
    var auto = 0;
    if (!muteAll && PrayerTimesService.autoEnabled) {
      auto = await _scheduleCalculated();
    }

    var custom = 0;
    for (final prayer in customPrayers) {
      await cancelReminder(prayer.notificationId);
      if (muteAll || !prayer.isEnabled) continue;
      custom += await _scheduleCustom(prayer);
    }
    return PrayerSyncResult(autoScheduled: auto, customScheduled: custom);
  }

  // ── Calculated prayer times ─────────────────────────────────

  static Future<int> _scheduleCalculated() async {
    final lead = PrayerTimesService.leadMinutes;
    final atTime = PrayerTimesService.notifyAtTime;
    final timeFmt = DateFormat.jm();
    final today = DateTime.now();
    var count = 0;

    for (var day = 0; day < horizonDays; day++) {
      final date = DateTime(today.year, today.month, today.day + day);
      final entries = PrayerTimesService.forDate(date);
      var index = 0;
      for (final entry in entries) {
        if (!entry.key.isPrayer) continue;
        final slot = _autoBase + day * 20 + index * 2;
        index++;
        if (!PrayerTimesService.remindFor(entry.key)) continue;

        final clock = timeFmt.format(entry.time);
        if (lead > 0) {
          final ok = await NotificationService.schedule(
            id: slot,
            title: '${entry.name} in $lead min',
            body: '${entry.name} prayer is at $clock. Time to get ready.',
            when: entry.time.subtract(Duration(minutes: lead)),
            payload: 'prayer',
          );
          if (ok) count++;
        }
        if (atTime) {
          final ok = await NotificationService.schedule(
            id: slot + 1,
            title: '${entry.name} time',
            body: 'It is time for ${entry.name} ($clock).',
            when: entry.time,
            payload: 'prayer',
          );
          if (ok) count++;
        }
      }
    }
    return count;
  }

  // ── Custom reminders ────────────────────────────────────────

  static Future<int> _scheduleCustom(PrayerSchedule prayer) async {
    final title = prayer.name.trim();
    if (title.isEmpty || prayer.notificationId <= 0) return 0;

    final body = _body(prayer);
    final now = DateTime.now();
    var count = 0;

    Future<void> go(int slot, DateTime when, DateTimeComponents? repeat) async {
      final ok = await NotificationService.schedule(
        id: _customId(prayer.notificationId, slot),
        title: title,
        body: body,
        when: when,
        repeat: repeat,
        payload: 'prayer',
      );
      if (ok) count++;
    }

    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day, prayer.hour, prayer.minute);
    final lead = Duration(minutes: prayer.reminderMinutesBefore);

    switch (prayer.recurrence) {
      case PrayerRecurrence.once:
        final ms = prayer.onceDateMs;
        if (ms == null || ms <= 0) return 0;
        await go(0, at(DateTime.fromMillisecondsSinceEpoch(ms)).subtract(lead), null);
      case PrayerRecurrence.daily:
        var reminder = at(now).subtract(lead);
        if (!reminder.isAfter(now)) reminder = reminder.add(const Duration(days: 1));
        await go(0, reminder, DateTimeComponents.time);
      case PrayerRecurrence.weekly:
      case PrayerRecurrence.custom:
        final days = prayer.repeatWeekdays.isNotEmpty
            ? prayer.repeatWeekdays
            : (prayer.recurrence == PrayerRecurrence.weekly
                  ? [DateTime.fromMillisecondsSinceEpoch(prayer.createdAtMs).weekday]
                  : const <int>[]);
        for (final weekday in days) {
          // First upcoming prayer on [weekday] whose reminder is still ahead.
          for (var i = 0; i < 15; i++) {
            final day = DateTime(now.year, now.month, now.day + i);
            if (day.weekday != weekday) continue;
            final reminder = at(day).subtract(lead);
            if (reminder.isAfter(now)) {
              await go(weekday, reminder, DateTimeComponents.dayOfWeekAndTime);
              break;
            }
          }
        }
      case PrayerRecurrence.monthly:
        final anchorMs = prayer.onceDateMs ?? prayer.createdAtMs;
        final anchor = anchorMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(anchorMs)
            : now;
        for (var m = 0; m < 14; m++) {
          final lastDay = DateTime(now.year, now.month + m + 1, 0).day;
          final day = anchor.day > lastDay ? lastDay : anchor.day;
          final reminder = DateTime(
            now.year,
            now.month + m,
            day,
            prayer.hour,
            prayer.minute,
          ).subtract(lead);
          if (reminder.isAfter(now)) {
            // Schedule only the next one; it is re-planned on every app start
            // (day-of-month repeats would skip short months).
            await go(0, reminder, null);
            break;
          }
        }
    }
    return count;
  }

  static String _body(PrayerSchedule prayer) {
    final lead = prayer.reminderMinutesBefore;
    final clock = DateFormat.jm().format(
      DateTime(2000, 1, 1, prayer.hour, prayer.minute),
    );
    final base = lead <= 0
        ? '${prayer.name} at $clock'
        : '${prayer.name} in $lead ${lead == 1 ? 'minute' : 'minutes'} (at $clock)';
    final note = prayer.note.trim();
    return note.isEmpty ? base : '$base\n$note';
  }

  /// Shows a notification immediately so the user can confirm alerts work.
  static Future<void> sendTest() async {
    await NotificationService.requestPermission();
    await NotificationService.showNow(
      id: 9000,
      title: 'DayLee test notification',
      body: 'Prayer reminders will look like this.',
      channelId: NotificationService.prayerChannelId,
      payload: 'prayer',
    );
  }
}
