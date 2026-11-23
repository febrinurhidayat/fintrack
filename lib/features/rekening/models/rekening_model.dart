
class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String accountType;
  final String? bankName;
  final String? accountNumber;
  final double initialBalance;
  final double currentBalance;
  final String currency;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    this.bankName,
    this.accountNumber,
    required this.initialBalance,
    required this.currentBalance,
    required this.currency,
    required this.isActive,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['account_id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] as String,
      accountType: map['account_type'] as String,
      bankName: map['bank_name'] as String?,
      accountNumber: map['account_number'] as String?,
      initialBalance: (map['initial_balance'] as num).toDouble(),
      currentBalance: (map['current_balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'IDR',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}
