import 'package:adhan/adhan.dart';

import 'location_service.dart';
import 'storage_service.dart';

enum PrayerKey { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerKeyX on PrayerKey {
  String get id => name;

  /// The five obligatory prayers (sunrise is informational only).
  bool get isPrayer => this != PrayerKey.sunrise;

  String label({bool friday = false}) {
    switch (this) {
      case PrayerKey.fajr:
        return 'Fajr';
      case PrayerKey.sunrise:
        return 'Sunrise';
      case PrayerKey.dhuhr:
        return friday ? 'Jumu\'ah' : 'Dhuhr';
      case PrayerKey.asr:
        return 'Asr';
      case PrayerKey.maghrib:
        return 'Maghrib';
      case PrayerKey.isha:
        return 'Isha';
    }
  }
}

class PrayerTimeEntry {
  const PrayerTimeEntry({
    required this.key,
    required this.name,
    required this.time,
  });

  final PrayerKey key;
  final String name;
  final DateTime time;
}

class PrayerMethodOption {
  const PrayerMethodOption(this.id, this.label, this.method);

  final String id;
  final String label;
  final CalculationMethod method;
}

/// Offline prayer time calculation (adhan) plus the user's preferences.
class PrayerTimesService {
  PrayerTimesService._();

  static const String autoKey = 'prayer_auto_v1';
  static const String methodKey = 'prayer_method_v1';
  static const String madhabKey = 'prayer_madhab_v1';
  static const String leadKey = 'prayer_lead_min_v1';
  static const String atTimeKey = 'prayer_at_time_v1';

  static const List<PrayerMethodOption> methods = [
    PrayerMethodOption('karachi', 'Karachi (Bangladesh, Pakistan, India)',
        CalculationMethod.karachi),
    PrayerMethodOption('mwl', 'Muslim World League',
        CalculationMethod.muslim_world_league),
    PrayerMethodOption('egyptian', 'Egyptian General Authority',
        CalculationMethod.egyptian),
    PrayerMethodOption('umm_al_qura', 'Umm al-Qura (Makkah)',
        CalculationMethod.umm_al_qura),
    PrayerMethodOption('north_america', 'ISNA (North America)',
        CalculationMethod.north_america),
    PrayerMethodOption('singapore', 'Singapore / Malaysia',
        CalculationMethod.singapore),
    PrayerMethodOption('turkey', 'Turkey (Diyanet)', CalculationMethod.turkey),
  ];

  static const List<int> leadOptions = [0, 5, 10, 15, 20, 30];

  static bool get autoEnabled => StorageService.getBool(autoKey, fallback: true);

  static String get methodId =>
      StorageService.getString(methodKey, fallback: 'karachi');

  static PrayerMethodOption get methodOption => methods.firstWhere(
    (m) => m.id == methodId,
    orElse: () => methods.first,
  );

  /// Hanafi is the norm in Bangladesh; Shafi'i/Maliki/Hanbali use `shafi`.
  static bool get hanafi =>
      StorageService.getString(madhabKey, fallback: 'hanafi') == 'hanafi';

  static int get leadMinutes =>
      StorageService.getInt(leadKey, fallback: 10).clamp(0, 120).toInt();

  static bool get notifyAtTime =>
      StorageService.getBool(atTimeKey, fallback: true);

  /// Per-prayer minute offset, e.g. +10 to follow the local masjid jamaat.
  static int offset(PrayerKey key) =>
      StorageService.getInt('prayer_adj_${key.id}').clamp(-60, 60).toInt();

  static Future<void> setOffset(PrayerKey key, int minutes) =>
      StorageService.setInt('prayer_adj_${key.id}', minutes.clamp(-60, 60).toInt());

  static bool remindFor(PrayerKey key) =>
      StorageService.getBool('prayer_remind_${key.id}', fallback: true);

  static Future<void> setRemindFor(PrayerKey key, bool value) =>
      StorageService.setBool('prayer_remind_${key.id}', value);

  static Future<void> setAuto(bool v) => StorageService.setBool(autoKey, v);
  static Future<void> setMethod(String id) =>
      StorageService.setString(methodKey, id);
  static Future<void> setHanafi(bool v) =>
      StorageService.setString(madhabKey, v ? 'hanafi' : 'shafi');
  static Future<void> setLead(int v) => StorageService.setInt(leadKey, v);
  static Future<void> setNotifyAtTime(bool v) =>
      StorageService.setBool(atTimeKey, v);

  static CalculationParameters _parameters() {
    final params = methodOption.method.getParameters();
    params.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    params.adjustments.fajr = offset(PrayerKey.fajr);
    params.adjustments.sunrise = offset(PrayerKey.sunrise);
    params.adjustments.dhuhr = offset(PrayerKey.dhuhr);
    params.adjustments.asr = offset(PrayerKey.asr);
    params.adjustments.maghrib = offset(PrayerKey.maghrib);
    params.adjustments.isha = offset(PrayerKey.isha);
    return params;
  }

  /// All six times for [date] in the device time zone.
  static List<PrayerTimeEntry> forDate(DateTime date, {AppLocation? location}) {
    final loc = location ?? LocationService.cached;
    final times = PrayerTimes(
      Coordinates(loc.latitude, loc.longitude),
      DateComponents(date.year, date.month, date.day),
      _parameters(),
    );
    final friday = date.weekday == DateTime.friday;
    DateTime local(DateTime t) => t.toLocal();
    PrayerTimeEntry entry(PrayerKey key, DateTime t) => PrayerTimeEntry(
      key: key,
      name: key.label(friday: friday),
      time: local(t),
    );
    return [
      entry(PrayerKey.fajr, times.fajr),
      entry(PrayerKey.sunrise, times.sunrise),
      entry(PrayerKey.dhuhr, times.dhuhr),
      entry(PrayerKey.asr, times.asr),
      entry(PrayerKey.maghrib, times.maghrib),
      entry(PrayerKey.isha, times.isha),
    ];
  }

  /// The next obligatory prayer after [now].
  static PrayerTimeEntry? next({DateTime? now}) {
    final moment = now ?? DateTime.now();
    for (var i = 0; i < 3; i++) {
      final day = DateTime(moment.year, moment.month, moment.day + i);
      for (final entry in forDate(day)) {
        if (entry.key.isPrayer && entry.time.isAfter(moment)) return entry;
      }
    }
    return null;
  }

  /// The prayer whose window we are currently in (last one that started).
  static PrayerTimeEntry? current({DateTime? now}) {
    final moment = now ?? DateTime.now();
    PrayerTimeEntry? last;
    for (var i = -1; i <= 0; i++) {
      final day = DateTime(moment.year, moment.month, moment.day + i);
      for (final entry in forDate(day)) {
        if (entry.key.isPrayer && !entry.time.isAfter(moment)) last = entry;
      }
    }
    return last;
  }
}
