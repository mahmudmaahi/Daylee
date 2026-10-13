import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'core/app_info.dart';
import 'core/bootstrap.dart';
import 'data/repositories/money_repository.dart';
import 'data/repositories/prayer_repository.dart';
import 'data/services/hive_service.dart';
import 'data/services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage first: everything else depends on it.
  await StorageService.init();
  await AppInfo.load();
  await HiveService.init();

  // The finance ledger migrates data written by older versions here, before
  // any screen can read it.
  final money = Get.put(MoneyRepository(), permanent: true);
  await money.init();
  Get.put(PrayerRepository(), permanent: true);

  runApp(const DayleeApp());

  // Notifications never block start-up.
  unawaited(AppBootstrap.afterFirstFrame());
}
