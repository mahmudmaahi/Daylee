import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import '../../../core/bootstrap.dart';
import '../../../core/security/app_lock_policy.dart';
import '../../../core/theme/app_appearance.dart';
import '../../../data/repositories/money_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/category_service.dart';
import '../../../data/services/hive_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/notification_center.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/weather_service.dart';
import '../../../data/services/storage_service.dart';
import '../../money_management/models/money_transaction.dart';

class ProfileController extends GetxController {
  ProfileController();

  final _moneyRepo = Get.find<MoneyRepository>();
  final _imagePicker = ImagePicker();

  static const String _displayNameKey = 'profile_display_name';
  static const String _bioKey = 'profile_bio';
  static const String _joinDateKey = 'profile_joined_ms';
  static const String _backupAtKey = 'last_backup_ms';

  final firstName = 'Day'.obs;
  final lastName = 'Lee'.obs;
  final displayName = ''.obs;
  final bio = ''.obs;
  final phoneNumber = ''.obs;
  final email = ''.obs;
  final profilePhotoBase64 = ''.obs;
  final joinDateMs = 0.obs;

  final notificationsEnabled = true.obs;
  final dailySummaryEnabled = true.obs;
  final budgetAlertsEnabled = true.obs;
  final dailyReminderTime = const TimeOfDay(hour: 21, minute: 0).obs;
  final locationEnabled = false.obs;

  final currency = 'BDT (৳)'.obs;
  final cycleStartDay = 25.obs;
  final transactionCategories = <String>[].obs;

  final themePreference = AppThemePreference.system.obs;
  final accentColorValue = 0.obs;
  final fontScale = 1.0.obs;
  final uiDensityPreference = UiDensityPreference.comfortable.obs;

  final pinLockEnabled = false.obs;
  final useBiometrics = true.obs;
  final lockDelaySeconds = 60.obs;

  final totalSavings = 0.0.obs;
  final monthlySpendingAverage = 0.0.obs;
  final lastBackupAtMs = 0.obs;
  final statsReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreFromStorage();
    _hydrateStatsSnapshot();
    Future<void>(loadStats);
  }

  String get fullName => '${firstName.value} ${lastName.value}'.trim();

  String get profileDisplayName {
    final custom = displayName.value.trim();
    if (custom.isNotEmpty) return custom;
    final base = fullName.trim();
    if (base.isNotEmpty) return base;
    return 'DayLee User';
  }

  String get joinDateLabel {
    final value = joinDateMs.value;
    if (value <= 0) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    return DateFormat('MMM d, yyyy').format(date);
  }

  String get lockDelayLabel => AppLockPolicy.delayLabel(lockDelaySeconds.value);

  String get syncStatusLabel {
    if (lastBackupAtMs.value <= 0) return 'No backup yet';

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastBackupAtMs.value),
    );

    if (diff.inHours < 24) return 'Synced today';
    if (diff.inDays == 1) return 'Last synced 1 day ago';
    return 'Last synced ${diff.inDays} days ago';
  }

  Future<void> loadStats() async {
    _hydrateStatsSnapshot();
  }

  void _hydrateStatsSnapshot() {
    totalSavings.value = _moneyRepo.totalSavings;
    monthlySpendingAverage.value = _computeMonthlySpendingAverage();
    cycleStartDay.value = _moneyRepo.cycleStartDay;
    lastBackupAtMs.value = StorageService.getInt(_backupAtKey);
    statsReady.value = true;
  }

  double _computeMonthlySpendingAverage() {
    final grouped = <String, double>{};
    final txs = _moneyRepo.getTransactions();

    for (final tx in txs) {
      if (tx.type != MoneyTransactionType.expense) continue;
      if (tx.category == MoneyRepository.adjustmentCategory) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(tx.dateMs);
      final cycleId = _moneyRepo.monthIdFromDate(date);
      grouped[cycleId] = (grouped[cycleId] ?? 0) + tx.amount;
    }

    if (grouped.isEmpty) return 0;

    final values = grouped.values.toList(growable: false);
    final total = values.fold<double>(0, (sum, amount) => sum + amount);
    return total / values.length;
  }

  Future<void> updateUserInfo({
    required String first,
    required String last,
    required String userName,
    required String shortBio,
    required String phone,
    required String emailAddress,
  }) async {
    firstName.value = first.trim().isEmpty ? 'Day' : first.trim();
    lastName.value = last.trim().isEmpty ? 'Lee' : last.trim();
    displayName.value = userName.trim();
    bio.value = shortBio.trim();
    phoneNumber.value = phone.trim();
    email.value = emailAddress.trim();

    await StorageService.setString('first_name', firstName.value);
    await StorageService.setString('last_name', lastName.value);
    await StorageService.setString(_displayNameKey, displayName.value);
    await StorageService.setString(_bioKey, bio.value);
    await StorageService.setString('phone_number', phoneNumber.value);
    await StorageService.setString('email_address', email.value);
  }

  Future<void> pickProfilePhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 68,
      requestFullMetadata: true,
    );

    if (photo == null) return;

    try {
      final bytes = await photo.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Get.snackbar('Error', 'Failed to process profile photo.');
        return;
      }

      final baked = img.bakeOrientation(decoded);
      final normalizedBytes = img.encodeJpg(baked, quality: 90);
      final encoded = base64Encode(normalizedBytes);

      profilePhotoBase64.value = encoded;
      await StorageService.setString('profile_photo_base64', encoded);
      Get.snackbar('Success', 'Profile photo updated.');
    } catch (e) {
      Get.snackbar('Error', 'Failed to save profile photo.');
    }
  }

  Future<void> removeProfilePhoto() async {
    profilePhotoBase64.value = '';
    await StorageService.setString('profile_photo_base64', '');
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    themePreference.value = preference;
    await StorageService.setString(
      AppAppearance.themeModeKey,
      AppAppearance.encodeThemePreference(preference),
    );

    if (preference == AppThemePreference.dark) {
      await StorageService.setDarkMode(true);
    } else if (preference == AppThemePreference.light) {
      await StorageService.setDarkMode(false);
    }

    await _applyAppearance();
  }

  Future<void> setAccentColor(Color color) async {
    final argb = color.toARGB32();
    accentColorValue.value = argb;
    await StorageService.setInt(AppAppearance.accentColorKey, argb);
    await _applyAppearance();
  }

  Future<void> setFontScale(double value) async {
    final next = value.clamp(0.9, 1.2).toDouble();
    fontScale.value = next;
    await StorageService.setDouble(AppAppearance.fontScaleKey, next);
    await _applyAppearance();
  }

  Future<void> setUiDensity(UiDensityPreference value) async {
    uiDensityPreference.value = value;
    await StorageService.setString(
      AppAppearance.uiDensityKey,
      AppAppearance.encodeUiDensity(value),
    );
    await _applyAppearance();
  }

  Future<void> _applyAppearance() async {
    AppAppearance.notifyAppearanceChanged();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled.value = value;
    await StorageService.setBool(NotificationCenter.masterKey, value);
    if (value) {
      final allowed = await NotificationService.requestPermission();
      if (!allowed) {
        Get.snackbar(
          'Notifications blocked',
          'Allow notifications for DayLee in your phone settings to get reminders.',
        );
      }
    }
    await AppBootstrap.resync(force: true);
  }

  Future<void> setDailySummary(bool value) async {
    dailySummaryEnabled.value = value;
    await StorageService.setBool(NotificationCenter.dailyKey, value);
    if (value) await NotificationService.requestPermission();
    await NotificationCenter.syncDailyReminder();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    dailyReminderTime.value = time;
    await NotificationCenter.setDailyTime(time.hour, time.minute);
  }

  Future<void> setBudgetAlerts(bool value) async {
    budgetAlertsEnabled.value = value;
    await StorageService.setBool(NotificationCenter.budgetKey, value);
  }

  /// Turns location (weather + exact prayer times) on or off.
  Future<LocationAccess> setLocationEnabled(bool value) async {
    if (!value) {
      await LocationService.disable();
      locationEnabled.value = false;
      await WeatherService.clearCache();
      return LocationAccess.off;
    }
    final access = await LocationService.enable();
    locationEnabled.value = access == LocationAccess.granted;
    if (access == LocationAccess.granted) {
      await LocationService.refresh();
      await WeatherService.load(force: true);
      await AppBootstrap.resync(force: true);
    }
    return access;
  }

  Future<void> setCurrency(String value) async {
    currency.value = value;
    await StorageService.setString('currency', value);
    // Amounts are formatted when built; rebuild everything to show the symbol.
    AppAppearance.notifyAppearanceChanged();
    Get.forceAppUpdate();
  }

  Future<void> setCycleStartDay(int value) async {
    final day = value.clamp(1, 28);
    await _moneyRepo.setCycleStartDay(day);
    cycleStartDay.value = _moneyRepo.cycleStartDay;
    await loadStats();
    Get.snackbar('Finance', 'Cycle starts on day $day now.');
  }

  Future<String?> addCustomCategory(String input) async {
    final created = await CategoryService.addCustom(input);
    _loadTransactionCategories();
    return created;
  }

  Future<bool> deleteCustomCategory(String category) async {
    if (CategoryService.isDefault(CategoryService.normalize(category))) {
      Get.snackbar('Category', 'Default categories cannot be deleted.');
      return false;
    }
    final ok = await CategoryService.removeCustom(category);
    _loadTransactionCategories();
    return ok;
  }

  bool isDefaultCategory(String category) => CategoryService.isDefault(category);

  Future<void> setPinLock(bool value) async {
    if (!value) {
      pinLockEnabled.value = false;
      await StorageService.setBool(AppLockPolicy.enabledKey, false);
      Get.snackbar('Security', 'App lock disabled.');
      return;
    }

    final isSupported = await AuthService.isDeviceAuthenticationAvailable();
    if (!isSupported) {
      pinLockEnabled.value = false;
      await StorageService.setBool(AppLockPolicy.enabledKey, false);
      Get.snackbar('Security', 'Device authentication is not available.');
      return;
    }

    final verified = await AuthService.authenticate(
      localizedReason: 'Authenticate once to enable app lock.',
    );

    if (!verified) {
      pinLockEnabled.value = false;
      await StorageService.setBool(AppLockPolicy.enabledKey, false);
      Get.snackbar('Security', 'Authentication cancelled.');
      return;
    }

    pinLockEnabled.value = true;
    await StorageService.setBool(AppLockPolicy.enabledKey, true);

    if (StorageService.getInt(AppLockPolicy.delaySecondsKey, fallback: -1) <
        0) {
      await StorageService.setInt(AppLockPolicy.delaySecondsKey, 60);
    }

    Get.snackbar('Security', 'App lock enabled.');
  }

  Future<void> setUseBiometrics(bool value) async {
    useBiometrics.value = value;
    await StorageService.setBool(AppLockPolicy.useBiometricsKey, value);
  }

  Future<void> setLockDelay(int seconds) async {
    final safe = AppLockPolicy.sanitizeDelay(seconds);
    lockDelaySeconds.value = safe;
    await StorageService.setInt(AppLockPolicy.delaySecondsKey, safe);
  }

  Future<void> openDeviceSecuritySettings() async {
    await openAppSettings();
  }

  /// Saves a file with the system "save as" dialog (no storage permission
  /// needed). Returns true when the user picked a location.
  Future<bool> _saveFile({
    required String dialogTitle,
    required String fileName,
    required String content,
    required String extension,
  }) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return path != null;
  }

  Future<void> exportMonthlyExpensesCsv() async {
    try {
      final cycleId = _moneyRepo.currentMonthId;
      final csv = _moneyRepo.buildMonthlyExpenseCsv(monthId: cycleId);
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final saved = await _saveFile(
        dialogTitle: 'Save finance report',
        fileName: 'daylee_expenses_${cycleId}_$stamp.csv',
        content: csv,
        extension: 'csv',
      );
      if (saved) {
        Get.snackbar(
          'Export complete',
          'Report for ${_moneyRepo.cycleLabelFromId(cycleId)} saved.',
        );
      }
    } catch (_) {
      Get.snackbar('Export failed', 'Could not export the expenses CSV.');
    }
  }

  Future<void> backupAllDataToDocuments() async {
    try {
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final payload = await _buildBackupPayload();
      final saved = await _saveFile(
        dialogTitle: 'Save DayLee backup',
        fileName: 'daylee_backup_$stamp.json',
        content: const JsonEncoder.withIndent('  ').convert(payload),
        extension: 'json',
      );
      if (!saved) return;

      await StorageService.setInt(
        _backupAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      lastBackupAtMs.value = StorageService.getInt(_backupAtKey);
      Get.snackbar('Backup complete', 'Keep the file somewhere safe.');
    } catch (_) {
      Get.snackbar('Backup failed', 'Could not create the backup file.');
    }
  }

  Future<void> restoreDataFromBackupFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: 'Select Daylee backup file',
      );

      if (picked == null || picked.files.isEmpty) return;

      final picked0 = picked.files.single;
      final path = picked0.path;
      String content;
      if (path != null && path.trim().isNotEmpty && await File(path).exists()) {
        content = await File(path).readAsString();
      } else if (picked0.bytes != null) {
        content = utf8.decode(picked0.bytes!);
      } else {
        Get.snackbar('Restore failed', 'Could not read the selected file.');
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        Get.snackbar('Restore failed', 'Backup format is invalid.');
        return;
      }

      final ok = await _applyBackupPayload(Map<String, dynamic>.from(decoded));
      if (!ok) return;

      // Backups from older versions need converting to the ledger format.
      await _moneyRepo.init();
      _moneyRepo.revision.value++;
      _restoreFromStorage();
      await loadStats();
      update();
      AppAppearance.notifyAppearanceChanged();
      await AppBootstrap.resync(force: true);

      Get.snackbar('Restore complete', 'Your backup has been restored.');
    } catch (_) {
      Get.snackbar('Restore Failed', 'Could not restore backup file.');
    }
  }

  Future<void> resetAllData() async {
    await NotificationService.cancelAll();

    for (final boxName in _managedBoxNames) {
      await HiveService.box(boxName).clear();
    }

    final keys = StorageService.getKeys().toList(growable: false);
    for (final key in keys) {
      await StorageService.remove(key);
    }

    // A fresh start needs no conversion of old data.
    await StorageService.setBool('money_ledger_v2_done', true);
    await _moneyRepo.ensureDefaultWallets();
    _moneyRepo.revision.value++;

    _restoreFromStorage();
    await loadStats();
    update();
    AppAppearance.notifyAppearanceChanged();
    await AppBootstrap.resync(force: true);
  }

  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final boxNames = _managedBoxNames;
    final boxes = <String, dynamic>{};
    for (final boxName in boxNames) {
      final box = HiveService.box(boxName);
      boxes[boxName] = _serializeBox(box);
    }

    final preferences = <String, dynamic>{};
    for (final key in StorageService.getKeys()) {
      if (key.startsWith('flutter.')) continue;
      final value = StorageService.getValue(key);
      preferences[key] = _toJsonSafe(value);
    }

    return {
      'schemaVersion': 2,
      'app': 'daylee',
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'hiveBoxes': boxes,
      'preferences': preferences,
    };
  }

  Future<bool> _applyBackupPayload(Map<String, dynamic> payload) async {
    final rawBoxes = payload['hiveBoxes'];
    final rawPreferences = payload['preferences'];

    if (rawBoxes is! Map || rawPreferences is! Map) {
      Get.snackbar('Restore Failed', 'Backup payload is incomplete.');
      return false;
    }

    for (final boxName in _managedBoxNames) {
      final box = HiveService.box(boxName);
      await box.clear();

      final boxData = rawBoxes[boxName];
      if (boxData is! Map) continue;

      for (final entry in boxData.entries) {
        await box.put(entry.key, _fromJsonSafe(entry.value));
      }
    }

    final existingKeys = StorageService.getKeys();
    for (final key in existingKeys) {
      if (key.startsWith('flutter.')) continue;
      await StorageService.remove(key);
    }

    for (final entry in rawPreferences.entries) {
      final key = entry.key.toString();
      final value = _fromJsonSafe(entry.value);
      if (value is List<dynamic>) {
        await StorageService.setValue(
          key,
          value.map((e) => e.toString()).toList(growable: false),
        );
      } else {
        await StorageService.setValue(key, value);
      }
    }

    return true;
  }

  Map<String, dynamic> _serializeBox(Box box) {
    final map = <String, dynamic>{};
    for (final key in box.keys) {
      map[key.toString()] = _toJsonSafe(box.get(key));
    }
    return map;
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return {'__type': 'DateTime', 'value': value.toIso8601String()};
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] = _toJsonSafe(entry.value);
      }
      return out;
    }
    if (value is List) {
      return value.map(_toJsonSafe).toList(growable: false);
    }
    return value.toString();
  }

  dynamic _fromJsonSafe(dynamic value) {
    if (value is Map) {
      if (value['__type'] == 'DateTime') {
        final raw = value['value']?.toString() ?? '';
        final parsed = DateTime.tryParse(raw);
        return parsed ?? DateTime.now();
      }
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        out[entry.key.toString()] = _fromJsonSafe(entry.value);
      }
      return out;
    }
    if (value is List) {
      return value.map(_fromJsonSafe).toList(growable: false);
    }
    return value;
  }

  void _loadTransactionCategories() {
    transactionCategories.assignAll(CategoryService.expenseCategories());
  }

  String displayCategory(String value) => CategoryService.label(value);

  void _restoreFromStorage() {
    firstName.value = StorageService.getString('first_name', fallback: 'Day');
    lastName.value = StorageService.getString('last_name', fallback: 'Lee');
    displayName.value = StorageService.getString(_displayNameKey);
    bio.value = StorageService.getString(_bioKey);
    phoneNumber.value = StorageService.getString('phone_number');
    email.value = StorageService.getString('email_address');
    profilePhotoBase64.value = StorageService.getString('profile_photo_base64');

    final joinMs = StorageService.getInt(_joinDateKey);
    if (joinMs <= 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      joinDateMs.value = nowMs;
      StorageService.setInt(_joinDateKey, nowMs);
    } else {
      joinDateMs.value = joinMs;
    }

    notificationsEnabled.value = StorageService.getBool(
      NotificationCenter.masterKey,
      fallback: true,
    );
    dailySummaryEnabled.value = NotificationCenter.dailyEnabled;
    budgetAlertsEnabled.value = NotificationCenter.budgetEnabled;
    dailyReminderTime.value = TimeOfDay(
      hour: NotificationCenter.dailyHour,
      minute: NotificationCenter.dailyMinute,
    );
    locationEnabled.value = LocationService.enabled;

    currency.value = StorageService.getString('currency', fallback: 'BDT (৳)');
    cycleStartDay.value = _moneyRepo.cycleStartDay;
    _loadTransactionCategories();

    final legacyIsDark = StorageService.isDarkMode;
    themePreference.value = AppAppearance.parseThemePreference(
      StorageService.getString(
        AppAppearance.themeModeKey,
        fallback: legacyIsDark
            ? AppAppearance.encodeThemePreference(AppThemePreference.dark)
            : AppAppearance.encodeThemePreference(AppThemePreference.system),
      ),
    );

    accentColorValue.value = StorageService.getInt(
      AppAppearance.accentColorKey,
      fallback: AppAppearance.accentPresets.first.toARGB32(),
    );

    fontScale.value = StorageService.getDouble(
      AppAppearance.fontScaleKey,
      fallback: 1.0,
    ).clamp(0.9, 1.2).toDouble();

    uiDensityPreference.value = AppAppearance.parseUiDensity(
      StorageService.getString(
        AppAppearance.uiDensityKey,
        fallback: AppAppearance.encodeUiDensity(
          UiDensityPreference.comfortable,
        ),
      ),
    );

    pinLockEnabled.value = StorageService.getBool(AppLockPolicy.enabledKey);
    useBiometrics.value = StorageService.getBool(
      AppLockPolicy.useBiometricsKey,
      fallback: true,
    );
    lockDelaySeconds.value = AppLockPolicy.sanitizeDelay(
      StorageService.getInt(AppLockPolicy.delaySecondsKey, fallback: 60),
    );

    lastBackupAtMs.value = StorageService.getInt(_backupAtKey);
  }

  List<String> get _managedBoxNames => const [
    HiveService.moneyWalletBox,
    HiveService.moneyTransactionBox,
    HiveService.moneyTransferBox,
    HiveService.moneyMonthlyFundBox,
    HiveService.moneySavingsBox,
    HiveService.moneySourceBox,
    HiveService.moneyMetaBox,
    HiveService.prayerReminderBox,
  ];
}
