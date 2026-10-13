import 'dart:async';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_helper.dart';
import '../../../data/repositories/money_repository.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/prayer_times_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/weather_service.dart';
import '../../money_management/models/money_transaction.dart';
import '../../money_management/models/wallet.dart';

enum WeatherStatus { off, loading, ready, unavailable }

class DashboardController extends GetxController {
  final _repo = Get.find<MoneyRepository>();

  final greeting = ''.obs;
  final todayDateLabel = ''.obs;

  // Money
  final summary = Rxn<CycleSummary>();
  final recent = <MoneyTransaction>[].obs;
  final wallets = <Wallet>[].obs;
  final totalSavings = 0.0.obs;
  final spentToday = 0.0.obs;

  /// Spending so far minus what the previous cycle had spent by the same day.
  final trendDelta = 0.0.obs;
  final hasTrend = false.obs;

  // Weather
  final weather = Rxn<WeatherSnapshot>();
  final weatherStatus = WeatherStatus.off.obs;

  // Prayer
  final nextPrayer = Rxn<PrayerTimeEntry>();
  final currentPrayer = Rxn<PrayerTimeEntry>();
  final todayPrayers = <PrayerTimeEntry>[].obs;
  final nowMs = DateTime.now().millisecondsSinceEpoch.obs;

  Worker? _revisionWorker;
  Timer? _ticker;

  CycleSummary? get cycle => summary.value;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _revisionWorker = ever(_repo.revision, (_) => refreshMoney());
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      nowMs.value = DateTime.now().millisecondsSinceEpoch;
      _refreshPrayer();
    });
    loadWeather();
  }

  @override
  void onClose() {
    _revisionWorker?.dispose();
    _ticker?.cancel();
    super.onClose();
  }

  Future<void> refreshAll({bool forceWeather = false}) async {
    _updateGreeting();
    refreshMoney();
    _refreshPrayer();
    await loadWeather(force: forceWeather);
  }

  // ── Money ───────────────────────────────────────────────────

  void refreshMoney() {
    final now = DateTime.now();
    final monthId = _repo.monthIdFromDate(now);
    final current = _repo.computeCycleSummary(monthId);
    summary.value = current;
    wallets.assignAll(_repo.getWallets());
    totalSavings.value = wallets.fold(0.0, (s, w) => s + w.savingsBalance);
    spentToday.value = current.spentOn(now);

    recent.assignAll(
      _repo
          .getTransactions()
          .where((t) => t.category != MoneyRepository.adjustmentCategory)
          .take(5),
    );

    final previous = _repo.computeCycleSummary(_repo.previousMonthId(monthId));
    final elapsed = current.daysElapsed(now);
    var previousSoFar = 0.0;
    for (var i = 0; i < elapsed && i < previous.dailyExpenses.length; i++) {
      previousSoFar += previous.dailyExpenses[i];
    }
    hasTrend.value = previous.spentTotal > 0 && elapsed > 0;
    trendDelta.value = current.spentTotal - previousSoFar;
  }

  String get walletNameFallback => 'Unknown';

  String walletName(String id) =>
      wallets.firstWhereOrNull((w) => w.id == id)?.name ?? walletNameFallback;

  // ── Weather ─────────────────────────────────────────────────

  Future<void> loadWeather({bool force = false}) async {
    if (!LocationService.enabled) {
      weatherStatus.value = WeatherStatus.off;
      return;
    }
    final cached = WeatherService.cached;
    if (cached != null) weather.value = cached;
    if (!force && WeatherService.isFresh(cached)) {
      weatherStatus.value = WeatherStatus.ready;
      return;
    }

    weatherStatus.value = cached == null
        ? WeatherStatus.loading
        : WeatherStatus.ready;
    final fresh = await WeatherService.load(force: force);
    if (fresh != null) {
      weather.value = fresh;
      weatherStatus.value = WeatherStatus.ready;
    } else if (weather.value == null) {
      weatherStatus.value = WeatherStatus.unavailable;
    }
  }

  /// Asks for location permission and loads the weather. Returns the access
  /// result so the UI can explain what to do when it is denied.
  Future<LocationAccess> enableWeather() async {
    final access = await LocationService.enable();
    if (access == LocationAccess.granted) {
      weatherStatus.value = WeatherStatus.loading;
      await loadWeather(force: true);
      _refreshPrayer(); // prayer times use the new location too
    }
    return access;
  }

  // ── Prayer ──────────────────────────────────────────────────

  void _refreshPrayer() {
    final now = DateTime.now();
    todayPrayers.assignAll(
      PrayerTimesService.forDate(now).where((e) => e.key.isPrayer),
    );
    nextPrayer.value = PrayerTimesService.next(now: now);
    currentPrayer.value = PrayerTimesService.current(now: now);
  }

  Duration? get untilNextPrayer {
    final next = nextPrayer.value;
    if (next == null) return null;
    return next.time.difference(DateTime.fromMillisecondsSinceEpoch(nowMs.value));
  }

  // ── Misc ────────────────────────────────────────────────────

  void _updateGreeting() {
    final displayName = StorageService.getString('profile_display_name').trim();
    final first = StorageService.getString('first_name').trim();
    final last = StorageService.getString('last_name').trim();
    final fullName = displayName.isNotEmpty
        ? displayName
        : [first, last].where((v) => v.isNotEmpty).join(' ');
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final name = fullName.trim().isEmpty ? 'Friend' : parts.last;

    greeting.value = '${DateHelper.greeting()}, $name';
    todayDateLabel.value = DateFormat('EEEE, d MMMM').format(DateTime.now());
  }
}
