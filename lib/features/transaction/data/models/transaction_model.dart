class TransactionModel {
  final int? id;
  final int userId;
  final int? fromAccountId;
  final int? toAccountId;
  final int? categoryId;
  final double amount;
  final String transactionType; // INCOME, EXPENSE, TRANSFER, TOP_UP
  final String? description;
  final String transactionDate;
  final DateTime? createdAt;

  TransactionModel({
    this.id,
    required this.userId,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    required this.amount,
    required this.transactionType,
    this.description,
    required this.transactionDate,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'amount': amount,
      'transaction_type': transactionType,
      'description': description,
      'transaction_date': transactionDate,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      userId: map['user_id'],
      fromAccountId: map['from_account_id'],
      toAccountId: map['to_account_id'],
      categoryId: map['category_id'],
      amount: map['amount']?.toDouble() ?? 0,
      transactionType: map['transaction_type'] ?? '',
      description: map['description'],
      transactionDate: map['transaction_date'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}