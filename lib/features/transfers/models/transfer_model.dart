class TransferModel {
  final String id;
  final String userId;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final String? description;
  final DateTime transferDate;
  final DateTime? createdAt;

  const TransferModel({
    required this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.description,
    required this.transferDate,
    this.createdAt,
  });

  factory TransferModel.fromMap(Map<String, dynamic> map) {
    return TransferModel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      fromAccountId: map['from_account_id'].toString(),
      toAccountId: map['to_account_id'].toString(),
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      transferDate: DateTime.parse(
        map['transfer_date'].toString(),
      ),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'].toString()),
    );
  }
}
