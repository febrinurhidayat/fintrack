
class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String? categoryId;
  final String type;
  final double amount;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;

  final String status;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancelledBy;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amount,
    this.description,
    required this.transactionDate,
    required this.createdAt,
    this.status = 'active',
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
  });

  bool get isIncome => type == 'income';

  bool get isExpense => type == 'expense';

  bool get isActive => status == 'active';

  bool get isCancelled => status == 'cancelled';

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      accountId: map['account_id'].toString(),
      categoryId: map['category_id']?.toString(),
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      transactionDate: DateTime.parse(
        map['transaction_date'].toString(),
      ),
      createdAt: DateTime.parse(
        map['created_at'].toString(),
      ),
      status: map['status'] as String? ?? 'active',
      cancelledAt: map['cancelled_at'] == null
          ? null
          : DateTime.parse(map['cancelled_at'].toString()),
      cancellationReason: map['cancellation_reason'] as String?,
      cancelledBy: map['cancelled_by']?.toString(),
    );
  }
}
