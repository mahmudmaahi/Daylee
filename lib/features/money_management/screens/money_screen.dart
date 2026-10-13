import 'package:fl_chart/fl_chart.dart';
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
import '../../../data/repositories/money_repository.dart';
import '../../../data/services/category_service.dart';
import '../../../data/services/storage_service.dart';
import '../controllers/money_controller.dart';
import '../models/money_transaction.dart';
import '../models/money_transfer.dart';
import '../models/savings_entry.dart';
import '../models/wallet.dart';
import 'finance_sheets.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({
    super.key,
    this.initialPageIndex = 0,
    this.currentNavIndex = 2,
  });

  final int initialPageIndex;
  final int currentNavIndex;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  MoneyController get controller => Get.find<MoneyController>();

  @override
  void initState() {
    super.initState();
    // Open on the tab the route asked for, but only once: later rebuilds
    // (theme change, ...) must not snap the user back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.setPageIndex(widget.initialPageIndex);
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: const AppGlobalHeader(showBottomDivider: true),
      bottomNavigationBar: AppBottomNav(currentIndex: widget.currentNavIndex),
      floatingActionButton: Obx(() {
        final page = controller.selectedPageIndex.value;
        return FloatingActionButton.extended(
          onPressed: () => _onFab(context, page),
          icon: Icon(_fabIcon(page)),
          label: Text(_fabLabel(page)),
        );
      }),
      body: Obx(() {
        if (!controller.isReady.value || controller.summary.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            _CycleBar(controller: controller),
            _PageTabs(controller: controller),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: IndexedStack(
                index: controller.selectedPageIndex.value,
                children: [
                  _OverviewPage(controller: controller),
                  _WalletsPage(controller: controller),
                  _TransfersPage(controller: controller),
                  _SavingsPage(controller: controller),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  void _onFab(BuildContext context, int page) {
    switch (page) {
      case 1:
        showWalletSheet(context);
      case 2:
        showTransferSheet(context);
      case 3:
        showSavingsSheet(context);
      default:
        Get.toNamed(AppRoutes.addTransaction, arguments: {'type': 'expense'});
    }
  }

  IconData _fabIcon(int page) => switch (page) {
    1 => Icons.add_card_rounded,
    2 => Icons.swap_horiz_rounded,
    3 => Icons.savings_rounded,
    _ => Icons.add_rounded,
  };

  String _fabLabel(int page) => switch (page) {
    1 => 'Wallet',
    2 => 'Move money',
    3 => 'Savings',
    _ => 'Add',
  };
}

// ── Header ────────────────────────────────────────────────────

class _CycleBar extends StatelessWidget {
  const _CycleBar({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous cycle',
            onPressed: controller.goToPreviousCycle,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: controller.isCurrentCycle
                  ? null
                  : controller.goToCurrentCycle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          controller.cycleTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (controller.isCurrentCycle) ...[
                          const SizedBox(width: 8),
                          _Pill(
                            text: 'Now',
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      controller.isCurrentCycle
                          ? controller.cycleLabel
                          : '${controller.cycleLabel}  •  tap to jump to now',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next cycle',
            onPressed: controller.goToNextCycle,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _PageTabs extends StatelessWidget {
  const _PageTabs({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['Overview', 'Wallets', 'Transfers', 'Savings'];
    final selected = controller.selectedPageIndex.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          children: List.generate(labels.length, (i) {
            final active = i == selected;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => controller.setPageIndex(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? theme.colorScheme.primary : null,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active ? theme.colorScheme.onPrimary : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

EdgeInsets _pagePadding() => const EdgeInsets.fromLTRB(
  AppSpacing.lg,
  AppSpacing.xs,
  AppSpacing.lg,
  96,
);

// ── Overview ──────────────────────────────────────────────────

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.cycle;
    return RefreshIndicator(
      onRefresh: () async => controller.refreshAll(),
      child: ListView(
        padding: _pagePadding(),
        children: [
          _HeroCard(controller: controller),
          const SizedBox(height: AppSpacing.md),
          _AllowanceCard(controller: controller),
          if (controller.isCurrentCycle) _RolloverCard(controller: controller),
          const SizedBox(height: AppSpacing.md),
          _StatementCard(summary: c),
          const SizedBox(height: AppSpacing.md),
          _DailyChartCard(controller: controller),
          const SizedBox(height: AppSpacing.md),
          _CategoryCard(summary: c),
          const SizedBox(height: AppSpacing.md),
          _ActivityCard(controller: controller),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.cycle;
    final theme = Theme.of(context);
    final isNow = controller.isCurrentCycle && c.containsNow();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: context.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.isCurrentCycle ? 'Left to spend' : 'Left at end of cycle',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
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
              Expanded(
                child: _HeroChip(
                  icon: Icons.payments_rounded,
                  label: 'Cash',
                  value: c.closingCash,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeroChip(
                  icon: Icons.account_balance_rounded,
                  label: 'Online',
                  value: c.closingOnline,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: c.spentRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(
                c.spentRatio > 0.9 ? const Color(0xFFFFD166) : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Spent ${CurrencyHelper.formatShort(c.spentTotal)} of '
            '${CurrencyHelper.formatShort(c.budget)}'
            '${isNow ? '  •  ${CurrencyHelper.formatRounded(c.safePerDay())}/day for ${c.daysLeft()} days' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
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
        ],
      ),
    );
  }
}

class _AllowanceCard extends StatelessWidget {
  const _AllowanceCard({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final fund = controller.repo.getCycleFund(controller.currentMonthId);
    final has = fund.cash > 0 || fund.online > 0;
    final theme = Theme.of(context);

    return AppCard(
      onTap: () => showCycleFundSheet(context),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.success.withValues(alpha: 0.14),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  has ? 'Allowance this cycle' : 'Set this cycle\'s allowance',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  has
                      ? 'Cash ${CurrencyHelper.formatShort(fund.cash)}  •  Online ${CurrencyHelper.formatShort(fund.online)}'
                      : 'Record what you received in cash and online.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            has ? Icons.edit_outlined : Icons.add_circle_outline_rounded,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// At the start of a cycle: leftover cash is carried over automatically; this
/// card helps record the matching online money that went to savings.
class _RolloverCard extends StatelessWidget {
  const _RolloverCard({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.cycle;
    final key = 'rollover_done_${c.monthId}';
    if (c.openingCash < 1 || StorageService.getBool(key)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.autorenew_rounded, color: AppColors.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${CurrencyHelper.formatShort(c.openingCash)} cash carried over',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your leftover cash from the last cycle is already part of this '
              'cycle\'s cash. If your father sent the same amount online, '
              'record it as online savings so nothing is counted twice.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () async {
                      final online = controller.onlineWallets.firstOrNull;
                      await showSavingsSheet(
                        context,
                        action: SavingsAction.newMoney,
                        amount: c.openingCash,
                        walletId: online?.id,
                        note: 'Matches cash carried over',
                      );
                    },
                    child: const Text('Add to online savings'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () async {
                    await StorageService.setBool(key, true);
                    controller.refreshAll();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact statement: how the cycle's money moved, split by cash / online.
class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final theme = Theme.of(context);

    Widget row(
      String label,
      double cash,
      double online, {
      bool signed = false,
      bool strong = false,
      Color? color,
    }) {
      String fmt(double v) {
        if (v.abs() < 0.005) return '–';
        final text = CurrencyHelper.formatShort(v.abs());
        if (!signed) return text;
        return v > 0 ? '+$text' : '−$text';
      }

      final style = theme.textTheme.bodyMedium?.copyWith(
        fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
        color: color,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: strong ? FontWeight.w800 : null,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(fmt(cash), textAlign: TextAlign.right, style: style),
            ),
            Expanded(
              flex: 3,
              child: Text(fmt(online), textAlign: TextAlign.right, style: style),
            ),
          ],
        ),
      );
    }

    Widget header() => Row(
      children: [
        const Expanded(flex: 4, child: SizedBox()),
        for (final t in const ['Cash', 'Online'])
          Expanded(
            flex: 3,
            child: Text(
              t,
              textAlign: TextAlign.right,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    final hasExchange = s.transfersCash.abs() + s.transfersOnline.abs() > 0.005;
    final hasSavings = s.savingsCash.abs() + s.savingsOnline.abs() > 0.005;
    final hasAdj = s.adjustmentsCash.abs() + s.adjustmentsOnline.abs() > 0.005;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Cycle statement'),
          header(),
          row('Brought forward', s.openingCash, s.openingOnline),
          row(
            'Received',
            s.receivedCash,
            s.receivedOnline,
            signed: true,
            color: AppColors.success,
          ),
          row(
            'Spent',
            -s.spentCash,
            -s.spentOnline,
            signed: true,
            color: AppColors.error,
          ),
          if (hasExchange)
            row('Moved between wallets', s.transfersCash, s.transfersOnline,
                signed: true),
          if (hasSavings)
            row('To / from savings', s.savingsCash, s.savingsOnline, signed: true),
          if (hasAdj)
            row('Corrections', s.adjustmentsCash, s.adjustmentsOnline,
                signed: true),
          const Divider(height: AppSpacing.lg),
          row('Left', s.closingCash, s.closingOnline, strong: true),
        ],
      ),
    );
  }
}

class _DailyChartCard extends StatelessWidget {
  const _DailyChartCard({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller.cycle;
    final theme = Theme.of(context);
    final maxY = c.dailyExpenses.fold<double>(0, (m, v) => v > m ? v : m);
    final today = DateTime.now();
    final todayIndex = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(c.start).inDays;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Daily spending',
            trailing: Text(
              'avg ${CurrencyHelper.formatRounded(c.dailyAverage())}/day',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (maxY <= 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'No spending recorded in this cycle yet.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  maxY: maxY * 1.15,
                  alignment: BarChartAlignment.spaceBetween,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i % 5 != 0) return const SizedBox.shrink();
                          final day = c.start.add(Duration(days: i));
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${day.day}',
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, _) {
                        final day = c.start.add(Duration(days: group.x));
                        return BarTooltipItem(
                          '${DateFormat('d MMM').format(day)}\n'
                          '${CurrencyHelper.formatShort(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(c.dailyExpenses.length, (i) {
                    final isToday = i == todayIndex;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: c.dailyExpenses[i],
                          width: 5,
                          borderRadius: BorderRadius.circular(3),
                          color: isToday
                              ? AppColors.accentPink
                              : theme.colorScheme.primary.withValues(
                                  alpha: c.dailyExpenses[i] > 0 ? 0.9 : 0.15,
                                ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.summary});

  final CycleSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = summary.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = summary.spentTotal;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Where it went'),
          if (items.isEmpty)
            Text('Nothing spent yet.', style: theme.textTheme.bodySmall)
          else ...[
            SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 46,
                  sectionsSpace: 2,
                  sections: items
                      .map(
                        (e) => PieChartSectionData(
                          value: e.value,
                          color: CategoryService.color(e.key),
                          title: '',
                          radius: 38,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      CategoryService.icon(e.key),
                      size: 18,
                      color: CategoryService.color(e.key),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(CategoryService.label(e.key)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total <= 0 ? 0 : e.value / total,
                              minHeight: 5,
                              color: CategoryService.color(e.key),
                              backgroundColor: theme
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyHelper.formatShort(e.value),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${total <= 0 ? 0 : (e.value / total * 100).round()}%',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = controller.filteredTransactions;
    final categories = controller.cycleCategories;

    final groups = <DateTime, List<MoneyTransaction>>{};
    for (final tx in items) {
      final d = DateTime.fromMillisecondsSinceEpoch(tx.dateMs);
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(tx);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget filterChip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Activity'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                filterChip(
                  'All',
                  controller.activityFilter.value == ActivityFilter.all,
                  () => controller.activityFilter.value = ActivityFilter.all,
                ),
                filterChip(
                  'Expenses',
                  controller.activityFilter.value == ActivityFilter.expense,
                  () => controller.activityFilter.value =
                      ActivityFilter.expense,
                ),
                filterChip(
                  'Income',
                  controller.activityFilter.value == ActivityFilter.income,
                  () => controller.activityFilter.value = ActivityFilter.income,
                ),
              ],
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  filterChip(
                    'Any category',
                    controller.categoryFilter.value == 'all',
                    () => controller.categoryFilter.value = 'all',
                  ),
                  for (final c in categories)
                    filterChip(
                      CategoryService.label(c),
                      controller.categoryFilter.value == c,
                      () => controller.categoryFilter.value = c,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'No transactions yet. Tap Add to record one.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            )
          else
            for (final day in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(day),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      _dayTotal(groups[day]!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              for (final tx in groups[day]!)
                _TransactionTile(controller: controller, tx: tx),
            ],
        ],
      ),
    );
  }

  static String _dayLabel(DateTime day) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final diff = t.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  static String _dayTotal(List<MoneyTransaction> list) {
    var spent = 0.0;
    for (final tx in list) {
      if (tx.type == MoneyTransactionType.expense &&
          tx.category != MoneyRepository.adjustmentCategory) {
        spent += tx.amount;
      }
    }
    return spent <= 0 ? '' : '−${CurrencyHelper.formatShort(spent)}';
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.controller, required this.tx});

  final MoneyController controller;
  final MoneyTransaction tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = controller.walletById(tx.sourceWalletId);
    final isIncome = tx.type == MoneyTransactionType.income;
    final isAdjust = tx.category == MoneyRepository.adjustmentCategory;
    final color = isAdjust
        ? theme.colorScheme.onSurfaceVariant
        : (isIncome ? AppColors.success : AppColors.error);
    final note = tx.note.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Get.toNamed(
        AppRoutes.addTransaction,
        arguments: {'transactionId': tx.id},
      ),
      onLongPress: () => _confirmDelete(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: CategoryService.color(
                tx.category,
              ).withValues(alpha: 0.14),
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
                    [
                      wallet?.name ?? 'Unknown wallet',
                      if (note.isNotEmpty) note,
                    ].join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (v) {
                if (v == 'edit') {
                  Get.toNamed(
                    AppRoutes.addTransaction,
                    arguments: {'transactionId': tx.id},
                  );
                } else {
                  _confirmDelete(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete transaction?',
      message:
          '${CategoryService.label(tx.category)} • ${CurrencyHelper.format(tx.amount)} will be removed and your balance updated.',
      confirmLabel: 'Delete',
    );
    if (ok) await controller.deleteTransaction(tx.id);
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

// ── Wallets ───────────────────────────────────────────────────

class _WalletsPage extends StatelessWidget {
  const _WalletsPage({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget section(String title, List<Wallet> wallets) {
      if (wallets.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: SectionTitle(title),
          ),
          for (final w in wallets) _WalletCard(controller: controller, wallet: w),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async => controller.refreshAll(),
      child: ListView(
        padding: _pagePadding(),
        children: [
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Total money',
                    value: controller.totalBalance,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Free to spend',
                    value: controller.totalSpendable,
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'In savings',
                    value: controller.totalSavings,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          section('Cash', controller.cashWallets),
          section('Bank accounts', controller.bankWallets),
          section('Mobile wallets', controller.mobileWallets),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyHelper.formatShort(value),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.controller, required this.wallet});

  final MoneyController controller;
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (wallet.type) {
      WalletType.cash => Icons.payments_rounded,
      WalletType.bank => Icons.account_balance_rounded,
      WalletType.mobile => Icons.phone_android_rounded,
    };
    final canDelete = controller.canDeleteWallet(wallet.id);
    final detail = wallet.type == WalletType.bank
        ? wallet.bankName
        : (wallet.type == WalletType.mobile ? wallet.phoneNumber : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => showWalletSheet(context, wallet: wallet),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(detail, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Text(
                  CurrencyHelper.format(wallet.currentBalance),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Pill(
                  text: 'Free ${CurrencyHelper.formatShort(wallet.spendable)}',
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                if (wallet.savingsBalance > 0)
                  _Pill(
                    text:
                        'Saved ${CurrencyHelper.formatShort(wallet.savingsBalance)}',
                    color: theme.colorScheme.primary,
                  ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete wallet',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Delete ${wallet.name}?',
                        message: 'This wallet is empty and has no history.',
                        confirmLabel: 'Delete',
                      );
                      if (ok) await controller.deleteWallet(wallet.id);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transfers ─────────────────────────────────────────────────

class _TransfersPage extends StatelessWidget {
  const _TransfersPage({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transfers = controller.cycleTransfers;

    return RefreshIndicator(
      onRefresh: () async => controller.refreshAll(),
      child: ListView(
        padding: _pagePadding(),
        children: [
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: AppColors.info),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Moving money between your own wallets does not count as '
                    'spending. Use it when you swap online money for cash with '
                    'a friend, or when you withdraw from the bank.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('This cycle'),
                if (transfers.isEmpty)
                  Text('No transfers yet.', style: theme.textTheme.bodySmall)
                else
                  for (final t in transfers)
                    _TransferTile(controller: controller, transfer: t),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.controller, required this.transfer});

  final MoneyController controller;
  final MoneyTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = controller.walletById(transfer.fromWalletId)?.name ?? '?';
    final to = controller.walletById(transfer.toWalletId)?.name ?? '?';
    final date = DateFormat(
      'd MMM',
    ).format(DateTime.fromMillisecondsSinceEpoch(transfer.dateMs));
    final isSavings = transfer.type == TransferMoneyType.savings;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => showTransferSheet(context, transfer: transfer),
      leading: CircleAvatar(
        backgroundColor: AppColors.info.withValues(alpha: 0.14),
        child: Icon(
          isSavings ? Icons.savings_rounded : Icons.compare_arrows_rounded,
          color: AppColors.info,
        ),
      ),
      title: Text('$from → $to'),
      subtitle: Text(
        [
          date,
          isSavings ? 'Savings' : 'Spending money',
          if (transfer.note.isNotEmpty) transfer.note,
        ].join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyHelper.formatShort(transfer.amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete transfer?',
                message:
                    '${CurrencyHelper.format(transfer.amount)} from $from to $to will be reversed.',
                confirmLabel: 'Delete',
              );
              if (ok) await controller.deleteTransfer(transfer.id);
            },
          ),
        ],
      ),
    );
  }
}

// ── Savings ───────────────────────────────────────────────────

class _SavingsPage extends StatelessWidget {
  const _SavingsPage({required this.controller});

  final MoneyController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = controller.savingsEntries.take(40).toList();
    final wallets = controller.wallets
        .where((w) => w.savingsBalance > 0)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async => controller.refreshAll(),
      child: ListView(
        padding: _pagePadding(),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5A4), Color(0xFF22C55E)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total savings',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyHelper.format(controller.totalSavings),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Out of ${CurrencyHelper.formatShort(controller.totalBalance)} total money',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final (action, label, icon) in const [
                (SavingsAction.setAside, 'Set aside', Icons.south_rounded),
                (SavingsAction.newMoney, 'New money', Icons.add_rounded),
                (SavingsAction.release, 'Release', Icons.north_rounded),
              ])
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => showSavingsSheet(context, action: action),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Icon(icon, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Where it is kept'),
                if (wallets.isEmpty)
                  Text('Nothing saved yet.', style: theme.textTheme.bodySmall)
                else
                  for (final w in wallets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(w.name)),
                          Text(
                            CurrencyHelper.format(w.savingsBalance),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('History'),
                if (entries.isEmpty)
                  Text('No savings activity yet.', style: theme.textTheme.bodySmall)
                else
                  for (final e in entries)
                    _SavingsTile(controller: controller, entry: e),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsTile extends StatelessWidget {
  const _SavingsTile({required this.controller, required this.entry});

  final MoneyController controller;
  final SavingsEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDeposit = entry.type == SavingsEntryType.deposit;
    final color = isDeposit ? AppColors.success : AppColors.warning;
    final wallet = controller.walletById(entry.walletId)?.name ?? 'Unknown';
    final date = DateFormat(
      'd MMM',
    ).format(DateTime.fromMillisecondsSinceEpoch(entry.dateMs));
    final title = isDeposit
        ? (entry.newMoney ? 'New money saved' : 'Set aside')
        : (entry.refId != null ? 'Used for an expense' : 'Released');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(
          isDeposit ? Icons.south_rounded : Icons.north_rounded,
          color: color,
        ),
      ),
      title: Text(title),
      subtitle: Text(
        [date, wallet, if (entry.note.isNotEmpty) entry.note].join('  •  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isDeposit ? '+' : '−'}${CurrencyHelper.formatShort(entry.amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (entry.refId == null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete savings entry?',
                  message: 'This reverses its effect on your savings.',
                  confirmLabel: 'Delete',
                );
                if (ok) await controller.deleteSavingsEntry(entry.id);
              },
            ),
        ],
      ),
    );
  }
}
