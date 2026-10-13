enum WalletType { cash, bank, mobile }

WalletType walletTypeFromString(String value) {
  switch (value) {
    case 'cash':
      return WalletType.cash;
    case 'bank':
      return WalletType.bank;
    case 'mobile':
      return WalletType.mobile;
    default:
      return WalletType.mobile;
  }
}

String walletTypeToString(WalletType value) {
  switch (value) {
    case WalletType.cash:
      return 'cash';
    case WalletType.bank:
      return 'bank';
    case WalletType.mobile:
      return 'mobile';
  }
}

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.type,
    required this.currentBalance,
    required this.createdAtMs,
    this.bankName = '',
    this.accountName = '',
    this.phoneNumber = '',
    this.savingsBalance = 0,
  });

  final String id;
  final String name;
  final WalletType type;

  /// Real money in the wallet. Derived from the ledger by the repository; the
  /// persisted value is only used once, to migrate data from older builds.
  final double currentBalance;
  final int createdAtMs;
  final String bankName;
  final String accountName;
  final String phoneNumber;

  /// Part of [currentBalance] tagged as savings. Derived, never persisted.
  final double savingsBalance;

  bool get isOnline => type != WalletType.cash;

  /// Money in this wallet that is free to spend (balance minus savings).
  double get spendable {
    final value = currentBalance - savingsBalance;
    return value < 0 ? 0 : value;
  }

  Wallet copyWith({
    String? id,
    String? name,
    WalletType? type,
    double? currentBalance,
    int? createdAtMs,
    String? bankName,
    String? accountName,
    String? phoneNumber,
    double? savingsBalance,
  }) {
    return Wallet(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      savingsBalance: savingsBalance ?? this.savingsBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': walletTypeToString(type),
      'currentBalance': currentBalance,
      'createdAtMs': createdAtMs,
      'bankName': bankName,
      'accountName': accountName,
      'phoneNumber': phoneNumber,
    };
  }

  static Wallet fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed Wallet',
      type: walletTypeFromString((map['type'] as String?) ?? 'mobile'),
      currentBalance: (map['currentBalance'] as num?)?.toDouble() ?? 0,
      createdAtMs:
          (map['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      bankName: (map['bankName'] as String?) ?? '',
      accountName: (map['accountName'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
    );
  }
}
