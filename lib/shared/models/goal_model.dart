class GoalModel {
  final String id;
  final String title;
  final double currentAmount;
  final double targetAmount;
  final int iconCodePoint;
  final bool isCompleted;

  GoalModel({
    required this.id,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.iconCodePoint,
    this.isCompleted = false,
  });

  double get progressPercentage {
    if (targetAmount == 0) return 0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get remainingAmount {
    return (targetAmount - currentAmount).clamp(0.0, double.infinity);
  }

  GoalModel copyWith({
    String? id,
    String? title,
    double? currentAmount,
    double? targetAmount,
    int? iconCodePoint,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      currentAmount: currentAmount ?? this.currentAmount,
      targetAmount: targetAmount ?? this.targetAmount,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
