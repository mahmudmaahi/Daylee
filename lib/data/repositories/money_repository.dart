import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/currency_helper.dart';
import '../../features/money_management/models/money_transaction.dart';
import '../../features/money_management/models/money_transfer.dart';
import '../../features/money_management/models/savings_entry.dart';
import '../../features/money_management/models/wallet.dart';
import '../services/hive_service.dart';
import '../services/storage_service.dart';

class FinanceException implements Exception {
  FinanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything the UI needs to know about one budget cycle.
///
/// "Spendable" means money that is free to spend: wallet balance minus the
/// part tagged as savings. The identity
/// `closing = opening + received - spent + transfers + savings + adjustments`
/// always holds, per wallet group (cash / online).
class CycleSummary {
  const CycleSummary({
    required this.monthId,
    required this.start,
    required this.endExclusive,
    required this.openingCash,
    required this.openingOnline,
    required this.receivedCash,
    required this.receivedOnline,
    required this.spentCash,
    required this.spentOnline,
    required this.transfersCash,
    required this.transfersOnline,
    required this.savingsCash,
    required this.savingsOnline,
    required this.adjustmentsCash,
    required this.adjustmentsOnline,
    required this.closingCash,
    required this.closingOnline,
    required this.categoryExpenses,
    required this.dailyExpenses,
  });

  final String monthId;
  final DateTime start;
  final DateTime endExclusive;

  final double openingCash;
  final double openingOnline;
  final double receivedCash;
  final double receivedOnline;
  final double spentCash;
  final double spentOnline;

  /// Net effect of wallet-to-wallet exchanges (e.g. online -> cash from a
  /// friend) on the spendable money of each group.
  final double transfersCash;
  final double transfersOnline;

  /// Net effect of moving money into (-) or out of (+) savings.
  final double savingsCash;
  final double savingsOnline;

  /// Manual balance corrections and opening balances.
  final double adjustmentsCash;
  final double adjustmentsOnline;

  final double closingCash;
  final double closingOnline;

  final Map<String, double> categoryExpenses;

  /// Expense total for each day of the cycle, indexed from [start].
  final List<double> dailyExpenses;

  double get openingTotal => openingCash + openingOnline;
  double get receivedTotal => receivedCash + receivedOnline;
  double get spentTotal => spentCash + spentOnline;
  double get closingTotal => closingCash + closingOnline;
  double get adjustmentsTotal => adjustmentsCash + adjustmentsOnline;
  double get savingsTotal => savingsCash + savingsOnline;

  /// Everything that was available to spend during this cycle.
  double get budget {
    final value = openingTotal + receivedTotal + adjustmentsTotal;
    return value < 0 ? 0 : value;
  }

  double get spentRatio =>
      budget <= 0 ? 0 : (spentTotal / budget).clamp(0.0, 1.0).toDouble();

  int get totalDays => endExclusive.difference(start).inDays;

  bool containsNow([DateTime? now]) {
    final value = now ?? DateTime.now();
    return !value.isBefore(start) && value.isBefore(endExclusive);
  }

  /// Days that already passed in this cycle, including today (1..totalDays).
  int daysElapsed([DateTime? now]) {
    final value = now ?? DateTime.now();
    if (value.isBefore(start)) return 0;
    if (!value.isBefore(endExclusive)) return totalDays;
    final today = DateTime(value.year, value.month, value.day);
    return today.difference(start).inDays + 1;
  }

  /// Days left in the cycle, counting today.
  int daysLeft([DateTime? now]) {
    final left = totalDays - daysElapsed(now) + 1;
    return left < 1 ? 1 : left;
  }

  double dailyAverage([DateTime? now]) {
    final elapsed = daysElapsed(now);
    return elapsed <= 0 ? 0 : spentTotal / elapsed;
  }

  /// How much can be spent per day to make the remaining money last.
  double safePerDay([DateTime? now]) {
    if (closingTotal <= 0) return 0;
    return closingTotal / daysLeft(now);
  }

  double spentOn(DateTime day) {
    final index = DateTime(
      day.year,
      day.month,
      day.day,
    ).difference(start).inDays;
    if (index < 0 || index >= dailyExpenses.length) return 0;
    return dailyExpenses[index];
  }

  String get topCategory {
    String? top;
    var amount = 0.0;
    categoryExpenses.forEach((key, value) {
      if (value > amount) {
        amount = value;
        top = key;
      }
    });
    return top ?? '';
  }
}

class _Snapshot {
  _Snapshot(this.balance, this.savings);

  final Map<String, double> balance;
  final Map<String, double> savings;

  double balanceOf(String id) => balance[id] ?? 0;
  double savingsOf(String id) => savings[id] ?? 0;
}

class _Data {
  _Data({
    required this.wallets,
    required this.txs,
    required this.transfers,
    required this.savings,
  });

  final Map<String, Wallet> wallets;
  final Map<String, MoneyTransaction> txs;
  final Map<String, MoneyTransfer> transfers;
  final Map<String, SavingsEntry> savings;

  _Data copy() => _Data(
    wallets: Map.of(wallets),
    txs: Map.of(txs),
    transfers: Map.of(transfers),
    savings: Map.of(savings),
  );
}

/// Ledger based finance storage.
///
/// Wallet balances and savings are never stored as mutable numbers. They are
/// always derived from the list of transactions, transfers and savings entries,
/// so edits and deletes can never make the books drift. Every mutation is
/// validated on a candidate copy of the ledger and only written to disk when
/// no wallet ends up negative or with more savings than money.
class MoneyRepository {
  static const String cashWalletId = 'wallet_cash';
  static const String cashWalletName = 'Cash';
  static const String cycleStartDayKey = 'money_cycle_start_day';
  static const String _ledgerMigrationKey = 'money_ledger_v2_done';

  static const String adjustmentCategory = 'adjustment';
  static const String allowanceCategory = 'allowance';
  static const double _eps = 0.005;

  final _uuid = const Uuid();

  /// Bumped after every write so controllers on other screens can refresh.
  final revision = 0.obs;

  _Data? _cache;

  Box get _walletBox => HiveService.box(HiveService.moneyWalletBox);
  Box get _txBox => HiveService.box(HiveService.moneyTransactionBox);
  Box get _transferBox => HiveService.box(HiveService.moneyTransferBox);
  Box get _savingsBox => HiveService.box(HiveService.moneySavingsBox);
  Box get _legacyFundBox => HiveService.box(HiveService.moneyMonthlyFundBox);
  Box get _legacySourceBox => HiveService.box(HiveService.moneySourceBox);
  Box get _legacyMetaBox => HiveService.box(HiveService.moneyMetaBox);

  // ── Setup ───────────────────────────────────────────────────

  Future<void> init() async {
    await ensureDefaultWallets();
    await _migrateLegacyIfNeeded();
  }

  Future<void> ensureDefaultWallets() async {
    if (_walletBox.get(cashWalletId) is Map) return;
    final cash = Wallet(
      id: cashWalletId,
      name: cashWalletName,
      type: WalletType.cash,
      currentBalance: 0,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _walletBox.put(cash.id, cash.toMap());
    _invalidate();
  }

  Future<void> clearAllMoneyData() async {
    await _walletBox.clear();
    await _txBox.clear();
    await _transferBox.clear();
    await _savingsBox.clear();
    await _legacyFundBox.clear();
    await _legacySourceBox.clear();
    await _legacyMetaBox.clear();
    _invalidate();
  }

  // ── Cycle calendar ──────────────────────────────────────────

  int get cycleStartDay {
    final stored = StorageService.getInt(cycleStartDayKey, fallback: 25);
    return stored.clamp(1, 28).toInt();
  }

  Future<void> setCycleStartDay(int day) async {
    await StorageService.setInt(cycleStartDayKey, day.clamp(1, 28).toInt());
    _bump();
  }

  /// A cycle is named after the month it ends in: with a start day of 25,
  /// "2026-11" is 25 Oct - 24 Nov.
  String monthIdFromDate(DateTime date) {
    final cycleMonth = date.day >= cycleStartDay
        ? DateTime(date.year, date.month + 1, 1)
        : DateTime(date.year, date.month, 1);
    final m = cycleMonth.month.toString().padLeft(2, '0');
    return '${cycleMonth.year}-$m';
  }

  String get currentMonthId => monthIdFromDate(DateTime.now());

  String previousMonthId(String monthId) =>
      monthIdFromDate(monthStartFromId(monthId).subtract(const Duration(days: 1)));

  String nextMonthId(String monthId) =>
      monthIdFromDate(monthEndExclusiveFromId(monthId));

  DateTime monthStartFromId(String monthId) {
    final (year, month) = _parseMonthId(monthId);
    return DateTime(year, month - 1, cycleStartDay);
  }

  DateTime monthEndExclusiveFromId(String monthId) {
    final (year, month) = _parseMonthId(monthId);
    return DateTime(year, month, cycleStartDay);
  }

  (int, int) _parseMonthId(String monthId) {
    final parts = monthId.split('-');
    final now = DateTime.now();
    if (parts.length != 2) return (now.year, now.month);
    return (int.tryParse(parts[0]) ?? now.year, int.tryParse(parts[1]) ?? now.month);
  }

  String cycleLabelFromId(String monthId) {
    final start = monthStartFromId(monthId);
    final end = monthEndExclusiveFromId(
      monthId,
    ).subtract(const Duration(days: 1));
    final sameYear = start.year == end.year;
    final from = DateFormat(sameYear ? 'd MMM' : 'd MMM yyyy').format(start);
    return '$from - ${DateFormat('d MMM yyyy').format(end)}';
  }

  /// "November 2026" for the cycle that ends in November.
  String cycleTitleFromId(String monthId) {
    final end = monthEndExclusiveFromId(
      monthId,
    ).subtract(const Duration(days: 1));
    return DateFormat('MMMM yyyy').format(end);
  }

  // ── Reads ───────────────────────────────────────────────────

  _Data get _data => _cache ??= _load();

  _Data _load() {
    final wallets = <String, Wallet>{};
    for (final raw in _walletBox.values.whereType<Map>()) {
      final wallet = Wallet.fromMap(Map<String, dynamic>.from(raw));
      if (wallet.id.isNotEmpty) wallets[wallet.id] = wallet;
    }
    final txs = <String, MoneyTransaction>{};
    for (final raw in _txBox.values.whereType<Map>()) {
      final tx = MoneyTransaction.fromMap(Map<String, dynamic>.from(raw));
      if (tx.id.isNotEmpty) txs[tx.id] = tx;
    }
    final transfers = <String, MoneyTransfer>{};
    for (final raw in _transferBox.values.whereType<Map>()) {
      final t = MoneyTransfer.fromMap(Map<String, dynamic>.from(raw));
      if (t.id.isNotEmpty) transfers[t.id] = t;
    }
    final savings = <String, SavingsEntry>{};
    for (final raw in _savingsBox.values.whereType<Map>()) {
      final e = SavingsEntry.fromMap(Map<String, dynamic>.from(raw));
      if (e.id.isNotEmpty) savings[e.id] = e;
    }
    return _Data(
      wallets: wallets,
      txs: txs,
      transfers: transfers,
      savings: savings,
    );
  }

  void _invalidate() => _cache = null;

  void _bump() {
    _invalidate();
    revision.value++;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  _Snapshot _compute(_Data d, {int? beforeMs}) {
    final balance = <String, double>{};
    final savings = <String, double>{};
    bool counts(int ms) => beforeMs == null || ms < beforeMs;

    for (final tx in d.txs.values) {
      if (!counts(tx.dateMs)) continue;
      final signed = tx.type == MoneyTransactionType.expense
          ? -tx.amount
          : tx.amount;
      balance[tx.sourceWalletId] = (balance[tx.sourceWalletId] ?? 0) + signed;
    }
    for (final t in d.transfers.values) {
      if (!counts(t.dateMs)) continue;
      balance[t.fromWalletId] = (balance[t.fromWalletId] ?? 0) - t.amount;
      balance[t.toWalletId] = (balance[t.toWalletId] ?? 0) + t.amount;
      if (t.type == TransferMoneyType.savings) {
        savings[t.fromWalletId] = (savings[t.fromWalletId] ?? 0) - t.amount;
        savings[t.toWalletId] = (savings[t.toWalletId] ?? 0) + t.amount;
      }
    }
    for (final e in d.savings.values) {
      if (!counts(e.dateMs)) continue;
      savings[e.walletId] = (savings[e.walletId] ?? 0) + e.signedAmount;
      if (e.type == SavingsEntryType.deposit && e.newMoney) {
        balance[e.walletId] = (balance[e.walletId] ?? 0) + e.amount;
      }
    }
    return _Snapshot(
      balance.map((k, v) => MapEntry(k, _round(v))),
      savings.map((k, v) => MapEntry(k, _round(v))),
    );
  }

  List<Wallet> getWallets() {
    final d = _data;
    final snap = _compute(d);
    final list = d.wallets.values
        .map(
          (w) => w.copyWith(
            currentBalance: snap.balanceOf(w.id),
            savingsBalance: snap.savingsOf(w.id),
          ),
        )
        .toList();

    list.sort((a, b) {
      final aIsCash = a.type == WalletType.cash;
      final bIsCash = b.type == WalletType.cash;
      if (aIsCash && !bIsCash) return -1;
      if (!aIsCash && bIsCash) return 1;
      final byCreated = a.createdAtMs.compareTo(b.createdAtMs);
      if (byCreated != 0) return byCreated;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Wallet? getWalletById(String walletId) {
    for (final w in getWallets()) {
      if (w.id == walletId) return w;
    }
    return null;
  }

  List<MoneyTransaction> getTransactions() {
    final list = _data.txs.values.toList()
      ..sort((a, b) {
        final byDate = b.dateMs.compareTo(a.dateMs);
        return byDate != 0 ? byDate : b.createdAtMs.compareTo(a.createdAtMs);
      });
    return list;
  }

  MoneyTransaction? getTransactionById(String id) => _data.txs[id];

  List<MoneyTransfer> getTransfers() {
    final list = _data.transfers.values.toList()
      ..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    return list;
  }

  MoneyTransfer? getTransferById(String id) => _data.transfers[id];

  List<SavingsEntry> getSavingsEntries() {
    final list = _data.savings.values.toList()
      ..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    return list;
  }

  double get totalBalance =>
      getWallets().fold(0.0, (sum, w) => sum + w.currentBalance);

  double get totalSavings =>
      getWallets().fold(0.0, (sum, w) => sum + w.savingsBalance);

  double get totalSpendable =>
      getWallets().fold(0.0, (sum, w) => sum + w.spendable);

  double get cashSpendable => getWallets()
      .where((w) => !w.isOnline)
      .fold(0.0, (sum, w) => sum + w.spendable);

  double get onlineSpendable => getWallets()
      .where((w) => w.isOnline)
      .fold(0.0, (sum, w) => sum + w.spendable);

  double getWalletSavingsAmount(String walletId) =>
      _compute(_data).savingsOf(walletId);

  /// Expense transactions that fall inside a cycle, oldest first.
  List<MoneyTransaction> getCycleExpenseTransactions(String monthId) {
    final start = monthStartFromId(monthId).millisecondsSinceEpoch;
    final end = monthEndExclusiveFromId(monthId).millisecondsSinceEpoch;
    return _data.txs.values
        .where(
          (tx) =>
              tx.type == MoneyTransactionType.expense &&
              tx.category != adjustmentCategory &&
              tx.dateMs >= start &&
              tx.dateMs < end,
        )
        .toList()
      ..sort((a, b) => a.dateMs.compareTo(b.dateMs));
  }

  CycleSummary computeCycleSummary(String monthId) {
    final d = _data;
    final start = monthStartFromId(monthId);
    final end = monthEndExclusiveFromId(monthId);
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final opening = _compute(d, beforeMs: startMs);
    final closing = _compute(d, beforeMs: endMs);

    bool isOnline(String walletId) => d.wallets[walletId]?.isOnline ?? false;

    double spendable(_Snapshot s, {required bool online}) {
      var sum = 0.0;
      for (final w in d.wallets.values) {
        if (w.isOnline != online) continue;
        sum += s.balanceOf(w.id) - s.savingsOf(w.id);
      }
      return sum;
    }

    var receivedCash = 0.0, receivedOnline = 0.0;
    var spentCash = 0.0, spentOnline = 0.0;
    var adjCash = 0.0, adjOnline = 0.0;
    var trCash = 0.0, trOnline = 0.0;
    var savCash = 0.0, savOnline = 0.0;
    final categories = <String, double>{};
    final days = List<double>.filled(
      end.difference(start).inDays.clamp(1, 62).toInt(),
      0,
    );

    for (final tx in d.txs.values) {
      if (tx.dateMs < startMs || tx.dateMs >= endMs) continue;
      final online = isOnline(tx.sourceWalletId);
      final signed = tx.type == MoneyTransactionType.expense
          ? -tx.amount
          : tx.amount;

      if (tx.category == adjustmentCategory) {
        if (online) {
          adjOnline += signed;
        } else {
          adjCash += signed;
        }
        continue;
      }

      if (tx.type == MoneyTransactionType.income) {
        if (online) {
          receivedOnline += tx.amount;
        } else {
          receivedCash += tx.amount;
        }
        continue;
      }

      if (online) {
        spentOnline += tx.amount;
      } else {
        spentCash += tx.amount;
      }
      categories[tx.category] = (categories[tx.category] ?? 0) + tx.amount;
      final date = DateTime.fromMillisecondsSinceEpoch(tx.dateMs);
      final index = DateTime(
        date.year,
        date.month,
        date.day,
      ).difference(start).inDays;
      if (index >= 0 && index < days.length) days[index] += tx.amount;
    }

    for (final t in d.transfers.values) {
      if (t.dateMs < startMs || t.dateMs >= endMs) continue;
      if (t.type == TransferMoneyType.savings) continue; // spendable unchanged
      if (isOnline(t.fromWalletId)) {
        trOnline -= t.amount;
      } else {
        trCash -= t.amount;
      }
      if (isOnline(t.toWalletId)) {
        trOnline += t.amount;
      } else {
        trCash += t.amount;
      }
    }

    for (final e in d.savings.values) {
      if (e.dateMs < startMs || e.dateMs >= endMs) continue;
      final online = isOnline(e.walletId);
      double effect;
      if (e.type == SavingsEntryType.deposit) {
        // New money raises the balance and the savings equally.
        effect = e.newMoney ? 0 : -e.amount;
      } else {
        effect = e.amount;
      }
      if (online) {
        savOnline += effect;
      } else {
        savCash += effect;
      }
    }

    return CycleSummary(
      monthId: monthId,
      start: start,
      endExclusive: end,
      openingCash: _round(spendable(opening, online: false)),
      openingOnline: _round(spendable(opening, online: true)),
      receivedCash: _round(receivedCash),
      receivedOnline: _round(receivedOnline),
      spentCash: _round(spentCash),
      spentOnline: _round(spentOnline),
      transfersCash: _round(trCash),
      transfersOnline: _round(trOnline),
      savingsCash: _round(savCash),
      savingsOnline: _round(savOnline),
      adjustmentsCash: _round(adjCash),
      adjustmentsOnline: _round(adjOnline),
      closingCash: _round(spendable(closing, online: false)),
      closingOnline: _round(spendable(closing, online: true)),
      categoryExpenses: categories.map((k, v) => MapEntry(k, _round(v))),
      dailyExpenses: days.map(_round).toList(growable: false),
    );
  }

  // ── Writing ─────────────────────────────────────────────────

  /// Validates [next] and writes the differences to disk.
  Future<void> _commit(_Data next) async {
    final snap = _compute(next);
    for (final w in next.wallets.values) {
      final balance = snap.balanceOf(w.id);
      final saved = snap.savingsOf(w.id);
      if (balance < -_eps) {
        throw FinanceException(
          '${w.name} would be short by ${CurrencyHelper.format(-balance)}. '
          'Not enough money in this wallet.',
        );
      }
      if (saved < -_eps) {
        throw FinanceException(
          'Savings in ${w.name} cannot go below zero.',
        );
      }
      if (saved > balance + _eps) {
        throw FinanceException(
          '${w.name} needs ${CurrencyHelper.format(saved - balance)} more than '
          'its free money. Release some savings first.',
        );
      }
    }

    final current = _data;
    await _sync(_walletBox, current.wallets, next.wallets, (w) => w.toMap());
    await _sync(_txBox, current.txs, next.txs, (t) => t.toMap());
    await _sync(
      _transferBox,
      current.transfers,
      next.transfers,
      (t) => t.toMap(),
    );
    await _sync(_savingsBox, current.savings, next.savings, (e) => e.toMap());

    // Keep the persisted wallet balances readable for backups and tooling.
    for (final w in next.wallets.values) {
      final balance = snap.balanceOf(w.id);
      if ((w.currentBalance - balance).abs() > _eps) {
        await _walletBox.put(w.id, w.copyWith(currentBalance: balance).toMap());
      }
    }
    _bump();
  }

  Future<void> _sync<T>(
    Box box,
    Map<String, T> before,
    Map<String, T> after,
    Map<String, dynamic> Function(T) toMap,
  ) async {
    for (final key in before.keys) {
      if (!after.containsKey(key)) await box.delete(key);
    }
    for (final entry in after.entries) {
      if (!identical(before[entry.key], entry.value)) {
        await box.put(entry.key, toMap(entry.value));
      }
    }
  }

  String _normalizeCategory(String category, {String fallback = 'other'}) {
    final value = category.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return value.isEmpty ? fallback : value;
  }

  // Wallets

  Future<Wallet> createWallet({
    required String name,
    required WalletType type,
    double initialBalance = 0,
    String bankName = '',
    String accountName = '',
    String phoneNumber = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw FinanceException('Wallet name is required.');
    if (initialBalance < 0) {
      throw FinanceException('Opening balance cannot be negative.');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final wallet = Wallet(
      id: _uuid.v4(),
      name: trimmed,
      type: type,
      currentBalance: 0,
      createdAtMs: nowMs,
      bankName: bankName.trim(),
      accountName: accountName.trim(),
      phoneNumber: phoneNumber.trim(),
    );

    final next = _data.copy();
    next.wallets[wallet.id] = wallet;
    if (initialBalance > _eps) {
      _putAdjustment(next, wallet.id, initialBalance, 'Opening balance', nowMs);
    }
    await _commit(next);
    return wallet;
  }

  /// Renames a wallet. When [newBalance] differs from the current balance the
  /// difference is recorded as an adjustment so history stays consistent.
  Future<void> updateWallet({
    required String walletId,
    required String name,
    String bankName = '',
    String accountName = '',
    String phoneNumber = '',
    double? newBalance,
  }) async {
    final existing = _data.wallets[walletId];
    if (existing == null) throw FinanceException('Wallet not found.');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw FinanceException('Wallet name is required.');

    final next = _data.copy();
    next.wallets[walletId] = existing.copyWith(
      name: trimmed,
      bankName: bankName.trim(),
      accountName: accountName.trim(),
      phoneNumber: phoneNumber.trim(),
    );

    if (newBalance != null) {
      if (newBalance < 0) {
        throw FinanceException('Balance cannot be negative.');
      }
      final current = _compute(_data).balanceOf(walletId);
      final diff = _round(newBalance - current);
      if (diff.abs() > _eps) {
        _putAdjustment(
          next,
          walletId,
          diff,
          'Balance correction',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    await _commit(next);
  }

  bool canDeleteWallet(String walletId) {
    if (walletId == cashWalletId) return false;
    final d = _data;
    if (!d.wallets.containsKey(walletId)) return false;
    if (d.txs.values.any(
      (t) =>
          t.sourceWalletId == walletId && t.category != adjustmentCategory,
    )) {
      return false;
    }
    if (d.transfers.values.any(
      (t) => t.fromWalletId == walletId || t.toWalletId == walletId,
    )) {
      return false;
    }
    if (d.savings.values.any((e) => e.walletId == walletId)) return false;
    final snap = _compute(d);
    return snap.balanceOf(walletId).abs() < _eps;
  }

  Future<void> deleteWallet(String walletId) async {
    if (!canDeleteWallet(walletId)) {
      throw FinanceException(
        'This wallet has records or money in it. Move the money out first.',
      );
    }
    final next = _data.copy();
    next.wallets.remove(walletId);
    next.txs.removeWhere((_, t) => t.sourceWalletId == walletId);
    await _commit(next);
  }

  void _putAdjustment(
    _Data d,
    String walletId,
    double signedAmount,
    String note,
    int dateMs,
  ) {
    final wallet = d.wallets[walletId]!;
    final tx = MoneyTransaction(
      id: _uuid.v4(),
      amount: signedAmount.abs(),
      category: adjustmentCategory,
      sourceWalletId: walletId,
      sourceWalletType: walletTypeToString(wallet.type),
      dateMs: dateMs,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      type: signedAmount >= 0
          ? MoneyTransactionType.income
          : MoneyTransactionType.expense,
      note: note,
    );
    d.txs[tx.id] = tx;
  }

  // Transactions

  /// Adds an income or expense. Returns the amount that had to be taken from
  /// savings because the wallet's free money was not enough.
  Future<double> addTransaction({
    required MoneyTransactionType type,
    required String walletId,
    required double amount,
    required String category,
    required DateTime date,
    String note = '',
  }) async {
    final wallet = _data.wallets[walletId];
    if (wallet == null) {
      throw FinanceException('Selected wallet does not exist.');
    }
    if (amount <= 0) {
      throw FinanceException('Amount must be greater than zero.');
    }
    final tx = MoneyTransaction(
      id: _uuid.v4(),
      amount: _round(amount),
      category: _normalizeCategory(category),
      sourceWalletId: wallet.id,
      sourceWalletType: walletTypeToString(wallet.type),
      dateMs: date.millisecondsSinceEpoch,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      type: type,
      note: note.trim(),
    );
    return await _saveTransaction(tx);
  }

  Future<double> updateTransaction({
    required String transactionId,
    required MoneyTransactionType type,
    required String walletId,
    required double amount,
    required String category,
    required DateTime date,
    String note = '',
  }) async {
    final existing = _data.txs[transactionId];
    if (existing == null) throw FinanceException('Transaction not found.');
    final wallet = _data.wallets[walletId];
    if (wallet == null) {
      throw FinanceException('Selected wallet does not exist.');
    }
    if (amount <= 0) {
      throw FinanceException('Amount must be greater than zero.');
    }
    final tx = MoneyTransaction(
      id: transactionId,
      amount: _round(amount),
      category: _normalizeCategory(category),
      sourceWalletId: wallet.id,
      sourceWalletType: walletTypeToString(wallet.type),
      dateMs: date.millisecondsSinceEpoch,
      createdAtMs: existing.createdAtMs,
      type: type,
      note: note.trim(),
    );
    return await _saveTransaction(tx);
  }

  Future<double> _saveTransaction(MoneyTransaction tx) async {
    final next = _data.copy();
    next.txs[tx.id] = tx;
    // Any earlier automatic savings withdrawal belongs to the old version.
    next.savings.removeWhere((_, e) => e.refId == tx.id);

    var drawn = 0.0;
    if (tx.type == MoneyTransactionType.expense) {
      final snap = _compute(next);
      final balance = snap.balanceOf(tx.sourceWalletId);
      final saved = snap.savingsOf(tx.sourceWalletId);
      final shortfall = _round(saved - balance);
      if (shortfall > _eps && balance >= -_eps) {
        drawn = shortfall;
        final entry = SavingsEntry(
          id: _uuid.v4(),
          walletId: tx.sourceWalletId,
          amount: drawn,
          type: SavingsEntryType.withdraw,
          dateMs: tx.dateMs,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          note: 'Used for expense${tx.note.isEmpty ? '' : ' • ${tx.note}'}',
          refId: tx.id,
        );
        next.savings[entry.id] = entry;
      }
    }
    await _commit(next);
    return drawn;
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (!_data.txs.containsKey(transactionId)) {
      throw FinanceException('Transaction not found.');
    }
    final next = _data.copy();
    next.txs.remove(transactionId);
    next.savings.removeWhere((_, e) => e.refId == transactionId);
    await _commit(next);
  }

  // Cycle allowance

  static String fundTransactionId(String monthId, {required bool online}) =>
      'fund_${online ? 'online' : 'cash'}_$monthId';

  /// Records what you received for a cycle (e.g. from your father) as income
  /// transactions. Re-saving replaces the earlier entries.
  Future<void> setCycleFund({
    required String monthId,
    required double cashAmount,
    required double onlineAmount,
    String? onlineWalletId,
    DateTime? date,
    String cashWalletIdOverride = cashWalletId,
  }) async {
    if (cashAmount < 0 || onlineAmount < 0) {
      throw FinanceException('Amounts cannot be negative.');
    }
    final next = _data.copy();
    final start = monthStartFromId(monthId);
    final end = monthEndExclusiveFromId(monthId);
    var when = date ?? DateTime.now();
    if (when.isBefore(start)) when = start;
    if (!when.isBefore(end)) when = end.subtract(const Duration(days: 1));

    void put({
      required bool online,
      required double amount,
      required String? walletId,
      required String label,
    }) {
      final id = fundTransactionId(monthId, online: online);
      final existing = next.txs[id];
      if (amount <= _eps) {
        next.txs.remove(id);
        return;
      }
      final wallet = walletId == null ? null : next.wallets[walletId];
      if (wallet == null) {
        throw FinanceException(
          online
              ? 'Pick the online wallet that received the money.'
              : 'Cash wallet is missing.',
        );
      }
      next.txs[id] = MoneyTransaction(
        id: id,
        amount: _round(amount),
        category: allowanceCategory,
        sourceWalletId: wallet.id,
        sourceWalletType: walletTypeToString(wallet.type),
        dateMs: (existing != null && existing.dateMs >= start.millisecondsSinceEpoch &&
                existing.dateMs < end.millisecondsSinceEpoch && date == null)
            ? existing.dateMs
            : when.millisecondsSinceEpoch,
        createdAtMs:
            existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        type: MoneyTransactionType.income,
        note: label,
      );
    }

    put(
      online: false,
      amount: cashAmount,
      walletId: cashWalletIdOverride,
      label: 'Cycle allowance (cash)',
    );
    put(
      online: true,
      amount: onlineAmount,
      walletId: onlineWalletId,
      label: 'Cycle allowance (online)',
    );
    await _commit(next);
  }

  ({double cash, double online, String? onlineWalletId}) getCycleFund(
    String monthId,
  ) {
    final cash = _data.txs[fundTransactionId(monthId, online: false)];
    final online = _data.txs[fundTransactionId(monthId, online: true)];
    return (
      cash: cash?.amount ?? 0,
      online: online?.amount ?? 0,
      onlineWalletId: online?.sourceWalletId,
    );
  }

  // Transfers

  Future<void> addTransfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required TransferMoneyType transferType,
    required DateTime date,
    String note = '',
  }) {
    return _saveTransfer(
      MoneyTransfer(
        id: _uuid.v4(),
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        fromWalletType: '',
        toWalletType: '',
        amount: amount,
        type: transferType,
        dateMs: date.millisecondsSinceEpoch,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        note: note,
      ),
    );
  }

  Future<void> updateTransfer({
    required String transferId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required TransferMoneyType transferType,
    required DateTime date,
    String note = '',
  }) {
    final existing = _data.transfers[transferId];
    if (existing == null) throw FinanceException('Transfer not found.');
    return _saveTransfer(
      MoneyTransfer(
        id: transferId,
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        fromWalletType: '',
        toWalletType: '',
        amount: amount,
        type: transferType,
        dateMs: date.millisecondsSinceEpoch,
        createdAtMs: existing.createdAtMs,
        note: note,
      ),
    );
  }

  Future<void> _saveTransfer(MoneyTransfer draft) async {
    if (draft.amount <= 0) {
      throw FinanceException('Amount must be greater than zero.');
    }
    if (draft.fromWalletId == draft.toWalletId) {
      throw FinanceException('Choose two different wallets.');
    }
    final from = _data.wallets[draft.fromWalletId];
    final to = _data.wallets[draft.toWalletId];
    if (from == null || to == null) {
      throw FinanceException('Both wallets are required.');
    }
    final transfer = MoneyTransfer(
      id: draft.id,
      fromWalletId: from.id,
      toWalletId: to.id,
      fromWalletType: walletTypeToString(from.type),
      toWalletType: walletTypeToString(to.type),
      amount: _round(draft.amount),
      type: draft.type,
      dateMs: draft.dateMs,
      createdAtMs: draft.createdAtMs,
      note: draft.note.trim(),
    );
    final next = _data.copy();
    next.transfers[transfer.id] = transfer;
    await _commit(next);
  }

  Future<void> deleteTransfer(String transferId) async {
    if (!_data.transfers.containsKey(transferId)) {
      throw FinanceException('Transfer not found.');
    }
    final next = _data.copy();
    next.transfers.remove(transferId);
    await _commit(next);
  }

  // Savings

  /// Tags money as savings. With [newMoney] the amount is also added to the
  /// wallet (it arrived from outside); otherwise it is taken out of the money
  /// that is currently free to spend in that wallet.
  Future<void> addSavingsDeposit({
    required String walletId,
    required double amount,
    required DateTime date,
    String note = '',
    bool newMoney = false,
  }) {
    return _saveSavings(
      walletId: walletId,
      amount: amount,
      date: date,
      note: note,
      type: SavingsEntryType.deposit,
      newMoney: newMoney,
    );
  }

  /// Releases saved money back to the wallet's spendable balance.
  Future<void> withdrawSavings({
    required String walletId,
    required double amount,
    required DateTime date,
    String note = '',
  }) {
    return _saveSavings(
      walletId: walletId,
      amount: amount,
      date: date,
      note: note,
      type: SavingsEntryType.withdraw,
      newMoney: false,
    );
  }

  Future<void> _saveSavings({
    required String walletId,
    required double amount,
    required DateTime date,
    required String note,
    required SavingsEntryType type,
    required bool newMoney,
  }) async {
    if (amount <= 0) {
      throw FinanceException('Amount must be greater than zero.');
    }
    if (!_data.wallets.containsKey(walletId)) {
      throw FinanceException('Selected wallet was not found.');
    }
    final entry = SavingsEntry(
      id: _uuid.v4(),
      walletId: walletId,
      amount: _round(amount),
      type: type,
      dateMs: date.millisecondsSinceEpoch,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      note: note.trim(),
      newMoney: newMoney,
    );
    final next = _data.copy();
    next.savings[entry.id] = entry;
    await _commit(next);
  }

  Future<void> deleteSavingsEntry(String entryId) async {
    final entry = _data.savings[entryId];
    if (entry == null) throw FinanceException('Savings entry not found.');
    if (entry.refId != null) {
      throw FinanceException(
        'This withdrawal was created by an expense. Edit or delete that '
        'expense instead.',
      );
    }
    final next = _data.copy();
    next.savings.remove(entryId);
    await _commit(next);
  }

  // ── Migration ───────────────────────────────────────────────

  /// Converts data written by older builds (mutable balances + monthly fund
  /// records) into the ledger model without changing any wallet balance.
  Future<void> _migrateLegacyIfNeeded() async {
    if (StorageService.getBool(_ledgerMigrationKey)) return;

    final d = _load();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Monthly fund records become allowance income.
    for (final raw in _legacyFundBox.values.whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      final monthId = (map['monthId'] as String?) ?? '';
      if (monthId.isEmpty) continue;
      final offline = (map['offlineReceived'] as num?)?.toDouble() ?? 0;
      final online = (map['onlineReceived'] as num?)?.toDouble() ?? 0;
      final onlineWalletId = map['onlineWalletId'] as String?;
      final when = monthStartFromId(monthId).millisecondsSinceEpoch;

      void add(bool isOnline, double amount, String? walletId) {
        if (amount <= _eps) return;
        final wallet = walletId == null ? null : d.wallets[walletId];
        if (wallet == null) return;
        final id = fundTransactionId(monthId, online: isOnline);
        d.txs[id] = MoneyTransaction(
          id: id,
          amount: amount,
          category: allowanceCategory,
          sourceWalletId: wallet.id,
          sourceWalletType: walletTypeToString(wallet.type),
          dateMs: when,
          createdAtMs: nowMs,
          type: MoneyTransactionType.income,
          note: 'Cycle allowance (migrated)',
        );
      }

      add(false, offline, cashWalletId);
      add(true, online, onlineWalletId);
    }

    // Make the derived balances match what the old app showed.
    final snap = _compute(d);
    final epoch = DateTime(2000).millisecondsSinceEpoch;
    for (final w in d.wallets.values.toList()) {
      final diff = _round(w.currentBalance - snap.balanceOf(w.id));
      if (diff.abs() > _eps) {
        _putAdjustment(d, w.id, diff, 'Opening balance (migrated)', epoch);
      }
    }

    // Keep the savings tags inside what each wallet actually holds.
    final fixed = _compute(d);
    for (final w in d.wallets.values) {
      final balance = fixed.balanceOf(w.id);
      final saved = fixed.savingsOf(w.id);
      SavingsEntry? fix;
      if (saved < -_eps) {
        fix = SavingsEntry(
          id: _uuid.v4(),
          walletId: w.id,
          amount: -saved,
          type: SavingsEntryType.deposit,
          dateMs: epoch,
          createdAtMs: nowMs,
          note: 'Savings correction (migrated)',
        );
      } else if (saved > balance + _eps) {
        fix = SavingsEntry(
          id: _uuid.v4(),
          walletId: w.id,
          amount: saved - (balance < 0 ? 0 : balance),
          type: SavingsEntryType.withdraw,
          dateMs: epoch,
          createdAtMs: nowMs,
          note: 'Savings correction (migrated)',
        );
      }
      if (fix != null) d.savings[fix.id] = fix;
    }

    // Persist everything, normalising the old savings records on the way.
    for (final tx in d.txs.values) {
      await _txBox.put(tx.id, tx.toMap());
    }
    for (final e in d.savings.values) {
      await _savingsBox.put(e.id, e.toMap());
    }
    final finalSnap = _compute(d);
    for (final w in d.wallets.values) {
      await _walletBox.put(
        w.id,
        w.copyWith(currentBalance: finalSnap.balanceOf(w.id)).toMap(),
      );
    }

    await _legacyFundBox.clear();
    await _legacySourceBox.clear();
    await _legacyMetaBox.clear();
    await StorageService.setBool(_ledgerMigrationKey, true);
    _invalidate();
  }

  // ── Export ──────────────────────────────────────────────────

  String buildMonthlyExpenseCsv({required String monthId}) {
    final summary = computeCycleSummary(monthId);
    final end = summary.endExclusive.subtract(const Duration(days: 1));
    final expenses = getCycleExpenseTransactions(monthId);
    final wallets = getWallets();
    final names = {for (final w in wallets) w.id: w.name};
    final dateFmt = DateFormat('yyyy-MM-dd');

    final categoryRows = summary.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String f(double v) => v.toStringAsFixed(2);

    final sb = StringBuffer()
      ..writeln('DayLee Finance Export')
      ..writeln('Cycle,${_csv(cycleTitleFromId(monthId))}')
      ..writeln(
        'Range,${_csv('${dateFmt.format(summary.start)} to ${dateFmt.format(end)}')}',
      )
      ..writeln(
        'Generated,${_csv(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()))}',
      )
      ..writeln()
      ..writeln('Summary,Cash,Online,Total')
      ..writeln(
        'Opening,${f(summary.openingCash)},${f(summary.openingOnline)},${f(summary.openingTotal)}',
      )
      ..writeln(
        'Received,${f(summary.receivedCash)},${f(summary.receivedOnline)},${f(summary.receivedTotal)}',
      )
      ..writeln(
        'Spent,${f(summary.spentCash)},${f(summary.spentOnline)},${f(summary.spentTotal)}',
      )
      ..writeln(
        'Exchanges,${f(summary.transfersCash)},${f(summary.transfersOnline)},${f(summary.transfersCash + summary.transfersOnline)}',
      )
      ..writeln(
        'Savings moves,${f(summary.savingsCash)},${f(summary.savingsOnline)},${f(summary.savingsTotal)}',
      )
      ..writeln(
        'Closing,${f(summary.closingCash)},${f(summary.closingOnline)},${f(summary.closingTotal)}',
      )
      ..writeln()
      ..writeln('Expense by category,Amount');
    if (categoryRows.isEmpty) {
      sb.writeln('None,0.00');
    }
    for (final row in categoryRows) {
      sb.writeln('${_csv(row.key)},${f(row.value)}');
    }

    sb
      ..writeln()
      ..writeln('Date,Wallet,Category,Note,Amount');
    var total = 0.0;
    for (final tx in expenses) {
      total += tx.amount;
      sb.writeln(
        '${dateFmt.format(DateTime.fromMillisecondsSinceEpoch(tx.dateMs))},'
        '${_csv(names[tx.sourceWalletId] ?? 'Unknown')},'
        '${_csv(tx.category)},${_csv(tx.note)},${f(tx.amount)}',
      );
    }
    sb
      ..writeln('Total,,,,${f(total)}')
      ..writeln()
      ..writeln('Wallet,Type,Balance,Savings,Spendable');
    for (final w in wallets) {
      sb.writeln(
        '${_csv(w.name)},${walletTypeToString(w.type)},${f(w.currentBalance)},${f(w.savingsBalance)},${f(w.spendable)}',
      );
    }
    return sb.toString();
  }

  String _csv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
