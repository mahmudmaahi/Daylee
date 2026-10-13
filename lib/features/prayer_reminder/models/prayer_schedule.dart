import 'package:flutter/material.dart';

enum PrayerRecurrence { once, daily, weekly, custom, monthly }

PrayerRecurrence prayerRecurrenceFromString(String value) {
  switch (value) {
    case 'once':
      return PrayerRecurrence.once;
    case 'weekly':
      return PrayerRecurrence.weekly;
    case 'custom':
      return PrayerRecurrence.custom;
    case 'monthly':
      return PrayerRecurrence.monthly;
    case 'daily':
    default:
      return PrayerRecurrence.daily;
  }
}

String prayerRecurrenceToString(PrayerRecurrence value) {
  switch (value) {
    case PrayerRecurrence.once:
      return 'once';
    case PrayerRecurrence.daily:
      return 'daily';
    case PrayerRecurrence.weekly:
      return 'weekly';
    case PrayerRecurrence.custom:
      return 'custom';
    case PrayerRecurrence.monthly:
      return 'monthly';
  }
}

class PrayerSchedule {
  PrayerSchedule({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.reminderMinutesBefore,
    required this.isEnabled,
    required this.notificationId,
    this.recurrence = PrayerRecurrence.daily,
    this.repeatWeekdays = const [],
    this.onceDateMs,
    this.note = '',
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String name;
  final int hour;
  final int minute;
  final int reminderMinutesBefore;
  final bool isEnabled;
  final PrayerRecurrence recurrence;
  final List<int> repeatWeekdays;
  final int? onceDateMs;
  final String note;
  final int notificationId;
  final int createdAtMs;
  final int updatedAtMs;

  TimeOfDay get prayerTime => TimeOfDay(hour: hour, minute: minute);

  int get timeInMinutes => (hour * 60) + minute;

  PrayerSchedule copyWith({
    String? id,
    String? name,
    int? hour,
    int? minute,
    int? reminderMinutesBefore,
    bool? isEnabled,
    PrayerRecurrence? recurrence,
    List<int>? repeatWeekdays,
    int? onceDateMs,
    String? note,
    int? notificationId,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return PrayerSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      isEnabled: isEnabled ?? this.isEnabled,
      recurrence: recurrence ?? this.recurrence,
      repeatWeekdays: repeatWeekdays ?? this.repeatWeekdays,
      onceDateMs: onceDateMs ?? this.onceDateMs,
      note: note ?? this.note,
      notificationId: notificationId ?? this.notificationId,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': 2,
      'id': id,
      'name': name,
      'hour': hour,
      'minute': minute,
      'reminderMinutesBefore': reminderMinutesBefore,
      'isEnabled': isEnabled,
      'recurrence': prayerRecurrenceToString(recurrence),
      'repeatWeekdays': repeatWeekdays,
      'onceDateMs': onceDateMs,
      'note': note,
      'notificationId': notificationId,
      'createdAt': createdAtMs,
      'updatedAt': updatedAtMs,
    };
  }

  factory PrayerSchedule.fromMap(Map<String, dynamic> map) {
    final reminder =
        (map['reminderMinutesBefore'] as num?)?.toInt() ??
        (map['reminderOffsetMinutes'] as num?)?.toInt() ??
        10;

    final rawWeekdays = map['repeatWeekdays'];
    final parsedWeekdays = <int>{};
    if (rawWeekdays is List) {
      for (final item in rawWeekdays) {
        final day = (item as num?)?.toInt() ?? int.tryParse(item.toString());
        if (day != null && day >= DateTime.monday && day <= DateTime.sunday) {
          parsedWeekdays.add(day);
        }
      }
    }

    final recurrence = prayerRecurrenceFromString(
      (map['recurrence'] as String?) ?? 'daily',
    );

    List<int> weekdays;
    if (parsedWeekdays.isNotEmpty) {
      weekdays = parsedWeekdays.toList()..sort();
    } else if (recurrence == PrayerRecurrence.daily) {
      weekdays = [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ];
    } else if (recurrence == PrayerRecurrence.weekly) {
      final createdAt = (map['createdAt'] as num?)?.toInt() ?? 0;
      final createdDate = createdAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(createdAt)
          : DateTime.now();
      weekdays = [createdDate.weekday];
    } else {
      weekdays = const [];
    }

    return PrayerSchedule(
      id: (map['id'] as String?) ?? '',
      name: ((map['name'] as String?) ?? 'Prayer').trim(),
      hour: ((map['hour'] as num?)?.toInt() ?? 5).clamp(0, 23),
      minute: ((map['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
      reminderMinutesBefore: reminder.clamp(1, 180),
      isEnabled: map['isEnabled'] == true,
      recurrence: recurrence,
      repeatWeekdays: weekdays,
      onceDateMs: (map['onceDateMs'] as num?)?.toInt(),
      note: ((map['note'] as String?) ?? '').trim(),
      notificationId: (map['notificationId'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['createdAt'] as num?)?.toInt() ?? 0,
      updatedAtMs: (map['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
