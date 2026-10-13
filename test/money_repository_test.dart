import 'dart:io';

import 'package:daylee/data/repositories/money_repository.dart';
import 'package:daylee/data/services/hive_service.dart';
import 'package:daylee/data/services/storage_service.dart';
import 'package:daylee/features/money_management/models/money_transaction.dart';
import 'package:daylee/features/money_management/models/money_transfer.dart';
import 'package:daylee/features/money_management/models/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// These tests describe how the owner of the app really uses money:
///  * part of the monthly allowance arrives as cash, part online,
///  * leftover cash carries over while the same amount arrives online as
///    savings,
///  * online money is swapped for cash with friends.
void main() {
  late Directory dir;
  late MoneyRepository repo;

  Future<void> boot({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues({
      'money_cycle_start_day': 25,
      ...prefs,
    });
    await StorageService.init();
    dir = await Directory.systemTemp.createTemp('daylee_test_');
    Hive.init(dir.path);
    for (final name in [
      HiveService.moneyWalletBox,
      HiveService.moneyTransactionBox,
      HiveService.moneyTransferBox,
      HiveService.moneySavingsBox,
      HiveService.moneyMonthlyFundBox,
      HiveService.moneySourceBox,
      HiveService.moneyMetaBox,
    ]) {
      await Hive.openBox(name);
    }
    repo = MoneyRepository();
  }

  setUp(() async {
    await boot(prefs: {'money_ledger_v2_done': true});
    await repo.init();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  // A fixed cycle: 25 Oct 2026 .. 24 Nov 2026 (id 2026-11).
  const monthId = '2026-11';
  final inCycle = DateTime(2026, 11, 3);

  Future<Wallet> bank() => repo.createWallet(name: 'DBBL', type: WalletType.bank);

  test('cycle ids follow the 25th boundary', () {
    expect(repo.monthIdFromDate(DateTime(2026, 10, 24)), '2026-10');
    expect(repo.monthIdFromDate(DateTime(2026, 10, 25)), '2026-11');
    expect(repo.monthIdFromDate(DateTime(2026, 12, 31)), '2027-01');
    expect(repo.monthStartFromId(monthId), DateTime(2026, 10, 25));
    expect(repo.monthEndExclusiveFromId(monthId), DateTime(2026, 11, 25));
    expect(repo.previousMonthId(monthId), '2026-10');
    expect(repo.nextMonthId(monthId), '2026-12');
  });

  test('allowance, cash expense and online expense are counted once', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 5000,
      onlineAmount: 3000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: MoneyRepository.cashWalletId,
      amount: 1200,
      category: 'Food',
      date: inCycle,
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: online.id,
      amount: 500,
      category: 'bills',
      date: inCycle,
    );

    final s = repo.computeCycleSummary(monthId);
    expect(s.receivedCash, 5000);
    expect(s.receivedOnline, 3000);
    expect(s.spentCash, 1200);
    expect(s.spentOnline, 500);
    expect(s.closingCash, 3800);
    expect(s.closingOnline, 2500); // 3000 - 500, not 3000 - 500 - 500
    expect(s.closingTotal, 6300);
    expect(s.categoryExpenses['food'], 1200);
    expect(repo.getWalletById(online.id)!.currentBalance, 2500);
    expect(s.spentRatio, closeTo(1700 / 8000, 1e-9));
  });

  test('cannot overspend a wallet and nothing is written when it fails', () async {
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 100,
      onlineAmount: 0,
      date: inCycle,
    );
    expect(
      () => repo.addTransaction(
        type: MoneyTransactionType.expense,
        walletId: MoneyRepository.cashWalletId,
        amount: 150,
        category: 'food',
        date: inCycle,
      ),
      throwsA(isA<FinanceException>()),
    );
    expect(repo.getTransactions().length, 1); // only the allowance
    expect(repo.getWalletById(MoneyRepository.cashWalletId)!.currentBalance, 100);
  });

  test('swapping online money for cash with a friend is not spending', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 1000,
      onlineAmount: 2000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransfer(
      fromWalletId: online.id,
      toWalletId: MoneyRepository.cashWalletId,
      amount: 700,
      transferType: TransferMoneyType.expenseFund,
      date: inCycle,
    );

    final s = repo.computeCycleSummary(monthId);
    expect(s.spentTotal, 0);
    expect(s.closingCash, 1700);
    expect(s.closingOnline, 1300);
    expect(s.transfersCash, 700);
    expect(s.transfersOnline, -700);
    expect(s.closingTotal, 3000);
  });

  test('leftover cash carries over and online savings stay separate', () async {
    final online = await bank();
    // Previous cycle (2026-10): 25 Sep .. 24 Oct.
    await repo.setCycleFund(
      monthId: '2026-10',
      cashAmount: 4000,
      onlineAmount: 2000,
      onlineWalletId: online.id,
      date: DateTime(2026, 9, 26),
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: MoneyRepository.cashWalletId,
      amount: 3000,
      category: 'food',
      date: DateTime(2026, 10, 2),
    );
    final previous = repo.computeCycleSummary('2026-10');
    expect(previous.closingCash, 1000);

    // New cycle: father sends the same 1000 online, saved. New allowance too.
    await repo.addSavingsDeposit(
      walletId: online.id,
      amount: 1000,
      date: DateTime(2026, 10, 26),
      newMoney: true,
    );
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 4000,
      onlineAmount: 2000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );

    final s = repo.computeCycleSummary(monthId);
    expect(s.openingCash, 1000); // carried over automatically
    expect(s.openingOnline, 2000); // previous online leftover
    expect(s.closingCash, 5000);
    expect(s.closingOnline, 4000); // savings are NOT spendable
    expect(repo.totalSavings, 1000);
    expect(repo.getWalletById(online.id)!.currentBalance, 5000);
    expect(repo.getWalletById(online.id)!.spendable, 4000);
  });

  test('statement identity holds: closing = opening + flows', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 3000,
      onlineAmount: 2000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: online.id,
      amount: 300,
      category: 'transport',
      date: inCycle,
    );
    await repo.addTransfer(
      fromWalletId: online.id,
      toWalletId: MoneyRepository.cashWalletId,
      amount: 400,
      transferType: TransferMoneyType.expenseFund,
      date: inCycle,
    );
    await repo.addSavingsDeposit(
      walletId: online.id,
      amount: 250,
      date: inCycle,
    );
    await repo.updateWallet(
      walletId: MoneyRepository.cashWalletId,
      name: 'Cash',
      newBalance: 3500, // found 100 extra cash
    );

    for (final id in ['2026-10', monthId, '2026-12']) {
      final s = repo.computeCycleSummary(id);
      expect(
        s.closingCash,
        closeTo(
          s.openingCash + s.receivedCash - s.spentCash + s.transfersCash +
              s.savingsCash + s.adjustmentsCash,
          0.005,
        ),
        reason: 'cash identity in $id',
      );
      expect(
        s.closingOnline,
        closeTo(
          s.openingOnline + s.receivedOnline - s.spentOnline +
              s.transfersOnline + s.savingsOnline + s.adjustmentsOnline,
          0.005,
        ),
        reason: 'online identity in $id',
      );
    }
  });

  test('spending beyond free money uses savings and is undone on delete', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 0,
      onlineAmount: 1000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addSavingsDeposit(
      walletId: online.id,
      amount: 500,
      date: DateTime(2026, 10, 27),
      newMoney: true,
    ); // balance 1500, savings 500, free 1000

    final drawn = await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: online.id,
      amount: 1200,
      category: 'shopping',
      date: inCycle,
    );
    expect(drawn, 200);
    var w = repo.getWalletById(online.id)!;
    expect(w.currentBalance, 300);
    expect(w.savingsBalance, 300);
    expect(w.spendable, 0);

    final tx = repo.getTransactions().firstWhere((t) => t.category == 'shopping');
    await repo.deleteTransaction(tx.id);
    w = repo.getWalletById(online.id)!;
    expect(w.currentBalance, 1500);
    expect(w.savingsBalance, 500);
    expect(repo.getSavingsEntries().where((e) => e.refId != null), isEmpty);
  });

  test('editing a transaction moves money between wallets correctly', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 1000,
      onlineAmount: 1000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: MoneyRepository.cashWalletId,
      amount: 400,
      category: 'food',
      date: inCycle,
    );
    final tx = repo.getTransactions().firstWhere((t) => t.category == 'food');

    await repo.updateTransaction(
      transactionId: tx.id,
      type: MoneyTransactionType.expense,
      walletId: online.id,
      amount: 250,
      category: 'food',
      date: inCycle,
    );
    expect(repo.getWalletById(MoneyRepository.cashWalletId)!.currentBalance, 1000);
    expect(repo.getWalletById(online.id)!.currentBalance, 750);

    await repo.deleteTransaction(tx.id);
    expect(repo.getWalletById(online.id)!.currentBalance, 1000);
  });

  test('transfers can be edited and deleted', () async {
    final online = await bank();
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 0,
      onlineAmount: 1000,
      onlineWalletId: online.id,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransfer(
      fromWalletId: online.id,
      toWalletId: MoneyRepository.cashWalletId,
      amount: 600,
      transferType: TransferMoneyType.expenseFund,
      date: inCycle,
    );
    final t = repo.getTransfers().single;
    await repo.updateTransfer(
      transferId: t.id,
      fromWalletId: online.id,
      toWalletId: MoneyRepository.cashWalletId,
      amount: 300,
      transferType: TransferMoneyType.expenseFund,
      date: inCycle,
    );
    expect(repo.getWalletById(MoneyRepository.cashWalletId)!.currentBalance, 300);
    expect(
      () => repo.updateTransfer(
        transferId: t.id,
        fromWalletId: online.id,
        toWalletId: MoneyRepository.cashWalletId,
        amount: 5000,
        transferType: TransferMoneyType.expenseFund,
        date: inCycle,
      ),
      throwsA(isA<FinanceException>()),
    );
    // Failed edit changed nothing.
    expect(repo.getWalletById(MoneyRepository.cashWalletId)!.currentBalance, 300);
    await repo.deleteTransfer(t.id);
    expect(repo.getWalletById(online.id)!.currentBalance, 1000);
  });

  test('a delete that would leave a wallet negative is refused', () async {
    await repo.setCycleFund(
      monthId: monthId,
      cashAmount: 500,
      onlineAmount: 0,
      date: DateTime(2026, 10, 26),
    );
    await repo.addTransaction(
      type: MoneyTransactionType.expense,
      walletId: MoneyRepository.cashWalletId,
      amount: 400,
      category: 'food',
      date: inCycle,
    );
    // Removing the allowance would make the earlier expense impossible.
    expect(
      () => repo.deleteTransaction(
        MoneyRepository.fundTransactionId(monthId, online: false),
      ),
      throwsA(isA<FinanceException>()),
    );
    expect(repo.getWalletById(MoneyRepository.cashWalletId)!.currentBalance, 100);
  });

  test('wallet creation, balance correction and deletion', () async {
    final w = await repo.createWallet(
      name: 'bKash',
      type: WalletType.mobile,
      initialBalance: 800,
    );
    expect(repo.getWalletById(w.id)!.currentBalance, 800);
    expect(repo.canDeleteWallet(w.id), isFalse);

    await repo.updateWallet(walletId: w.id, name: 'bKash', newBalance: 650);
    expect(repo.getWalletById(w.id)!.currentBalance, 650);

    await repo.updateWallet(walletId: w.id, name: 'bKash', newBalance: 0);
    expect(repo.canDeleteWallet(w.id), isTrue);
    await repo.deleteWallet(w.id);
    expect(repo.getWalletById(w.id), isNull);
    expect(repo.canDeleteWallet(MoneyRepository.cashWalletId), isFalse);
  });

  test('summary helpers behave on the first and last day', () async {
    final s = repo.computeCycleSummary(monthId);
    expect(s.totalDays, 31);
    expect(s.daysElapsed(DateTime(2026, 10, 25, 9)), 1);
    expect(s.daysLeft(DateTime(2026, 10, 25, 9)), 31);
    expect(s.daysElapsed(DateTime(2026, 11, 24, 23)), 31);
    expect(s.daysLeft(DateTime(2026, 11, 24, 23)), 1);
  });

  group('migration from the old format', () {
    test('keeps every wallet balance and converts monthly funds', () async {
      await Hive.close();
      await dir.delete(recursive: true);
      await boot(); // no migration flag
      final wallets = Hive.box(HiveService.moneyWalletBox);
      await wallets.put('wallet_cash', {
        'id': 'wallet_cash',
        'name': 'Cash Wallet',
        'type': 'cash',
        'currentBalance': 1234.5,
        'createdAtMs': 1,
      });
      await wallets.put('w_bank', {
        'id': 'w_bank',
        'name': 'City Bank',
        'type': 'bank',
        'currentBalance': 9000.0,
        'createdAtMs': 2,
      });
      await Hive.box(HiveService.moneyMonthlyFundBox).put('2026-11', {
        'monthId': '2026-11',
        'offlineReceived': 2000.0,
        'onlineReceived': 3000.0,
        'onlineWalletId': 'w_bank',
      });
      // The old sign bug: withdrawals stored with negative amounts.
      await Hive.box(HiveService.moneySavingsBox).put('s1', {
        'id': 's1',
        'walletId': 'w_bank',
        'amount': -400.0,
        'type': 'withdraw',
        'dateMs': DateTime(2026, 11, 2).millisecondsSinceEpoch,
        'createdAtMs': 1,
        'note': '',
      });

      await repo.init();

      expect(repo.getWalletById('wallet_cash')!.currentBalance, 1234.5);
      expect(repo.getWalletById('w_bank')!.currentBalance, 9000);
      final s = repo.computeCycleSummary('2026-11');
      expect(s.receivedCash, 2000);
      expect(s.receivedOnline, 3000);
      for (final w in repo.getWallets()) {
        expect(w.savingsBalance, greaterThanOrEqualTo(0));
        expect(w.savingsBalance, lessThanOrEqualTo(w.currentBalance));
      }
      // Running it again must not change anything.
      final before = repo.getTransactions().length;
      await repo.init();
      expect(repo.getTransactions().length, before);
    });
  });
}
