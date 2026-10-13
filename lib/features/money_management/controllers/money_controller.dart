import 'package:get/get.dart';

import '../../../core/utils/currency_helper.dart';
import '../../../data/repositories/money_repository.dart';
import '../../../data/services/category_service.dart';
import '../../../data/services/notification_center.dart';
import '../models/money_transaction.dart';
import '../models/money_transfer.dart';
import '../models/savings_entry.dart';
import '../models/wallet.dart';

enum ActivityFilter { all, expense, income }

class MoneyController extends GetxController {
  final _repo = Get.find<MoneyRepository>();

  final selectedPageIndex = 0.obs;
  final selectedMonthId = ''.obs;
  final activityFilter = ActivityFilter.all.obs;
  final categoryFilter = 'all'.obs;
  final walletFilter = 'all'.obs;

  final wallets = <Wallet>[].obs;
  final transactions = <MoneyTransaction>[].obs;
  final transfers = <MoneyTransfer>[].obs;
  final savingsEntries = <SavingsEntry>[].obs;
  final summary = Rxn<CycleSummary>();
  final isReady = false.obs;

  Worker? _revisionWorker;

  MoneyRepository get repo => _repo;

  String get currentMonthId => selectedMonthId.value;
  bool get isCurrentCycle => selectedMonthId.value == _repo.currentMonthId;
  String get cycleTitle => _repo.cycleTitleFromId(selectedMonthId.value);
  String get cycleLabel => _repo.cycleLabelFromId(selectedMonthId.value);

  CycleSummary get cycle => summary.value!;

  List<Wallet> get cashWallets =>
      wallets.where((w) => w.type == WalletType.cash).toList(growable: false);
  List<Wallet> get bankWallets =>
      wallets.where((w) => w.type == WalletType.bank).toList(growable: false);
  List<Wallet> get mobileWallets =>
      wallets.where((w) => w.type == WalletType.mobile).toList(growable: false);
  List<Wallet> get onlineWallets =>
      wallets.where((w) => w.isOnline).toList(growable: false);

  Wallet? get cashWallet =>
      wallets.firstWhereOrNull((w) => w.id == MoneyRepository.cashWalletId);

  double get totalBalance =>
      wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
  double get totalSavings =>
      wallets.fold(0.0, (sum, w) => sum + w.savingsBalance);
  double get totalSpendable => wallets.fold(0.0, (sum, w) => sum + w.spendable);

  Wallet? walletById(String id) => wallets.firstWhereOrNull((w) => w.id == id);

  List<String> get expenseCategories => CategoryService.expenseCategories();

  bool _inCycle(int ms) {
    final c = summary.value;
    if (c == null) return false;
    return ms >= c.start.millisecondsSinceEpoch &&
        ms < c.endExclusive.millisecondsSinceEpoch;
  }

  List<MoneyTransaction> get cycleTransactions =>
      transactions.where((tx) => _inCycle(tx.dateMs)).toList(growable: false);

  List<MoneyTransfer> get cycleTransfers =>
      transfers.where((t) => _inCycle(t.dateMs)).toList(growable: false);

  /// Income and expenses of the cycle after applying the active filters.
  List<MoneyTransaction> get filteredTransactions {
    return cycleTransactions
        .where((tx) {
          if (tx.category == MoneyRepository.adjustmentCategory &&
              activityFilter.value != ActivityFilter.all) {
            return false;
          }
          switch (activityFilter.value) {
            case ActivityFilter.expense:
              if (tx.type != MoneyTransactionType.expense) return false;
            case ActivityFilter.income:
              if (tx.type != MoneyTransactionType.income) return false;
            case ActivityFilter.all:
              break;
          }
          if (categoryFilter.value != 'all' &&
              tx.category != categoryFilter.value) {
            return false;
          }
          if (walletFilter.value != 'all' &&
              tx.sourceWalletId != walletFilter.value) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Categories that appear in the current cycle (for the filter chips).
  List<String> get cycleCategories {
    final set = <String>{};
    for (final tx in cycleTransactions) {
      if (tx.category != MoneyRepository.adjustmentCategory) {
        set.add(tx.category);
      }
    }
    return set.toList()..sort();
  }

  MoneyTransaction? findTransactionById(String id) =>
      transactions.firstWhereOrNull((tx) => tx.id == id);

  @override
  void onInit() {
    super.onInit();
    selectedMonthId.value = _repo.currentMonthId;
    refreshAll();
    isReady.value = true;
    // Any write anywhere (dashboard quick-add, restore, ...) refreshes us.
    _revisionWorker = ever(_repo.revision, (_) => refreshAll());
  }

  @override
  void onClose() {
    _revisionWorker?.dispose();
    super.onClose();
  }

  void refreshAll() {
    wallets.assignAll(_repo.getWallets());
    transactions.assignAll(_repo.getTransactions());
    transfers.assignAll(_repo.getTransfers());
    savingsEntries.assignAll(_repo.getSavingsEntries());
    summary.value = _repo.computeCycleSummary(selectedMonthId.value);
  }

  void setPageIndex(int value) {
    if (value < 0 || value > 3) return;
    selectedPageIndex.value = value;
  }

  void goToPreviousCycle() {
    selectedMonthId.value = _repo.previousMonthId(selectedMonthId.value);
    _resetFilters();
    refreshAll();
  }

  void goToNextCycle() {
    selectedMonthId.value = _repo.nextMonthId(selectedMonthId.value);
    _resetFilters();
    refreshAll();
  }

  void goToCurrentCycle() {
    selectedMonthId.value = _repo.currentMonthId;
    _resetFilters();
    refreshAll();
  }

  void _resetFilters() {
    activityFilter.value = ActivityFilter.all;
    categoryFilter.value = 'all';
    walletFilter.value = 'all';
  }

  // ── Mutations ───────────────────────────────────────────────

  Future<bool> addTransaction({
    required MoneyTransactionType type,
    required double amount,
    required String category,
    required String walletId,
    required DateTime date,
    String note = '',
  }) async {
    return _run(() async {
      final drawn = await _repo.addTransaction(
        type: type,
        walletId: walletId,
        amount: amount,
        category: category,
        date: date,
        note: note,
      );
      if (type == MoneyTransactionType.expense) {
        await NotificationCenter.onExpenseSaved();
      }
      return _savingsNote(
        type == MoneyTransactionType.expense
            ? 'Expense added'
            : 'Income added',
        drawn,
      );
    });
  }

  Future<bool> updateTransaction({
    required String transactionId,
    required MoneyTransactionType type,
    required double amount,
    required String category,
    required String walletId,
    required DateTime date,
    String note = '',
  }) async {
    return _run(() async {
      final drawn = await _repo.updateTransaction(
        transactionId: transactionId,
        type: type,
        walletId: walletId,
        amount: amount,
        category: category,
        date: date,
        note: note,
      );
      if (type == MoneyTransactionType.expense) {
        await NotificationCenter.onExpenseSaved();
      }
      return _savingsNote('Transaction updated', drawn);
    });
  }

  Future<bool> deleteTransaction(String id) =>
      _run(() async {
        await _repo.deleteTransaction(id);
        return 'Transaction deleted';
      });

  Future<bool> setCycleFund({
    required double cash,
    required double online,
    String? onlineWalletId,
    DateTime? date,
  }) => _run(() async {
    await _repo.setCycleFund(
      monthId: selectedMonthId.value,
      cashAmount: cash,
      onlineAmount: online,
      onlineWalletId: onlineWalletId,
      date: date,
    );
    return 'Cycle allowance saved';
  });

  Future<bool> addWallet({
    required String name,
    required WalletType type,
    double balance = 0,
    String bankName = '',
    String accountName = '',
    String phoneNumber = '',
  }) => _run(() async {
    await _repo.createWallet(
      name: name,
      type: type,
      initialBalance: balance,
      bankName: bankName,
      accountName: accountName,
      phoneNumber: phoneNumber,
    );
    return 'Wallet added';
  });

  Future<bool> updateWallet({
    required Wallet wallet,
    required String name,
    required double balance,
    String bankName = '',
    String accountName = '',
    String phoneNumber = '',
  }) => _run(() async {
    await _repo.updateWallet(
      walletId: wallet.id,
      name: name,
      bankName: bankName,
      accountName: accountName,
      phoneNumber: phoneNumber,
      newBalance: balance,
    );
    return 'Wallet updated';
  });

  bool canDeleteWallet(String id) => _repo.canDeleteWallet(id);

  Future<bool> deleteWallet(String id) => _run(() async {
    await _repo.deleteWallet(id);
    return 'Wallet deleted';
  });

  Future<bool> addTransfer({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required TransferMoneyType type,
    required DateTime date,
    String note = '',
  }) => _run(() async {
    await _repo.addTransfer(
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      transferType: type,
      date: date,
      note: note,
    );
    return 'Transfer saved';
  });

  Future<bool> updateTransfer({
    required String transferId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required TransferMoneyType type,
    required DateTime date,
    String note = '',
  }) => _run(() async {
    await _repo.updateTransfer(
      transferId: transferId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      amount: amount,
      transferType: type,
      date: date,
      note: note,
    );
    return 'Transfer updated';
  });

  Future<bool> deleteTransfer(String id) => _run(() async {
    await _repo.deleteTransfer(id);
    return 'Transfer deleted';
  });

  Future<bool> addSavings({
    required String walletId,
    required double amount,
    required DateTime date,
    required bool newMoney,
    String note = '',
  }) => _run(() async {
    await _repo.addSavingsDeposit(
      walletId: walletId,
      amount: amount,
      date: date,
      note: note,
      newMoney: newMoney,
    );
    return newMoney ? 'Added to savings' : 'Moved to savings';
  });

  Future<bool> withdrawSavings({
    required String walletId,
    required double amount,
    required DateTime date,
    String note = '',
  }) => _run(() async {
    await _repo.withdrawSavings(
      walletId: walletId,
      amount: amount,
      date: date,
      note: note,
    );
    return 'Released to spendable money';
  });

  Future<bool> deleteSavingsEntry(String id) => _run(() async {
    await _repo.deleteSavingsEntry(id);
    return 'Savings entry deleted';
  });

  String _savingsNote(String base, double drawn) {
    if (drawn <= 0) return base;
    return '$base • ${CurrencyHelper.format(drawn)} came from savings';
  }

  Future<bool> _run(Future<String> Function() action) async {
    try {
      final message = await action();
      Get.closeAllSnackbars();
      Get.snackbar('Done', message, duration: const Duration(seconds: 2));
      return true;
    } on FinanceException catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar('Can\'t do that', e.message);
      return false;
    } catch (_) {
      Get.snackbar('Error', 'Something went wrong. Please try again.');
      return false;
    }
  }
}
