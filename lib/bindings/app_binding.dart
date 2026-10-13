import 'package:get/get.dart';

import '../data/repositories/money_repository.dart';
import '../data/repositories/prayer_repository.dart';

/// App-level binding — runs once at startup.
/// Registers the global repositories permanently.
/// NOTE: HiveService and StorageService are static singletons initialised in
/// main.dart before runApp, and MoneyRepository is created there too (it has
/// to migrate stored data before any screen reads it).
class AppBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MoneyRepository>()) {
      Get.put(MoneyRepository(), permanent: true);
    }
    if (!Get.isRegistered<PrayerRepository>()) {
      Get.put(PrayerRepository(), permanent: true);
    }
  }
}
