import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../common/widgets/app_bottom_nav.dart';
import '../../../common/widgets/app_card.dart';
import '../../../common/widgets/app_global_header.dart';
import '../../../common/widgets/app_sheet.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_appearance.dart';
import '../../../core/utils/currency_helper.dart';
import '../../../data/services/category_service.dart';
import '../../../data/services/location_service.dart';
import '../../../data/services/weather_service.dart';
import '../../money_management/models/money_transaction.dart';
import '../controllers/dashboard_controller.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppGlobalHeader(showBottomDivider: true),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refreshAll(forceWeather: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              _Greeting(controller: controller),
              const SizedBox(height: AppSpacing.lg),
              _BalanceHero(controller: controller),
              const SizedBox(height: AppSpacing.md),
              _StatTiles(controller: controller),
              const SizedBox(height: AppSpacing.md),
              _WeatherCard(controller: controller),
              const SizedBox(height: AppSpacing.md),
              _PrayerCard(controller: controller),
              const SizedBox(height: AppSpacing.lg),
              const _QuickActions(),
              const SizedBox(height: AppSpacing.lg),
              _RecentActivity(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.greeting.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            controller.todayDateLabel.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Balance ───────────────────────────────────────────────────

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final c = controller.summary.value;
      if (c == null) return const SizedBox(height: 160);
      final delta = controller.trendDelta.value;
      final up = delta > 0;

      return GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.money),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: context.heroGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Left to spend this cycle',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyHelper.format(c.closingTotal),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _HeroBox(
                    icon: Icons.payments_rounded,
                    label: 'Cash',
                    value: c.closingCash,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _HeroBox(
                    icon: Icons.account_balance_rounded,
                    label: 'Online',
                    value: c.closingOnline,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _HeroBox(
                    icon: Icons.savings_rounded,
                    label: 'Savings',
                    value: controller.totalSavings.value,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: c.spentRatio,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation(
                    c.spentRatio > 0.9 ? const Color(0xFFFFD166) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${(c.spentRatio * 100).round()}% used  •  ${c.daysLeft()} days left',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (controller.hasTrend.value)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 16,
                          color: up ? const Color(0xFFFFD166) : Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${up ? '+' : '−'}${CurrencyHelper.formatShort(delta.abs())} vs last cycle',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _HeroBox extends StatelessWidget {
  const _HeroBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyHelper.formatShort(value),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = controller.summary.value;
      if (c == null) return const SizedBox.shrink();
      return Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.today_rounded,
              color: AppColors.accentPink,
              label: 'Spent today',
              value: CurrencyHelper.formatShort(controller.spentToday.value),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: Icons.show_chart_rounded,
              color: AppColors.info,
              label: 'Daily average',
              value: CurrencyHelper.formatRounded(c.dailyAverage()),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: Icons.speed_rounded,
              color: AppColors.success,
              label: 'Safe per day',
              value: CurrencyHelper.formatRounded(c.safePerDay()),
            ),
          ),
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weather ───────────────────────────────────────────────────

IconData _weatherIcon(WeatherSnapshot w) {
  switch (w.weatherCode) {
    case 0:
      return w.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    case 1:
    case 2:
      return w.isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
    case 3:
      return Icons.cloud_rounded;
    case 45:
    case 48:
      return Icons.foggy;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return Icons.grain_rounded;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return Icons.umbrella_rounded;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return Icons.ac_unit_rounded;
    case 95:
    case 96:
    case 99:
      return Icons.thunderstorm_rounded;
    default:
      return Icons.cloud_queue_rounded;
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final status = controller.weatherStatus.value;
      final w = controller.weather.value;

      if (status == WeatherStatus.off) {
        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.info.withValues(alpha: 0.14),
                child: const Icon(Icons.wb_cloudy_rounded, color: AppColors.info),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'See the weather here',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Allow location to show temperature, humidity and rain chance. '
                      'It also makes prayer times exact for where you are.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: () => _enable(context),
                child: const Text('Enable'),
              ),
            ],
          ),
        );
      }

      if (w == null) {
        return AppCard(
          child: SizedBox(
            height: 64,
            child: Center(
              child: status == WeatherStatus.loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text('Weather unavailable right now'),
                        TextButton(
                          onPressed: () => controller.loadWeather(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      }

      final warm = w.temperature >= 32;
      final colors = !w.isDay
          ? const [Color(0xFF1E1B4B), Color(0xFF312E81)]
          : (w.precipitationChance >= 60
                ? const [Color(0xFF475569), Color(0xFF64748B)]
                : (warm
                      ? const [Color(0xFFF97316), Color(0xFFFBBF24)]
                      : const [Color(0xFF0EA5E9), Color(0xFF38BDF8)]));

      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_weatherIcon(w), color: Colors.white, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${w.temperature.round()}°C',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        w.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          w.place.isEmpty ? 'Your location' : w.place,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'H ${w.tempMax.round()}°  L ${w.tempMin.round()}°',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _WeatherFact(
                  icon: Icons.thermostat_rounded,
                  label: 'Feels like',
                  value: '${w.feelsLike.round()}°',
                ),
                _WeatherFact(
                  icon: Icons.water_drop_rounded,
                  label: 'Humidity',
                  value: '${w.humidity}%',
                ),
                _WeatherFact(
                  icon: Icons.umbrella_rounded,
                  label: 'Rain chance',
                  value: '${w.precipitationChance}%',
                ),
                _WeatherFact(
                  icon: Icons.air_rounded,
                  label: 'Wind',
                  value: '${w.windKmh.round()} km/h',
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _enable(BuildContext context) async {
    final access = await controller.enableWeather();
    switch (access) {
      case LocationAccess.granted || LocationAccess.off:
        return;
      case LocationAccess.serviceDisabled:
        Get.snackbar('Location is off', 'Turn on location services and try again.');
      case LocationAccess.denied:
        Get.snackbar(
          'Permission needed',
          'Allow location access to see the weather.',
        );
      case LocationAccess.deniedForever:
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Location is blocked'),
            content: const Text(
              'Open app settings and allow Location for DayLee to see the weather.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  LocationService.openSettings();
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
    }
  }
}

class _WeatherFact extends StatelessWidget {
  const _WeatherFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prayer ────────────────────────────────────────────────────

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFmt = DateFormat.jm();

    return Obx(() {
      controller.nowMs.value; // rebuild every tick
      final next = controller.nextPrayer.value;
      final current = controller.currentPrayer.value;
      final left = controller.untilNextPrayer;
      final prayers = controller.todayPrayers;

      return AppCard(
        onTap: () => Get.toNamed(AppRoutes.prayer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.prayerAccent.withValues(alpha: 0.16),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: AppColors.prayerAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        next == null ? 'Prayer times' : 'Next: ${next.name}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (next != null)
                        Text(
                          '${timeFmt.format(next.time)}  •  in ${_countdown(left)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final p in prayers)
                  Expanded(
                    child: _PrayerDot(
                      name: p.name,
                      time: timeFmt.format(p.time).replaceAll(' ', ''),
                      isNext: next != null &&
                          next.key == p.key &&
                          next.time.day == p.time.day,
                      isCurrent: current?.key == p.key &&
                          current?.time.day == p.time.day,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }

  static String _countdown(Duration? d) {
    if (d == null) return '-';
    final minutes = d.inMinutes;
    if (minutes < 1) return 'under a minute';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }
}

class _PrayerDot extends StatelessWidget {
  const _PrayerDot({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isCurrent,
  });

  final String name;
  final String time;
  final bool isNext;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = isNext ? theme.colorScheme.primary : null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isNext
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: theme.textTheme.labelSmall?.copyWith(
                color: highlight ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: theme.textTheme.labelMedium?.copyWith(
                color: highlight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions & activity ──────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Quick actions'),
        Row(
          children: [
            action(
              Icons.remove_circle_outline_rounded,
              'Expense',
              AppColors.error,
              () => Get.toNamed(
                AppRoutes.addTransaction,
                arguments: {'type': 'expense'},
              ),
            ),
            action(
              Icons.add_circle_outline_rounded,
              'Income',
              AppColors.success,
              () => Get.toNamed(
                AppRoutes.addTransaction,
                arguments: {'type': 'income'},
              ),
            ),
            action(
              Icons.swap_horiz_rounded,
              'Move money',
              AppColors.info,
              () => Get.toNamed(AppRoutes.transfer),
            ),
            action(
              Icons.savings_rounded,
              'Savings',
              AppColors.accentPink,
              () => Get.toNamed(AppRoutes.savings),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final items = controller.recent;
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Recent activity',
              trailing: TextButton(
                onPressed: () => Get.toNamed(AppRoutes.money),
                child: const Text('See all'),
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    'Nothing yet. Add your first expense with the button above.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              for (final tx in items) _RecentTile(controller: controller, tx: tx),
          ],
        ),
      );
    });
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.controller, required this.tx});

  final DashboardController controller;
  final MoneyTransaction tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = tx.type == MoneyTransactionType.income;
    final date = DateTime.fromMillisecondsSinceEpoch(tx.dateMs);
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    final when = diff == 0
        ? 'Today'
        : (diff == 1 ? 'Yesterday' : DateFormat('d MMM').format(date));

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Get.toNamed(
        AppRoutes.addTransaction,
        arguments: {'transactionId': tx.id},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  CategoryService.color(tx.category).withValues(alpha: 0.14),
              child: Icon(
                CategoryService.icon(tx.category),
                size: 20,
                color: CategoryService.color(tx.category),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CategoryService.label(tx.category),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$when  •  ${controller.walletName(tx.sourceWalletId)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '−'}${CurrencyHelper.formatShort(tx.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isIncome ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

