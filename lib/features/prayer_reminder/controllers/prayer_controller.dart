import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/prayer_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_center.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/prayer_notification_service.dart';
import '../../../data/services/prayer_times_service.dart';
import '../../../data/services/storage_service.dart';
import '../models/prayer_schedule.dart';

class PrayerController extends GetxController {
  final _repo = Get.find<PrayerRepository>();

  static const String muteAllKey = 'prayer_mute_all_v1';
  static const List<int> reminderOptions = [0, 5, 10, 15, 30, 60];

  // Custom reminders
  final customPrayers = <PrayerSchedule>[].obs;
  final muteAllReminders = false.obs;
  final isBusy = false.obs;

  // Calculated times
  final todayTimes = <PrayerTimeEntry>[].obs;
  final nowMs = DateTime.now().millisecondsSinceEpoch.obs;
  final autoEnabled = true.obs;
  final methodId = 'karachi'.obs;
  final hanafi = true.obs;
  final leadMinutes = 10.obs;
  final notifyAtTime = true.obs;
  final locationLabel = ''.obs;
  final usingDefaultLocation = true.obs;

  // Health of the notification pipeline
  final notificationsAllowed = true.obs;
  final exactAlarmsAllowed = true.obs;
  final scheduledCount = 0.obs;

  Timer? _clockTimer;

  @override
  void onInit() {
    super.onInit();
    muteAllReminders.value = StorageService.getBool(muteAllKey);
    _loadSettings();
    loadCustom();
    refreshTimes();
    refreshPermissions();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      final previousDay = DateTime.fromMillisecondsSinceEpoch(nowMs.value).day;
      nowMs.value = DateTime.now().millisecondsSinceEpoch;
      if (DateTime.now().day != previousDay) refreshTimes();
    });
    syncNotifications();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    super.onClose();
  }

  // ── Calculated prayer times ─────────────────────────────────

  void _loadSettings() {
    autoEnabled.value = PrayerTimesService.autoEnabled;
    methodId.value = PrayerTimesService.methodId;
    hanafi.value = PrayerTimesService.hanafi;
    leadMinutes.value = PrayerTimesService.leadMinutes;
    notifyAtTime.value = PrayerTimesService.notifyAtTime;
  }

  void refreshTimes() {
    final location = LocationService.cached;
    usingDefaultLocation.value = !location.isReal;
    final place = LocationService.placeName;
    locationLabel.value = location.isReal
        ? (place.isNotEmpty ? place : 'Your location')
        : 'Dhaka (default)';
    todayTimes.assignAll(PrayerTimesService.forDate(DateTime.now()));
    nowMs.value = DateTime.now().millisecondsSinceEpoch;
  }

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(nowMs.value);

  PrayerTimeEntry? get nextPrayer => PrayerTimesService.next(now: now);
  PrayerTimeEntry? get currentPrayer => PrayerTimesService.current(now: now);

  Duration? get untilNext {
    final next = nextPrayer;
    return next?.time.difference(now);
  }

  /// Fraction (0..1) of the gap between the previous and next prayer that
  /// has already passed.
  double get progressToNext {
    final next = nextPrayer;
    final current = currentPrayer;
    if (next == null || current == null) return 0;
    final total = next.time.difference(current.time).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(current.time).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0).toDouble();
  }

  bool isPast(PrayerTimeEntry entry) => !entry.time.isAfter(now);

  Future<void> setAuto(bool value) async {
    autoEnabled.value = value;
    await PrayerTimesService.setAuto(value);
    await syncNotifications();
  }

  Future<void> setMethod(String id) async {
    methodId.value = id;
    await PrayerTimesService.setMethod(id);
    refreshTimes();
    await syncNotifications();
  }

  Future<void> setHanafi(bool value) async {
    hanafi.value = value;
    await PrayerTimesService.setHanafi(value);
    refreshTimes();
    await syncNotifications();
  }

  Future<void> setLead(int minutes) async {
    leadMinutes.value = minutes;
    await PrayerTimesService.setLead(minutes);
    await syncNotifications();
  }

  Future<void> setNotifyAtTime(bool value) async {
    notifyAtTime.value = value;
    await PrayerTimesService.setNotifyAtTime(value);
    await syncNotifications();
  }

  int offsetFor(PrayerKey key) => PrayerTimesService.offset(key);

  Future<void> setOffset(PrayerKey key, int minutes) async {
    await PrayerTimesService.setOffset(key, minutes);
    refreshTimes();
    await syncNotifications();
  }

  bool remindFor(PrayerKey key) => PrayerTimesService.remindFor(key);

  Future<void> setRemind(PrayerKey key, bool value) async {
    await PrayerTimesService.setRemindFor(key, value);
    todayTimes.refresh();
    await syncNotifications();
  }

  /// Uses the phone's location for calculated prayer times.
  Future<LocationAccess> useMyLocation() async {
    final access = await LocationService.enable();
    if (access == LocationAccess.granted) {
      await LocationService.refresh();
      refreshTimes();
      await syncNotifications();
    }
    return access;
  }

  // ── Custom reminders ────────────────────────────────────────

  Future<void> loadCustom() async {
    customPrayers.assignAll(_repo.getAllPrayers());
  }

  Future<void> saveCustom({
    PrayerSchedule? existing,
    required String name,
    required TimeOfDay time,
    required int reminderMinutesBefore,
    required bool isEnabled,
    required PrayerRecurrence recurrence,
    List<int> repeatWeekdays = const [],
    int? onceDateMs,
    String note = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Reminder name is required.');

    final nowStamp = DateTime.now().millisecondsSinceEpoch;
    final id = existing?.id ?? const Uuid().v4();

    final weekdays = switch (recurrence) {
      PrayerRecurrence.once || PrayerRecurrence.monthly => const <int>[],
      PrayerRecurrence.daily => const [1, 2, 3, 4, 5, 6, 7],
      _ => (repeatWeekdays.toSet().toList()..sort()),
    };

    final schedule = PrayerSchedule(
      id: id,
      name: trimmed,
      hour: time.hour,
      minute: time.minute,
      reminderMinutesBefore: reminderMinutesBefore,
      isEnabled: isEnabled,
      recurrence: recurrence,
      repeatWeekdays: weekdays,
      onceDateMs:
          (recurrence == PrayerRecurrence.once ||
              recurrence == PrayerRecurrence.monthly)
          ? onceDateMs
          : null,
      note: note.trim(),
      notificationId: existing?.notificationId ?? _notificationId(id),
      createdAtMs: existing?.createdAtMs ?? nowStamp,
      updatedAtMs: nowStamp,
    );

    isBusy.value = true;
    try {
      await _repo.savePrayer(schedule);
      await loadCustom();
      await syncNotifications();
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> deleteCustom(PrayerSchedule prayer) async {
    await PrayerNotificationService.cancelReminder(prayer.notificationId);
    await _repo.deletePrayer(prayer.id);
    await loadCustom();
  }

  Future<void> toggleCustom(PrayerSchedule prayer, bool enabled) async {
    await _repo.savePrayer(
      prayer.copyWith(
        isEnabled: enabled,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await loadCustom();
    await syncNotifications();
  }

  // ── Notifications ───────────────────────────────────────────

  Future<void> setMuteAll(bool value) async {
    muteAllReminders.value = value;
    await StorageService.setBool(muteAllKey, value);
    await syncNotifications();
  }

  Future<void> syncNotifications() async {
    if (!NotificationCenter.masterEnabled) return;
    final result = await PrayerNotificationService.syncAll(
      customPrayers: customPrayers,
      muteAll: muteAllReminders.value,
    );
    scheduledCount.value = result.autoScheduled + result.customScheduled;
    await refreshPermissions();
  }

  Future<void> refreshPermissions() async {
    notificationsAllowed.value = await NotificationService.notificationsAllowed();
    exactAlarmsAllowed.value = await NotificationService.exactAlarmsAllowed();
  }

  Future<void> requestNotificationPermission() async {
    await NotificationService.requestPermission();
    await refreshPermissions();
    await syncNotifications();
  }

  Future<void> requestExactAlarms() async {
    await NotificationService.requestExactAlarms();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refreshPermissions();
    await syncNotifications();
  }

  Future<void> sendTestNotification() async {
    await PrayerNotificationService.sendTest();
    await refreshPermissions();
  }

  // ── Custom reminder helpers ─────────────────────────────────

  String reminderLabel(int minutes) {
    if (minutes <= 0) return 'At prayer time';
    if (minutes == 60) return '1 hour before';
    if (minutes > 60 && minutes % 60 == 0) return '${minutes ~/ 60} hours before';
    return '$minutes min before';
  }

  /// Next time this custom reminder's *event* happens (not the alert).
  DateTime? nextOccurrence(PrayerSchedule prayer) {
    final current = now;
    DateTime at(DateTime d) =>
        DateTime(d.year, d.month, d.day, prayer.hour, prayer.minute);

    switch (prayer.recurrence) {
      case PrayerRecurrence.once:
        final ms = prayer.onceDateMs;
        if (ms == null || ms <= 0) return null;
        final when = at(DateTime.fromMillisecondsSinceEpoch(ms));
        return when.isAfter(current) ? when : null;
      case PrayerRecurrence.daily:
        final today = at(current);
        return today.isAfter(current) ? today : today.add(const Duration(days: 1));
      case PrayerRecurrence.weekly:
      case PrayerRecurrence.custom:
        final days = prayer.repeatWeekdays.isNotEmpty
            ? prayer.repeatWeekdays
            : (prayer.recurrence == PrayerRecurrence.weekly
                  ? [DateTime.fromMillisecondsSinceEpoch(prayer.createdAtMs).weekday]
                  : const <int>[]);
        for (var i = 0; i < 8; i++) {
          final day = DateTime(current.year, current.month, current.day + i);
          if (days.contains(day.weekday) && at(day).isAfter(current)) {
            return at(day);
          }
        }
        return null;
      case PrayerRecurrence.monthly:
        final anchorMs = prayer.onceDateMs ?? prayer.createdAtMs;
        final anchor = anchorMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(anchorMs)
            : current;
        for (var m = 0; m < 14; m++) {
          final lastDay = DateTime(current.year, current.month + m + 1, 0).day;
          final day = anchor.day > lastDay ? lastDay : anchor.day;
          final when = DateTime(
            current.year,
            current.month + m,
            day,
            prayer.hour,
            prayer.minute,
          );
          if (when.isAfter(current)) return when;
        }
        return null;
    }
  }

  int _notificationId(String id) {
    var hash = 19;
    for (final unit in id.codeUnits) {
      hash = ((hash * 37) + unit) & 0x7fffffff;
    }
    return (hash % 90000000) + 1;
  }
}
