import 'package:hive_flutter/hive_flutter.dart';

/// Central Hive initialization service.
/// Call [HiveService.init()] once at app startup in main.dart before runApp.
class HiveService {
  HiveService._();

  // Box names — use these constants, never raw strings
  static const String moneyWalletBox = 'mm_wallets';
  static const String moneyTransactionBox = 'mm_transactions';
  static const String moneyTransferBox = 'mm_transfers';
  static const String moneySavingsBox = 'mm_savings_entries';

  // Legacy boxes: only read once while migrating older data, then emptied.
  static const String moneyMonthlyFundBox = 'mm_monthly_funds';
  static const String moneySourceBox = 'mm_sources';
  static const String moneyMetaBox = 'mm_meta';

  static const String prayerReminderBox = 'prayer_reminders';

  /// Initializes Hive and opens all boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    await Future.wait([
      Hive.openBox(moneyWalletBox),
      Hive.openBox(moneyTransactionBox),
      Hive.openBox(moneyTransferBox),
      Hive.openBox(moneySavingsBox),
      Hive.openBox(moneyMonthlyFundBox),
      Hive.openBox(moneySourceBox),
      Hive.openBox(moneyMetaBox),
      Hive.openBox(prayerReminderBox),
    ]);
  }

  /// Returns an already-opened box. Throws if box is not open.
  static Box box(String name) => Hive.box(name);
}
