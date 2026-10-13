enum MoneyTransactionType { expense, income }

MoneyTransactionType moneyTransactionTypeFromString(String value) {
  switch (value) {
    case 'income':
      return MoneyTransactionType.income;
    case 'expense':
    default:
      return MoneyTransactionType.expense;
  }
}

String moneyTransactionTypeToString(MoneyTransactionType value) {
  switch (value) {
    case MoneyTransactionType.expense:
      return 'expense';
    case MoneyTransactionType.income:
      return 'income';
  }
}

class MoneyTransaction {
  const MoneyTransaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.sourceWalletId,
    required this.sourceWalletType,
    required this.dateMs,
    required this.createdAtMs,
    required this.type,
    this.note = '',
  });

  final String id;
  final double amount;
  final String category;
  final String sourceWalletId;
  final String sourceWalletType;
  final int dateMs;
  final int createdAtMs;
  final MoneyTransactionType type;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'sourceWalletId': sourceWalletId,
      'sourceWalletType': sourceWalletType,
      'dateMs': dateMs,
      'createdAtMs': createdAtMs,
      'type': moneyTransactionTypeToString(type),
      'note': note,
    };
  }

  static MoneyTransaction fromMap(Map<String, dynamic> map) {
    return MoneyTransaction(
      id: (map['id'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      category: (map['category'] as String?) ?? 'other',
      sourceWalletId: (map['sourceWalletId'] as String?) ?? '',
      sourceWalletType: (map['sourceWalletType'] as String?) ?? 'cash',
      dateMs: (map['dateMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      type: moneyTransactionTypeFromString((map['type'] as String?) ?? ''),
      note: (map['note'] as String?) ?? '',
    );
  }
}
