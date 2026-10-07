// Model สำหรับรายการธุรกรรม
class TransactionItem {
  final String title;
  final String date;
  final double amount;
  final bool isIncome;
  final int iconCodePoint;
  final bool affectsBalance;
  final DateTime? transactionDate;
  final int? id;

  TransactionItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.iconCodePoint,
    this.affectsBalance = true,
    this.transactionDate,
    this.id,
  });
}
