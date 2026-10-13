enum SavingsEntryType { deposit, withdraw }

SavingsEntryType savingsEntryTypeFromString(String value) {
  switch (value) {
    case 'withdraw':
      return SavingsEntryType.withdraw;
    case 'deposit':
    default:
      return SavingsEntryType.deposit;
  }
}

String savingsEntryTypeToString(SavingsEntryType value) {
  switch (value) {
    case SavingsEntryType.deposit:
      return 'deposit';
    case SavingsEntryType.withdraw:
      return 'withdraw';
  }
}

/// Tags part of a wallet's balance as savings (deposit) or releases it back to
/// spendable money (withdraw).
///
/// * [newMoney] deposits also add the amount to the wallet balance (money that
///   arrived from outside, e.g. a transfer from your father straight into
///   savings).
/// * [refId] links an automatic withdrawal to the expense that caused it, so
///   it is undone together with that expense.
class SavingsEntry {
  const SavingsEntry({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    required this.dateMs,
    required this.createdAtMs,
    this.note = '',
    this.newMoney = false,
    this.refId,
  });

  final String id;
  final String walletId;
  final double amount;
  final SavingsEntryType type;
  final int dateMs;
  final int createdAtMs;
  final String note;
  final bool newMoney;
  final String? refId;

  double get signedAmount =>
      type == SavingsEntryType.deposit ? amount : -amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'walletId': walletId,
      'amount': amount,
      'type': savingsEntryTypeToString(type),
      'dateMs': dateMs,
      'createdAtMs': createdAtMs,
      'note': note,
      'newMoney': newMoney,
      'refId': refId,
    };
  }

  static SavingsEntry fromMap(Map<String, dynamic> map) {
    return SavingsEntry(
      id: (map['id'] as String?) ?? '',
      walletId: (map['walletId'] as String?) ?? '',
      // Older builds stored negative amounts for withdrawals; the sign lives
      // in [type] now.
      amount: ((map['amount'] as num?)?.toDouble() ?? 0).abs(),
      type: savingsEntryTypeFromString((map['type'] as String?) ?? ''),
      dateMs: (map['dateMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      note: (map['note'] as String?) ?? '',
      newMoney: map['newMoney'] == true,
      refId: map['refId'] as String?,
    );
  }
}
