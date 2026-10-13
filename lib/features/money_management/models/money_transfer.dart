enum TransferMoneyType { expenseFund, savings }

TransferMoneyType transferMoneyTypeFromString(String value) {
  switch (value) {
    case 'savings':
      return TransferMoneyType.savings;
    case 'expense_fund':
    default:
      return TransferMoneyType.expenseFund;
  }
}

String transferMoneyTypeToString(TransferMoneyType value) {
  switch (value) {
    case TransferMoneyType.expenseFund:
      return 'expense_fund';
    case TransferMoneyType.savings:
      return 'savings';
  }
}

class MoneyTransfer {
  const MoneyTransfer({
    required this.id,
    required this.fromWalletId,
    required this.toWalletId,
    required this.fromWalletType,
    required this.toWalletType,
    required this.amount,
    required this.type,
    required this.dateMs,
    required this.createdAtMs,
    this.note = '',
  });

  final String id;
  final String fromWalletId;
  final String toWalletId;
  final String fromWalletType;
  final String toWalletType;
  final double amount;
  final TransferMoneyType type;
  final int dateMs;
  final int createdAtMs;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'fromWalletType': fromWalletType,
      'toWalletType': toWalletType,
      'amount': amount,
      'type': transferMoneyTypeToString(type),
      'dateMs': dateMs,
      'createdAtMs': createdAtMs,
      'note': note,
    };
  }

  static MoneyTransfer fromMap(Map<String, dynamic> map) {
    return MoneyTransfer(
      id: (map['id'] as String?) ?? '',
      fromWalletId: (map['fromWalletId'] as String?) ?? '',
      toWalletId: (map['toWalletId'] as String?) ?? '',
      fromWalletType: (map['fromWalletType'] as String?) ?? 'cash',
      toWalletType: (map['toWalletType'] as String?) ?? 'mobile',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: transferMoneyTypeFromString((map['type'] as String?) ?? ''),
      dateMs: (map['dateMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      note: (map['note'] as String?) ?? '',
    );
  }
}
