import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../core/utils/currency_helper.dart';
import '../repositories/money_repository.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// App level notification preferences (the toggles in Settings) and the
/// finance related alerts that depend on them.
class NotificationCenter {
  NotificationCenter._();

  static const String masterKey = 'notifications_enabled';
  static const String dailyKey = 'notifications_daily_summary';
  static const String budgetKey = 'notifications_budget_alerts';
  static const String dailyHourKey = 'notifications_daily_hour';
  static const String dailyMinuteKey = 'notifications_daily_minute';
  static const String _alertLevelPrefix = 'budget_alert_level_';

  static const int _dailyReminderId = 9101;
  static const int _budgetAlertId = 9102;

  static bool get masterEnabled => StorageService.getBool(masterKey, fallback: true);
  static bool get dailyEnabled => StorageService.getBool(dailyKey, fallback: true);
  static bool get budgetEnabled => StorageService.getBool(budgetKey, fallback: true);
  static int get dailyHour =>
      StorageService.getInt(dailyHourKey, fallback: 21).clamp(0, 23).toInt();
  static int get dailyMinute =>
      StorageService.getInt(dailyMinuteKey).clamp(0, 59).toInt();

  static Future<void> setDailyTime(int hour, int minute) async {
    await StorageService.setInt(dailyHourKey, hour);
    await StorageService.setInt(dailyMinuteKey, minute);
    await syncDailyReminder();
  }

  /// (Re)schedules or cancels the evening "log your expenses" reminder
  /// according to the current preferences.
  static Future<void> syncDailyReminder() async {
    await NotificationService.cancel(_dailyReminderId);
    if (!masterEnabled || !dailyEnabled) return;

    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, dailyHour, dailyMinute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    await NotificationService.schedule(
      id: _dailyReminderId,
      title: 'How was your spending today?',
      body: 'Take a moment to log today\'s expenses so your balance stays right.',
      when: when,
      channelId: NotificationService.financeChannelId,
      repeat: DateTimeComponents.time,
      payload: 'finance',
    );
  }

  /// Called after an expense is saved: warns once when the cycle budget
  /// passes 80% and again at 100%.
  static Future<void> onExpenseSaved() async {
    try {
      if (!masterEnabled || !budgetEnabled) return;
      if (!Get.isRegistered<MoneyRepository>()) return;
      final repo = Get.find<MoneyRepository>();
      final monthId = repo.currentMonthId;
      final summary = repo.computeCycleSummary(monthId);
      if (summary.budget <= 0) return;

      final ratio = summary.spentTotal / summary.budget;
      final level = ratio >= 1 ? 100 : (ratio >= 0.8 ? 80 : 0);
      final key = '$_alertLevelPrefix$monthId';
      final previous = StorageService.getInt(key);
      if (level == 0) {
        if (previous != 0) await StorageService.setInt(key, 0);
        return;
      }
      if (level <= previous) return;

      await StorageService.setInt(key, level);
      await NotificationService.requestPermission();
      await NotificationService.showNow(
        id: _budgetAlertId,
        title: level >= 100 ? 'Budget used up' : '80% of your budget is gone',
        body: level >= 100
            ? 'You have spent ${CurrencyHelper.format(summary.spentTotal)} this cycle. '
                  'Only ${CurrencyHelper.format(summary.closingTotal)} is left.'
            : '${CurrencyHelper.format(summary.closingTotal)} left for '
                  '${summary.daysLeft()} more days '
                  '(about ${CurrencyHelper.format(summary.safePerDay())} a day).',
        payload: 'finance',
      );
    } catch (_) {
      // Alerts are best effort and must never break saving an expense.
    }
  }
}
