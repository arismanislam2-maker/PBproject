class GoalTransaction {
  final String id;
  final double amount;
  final bool isIncome; // true = เงินเข้า, false = เงินออก
  final String date; // formatted display date
  final DateTime createdAt;
  final String? note;

  GoalTransaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.createdAt,
    this.note,
  });
}
