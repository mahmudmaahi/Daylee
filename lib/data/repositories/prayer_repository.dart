import 'package:hive/hive.dart';

import '../../features/prayer_reminder/models/prayer_schedule.dart';
import '../services/hive_service.dart';

/// Data access layer for prayer reminders.
class PrayerRepository {
  Box get _box => HiveService.box(HiveService.prayerReminderBox);

  List<PrayerSchedule> getAllPrayers() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .map(PrayerSchedule.fromMap)
        .where((item) => item.id.trim().isNotEmpty)
        .toList();

    list.sort((a, b) => a.timeInMinutes.compareTo(b.timeInMinutes));
    return list;
  }

  Future<void> savePrayer(PrayerSchedule prayer) {
    return _box.put(prayer.id, prayer.toMap());
  }

  Future<void> deletePrayer(String id) {
    return _box.delete(id);
  }

  PrayerSchedule? getPrayer(String id) {
    final value = _box.get(id);
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final parsed = PrayerSchedule.fromMap(map);
    if (parsed.id.trim().isEmpty) return null;
    return parsed;
  }

  Future<void> clearAll() => _box.clear();
}
