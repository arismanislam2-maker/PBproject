// Model สำหรับรายการธุรกรรม
class TransactionItem {
  final String title;
  final String date;
  final double amount;
  final bool isIncome; // true = รายรับ, false = รายจ่าย
  final int iconCodePoint; // icon code

  TransactionItem({
    required this.title,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.iconCodePoint,
  });
}
