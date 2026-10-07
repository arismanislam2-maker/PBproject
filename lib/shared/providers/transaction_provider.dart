import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';
import '../models/transaction_item.dart';

class TransactionProvider extends ChangeNotifier {
  final List<TransactionItem> _transactions = [];
  double _goalBalanceAdjustment = 0;
  int? _loadedUserId;

  List<TransactionItem> get transactions => _transactions;

  double get totalBalance {
    double total = 0;
    for (final t in _transactions) {
      if (t.affectsBalance) {
        total += t.isIncome ? t.amount : -t.amount;
      }
    }
    return total + _goalBalanceAdjustment;
  }

  /// Moves money between the available balance and saving goals.
  /// A negative amount adds money to a goal; a positive amount withdraws it.
  /// Reflects a transfer already validated and committed by the database.
  void reflectGoalTransfer(double balanceChange) {
    _goalBalanceAdjustment += balanceChange;
    notifyListeners();
  }

  double get totalIncome {
    return _transactions
        .where((t) => t.isIncome && _isInCurrentMonth(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => !t.isIncome && _isInCurrentMonth(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  void addTransaction(TransactionItem item) {
    _transactions.insert(0, item);
    notifyListeners();
  }

  bool _isInCurrentMonth(TransactionItem item) {
    final date = item.transactionDate;
    if (date == null) return true;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  Future<void> loadForUser(int userId) async {
    if (_loadedUserId == userId) return;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'transaction_date DESC, id DESC',
    );
    final loaded = <TransactionItem>[];
    for (final row in rows) {
      final type = row['transaction_type'] as String? ?? '';
      final date = DateTime.tryParse(row['transaction_date'] as String? ?? '');
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      loaded.add(TransactionItem(
        id: (row['id'] as num?)?.toInt(),
        title: (row['description'] as String?)?.trim().isNotEmpty == true
            ? (row['description'] as String).trim()
            : 'รายการ',
        date: date == null
            ? (row['transaction_date'] as String? ?? '')
            : '${date.day}/${date.month}/${date.year + 543}',
        amount: amount,
        isIncome: type == 'INCOME',
        iconCodePoint: type == 'INCOME'
            ? Icons.savings_rounded.codePoint
            : Icons.receipt_long_rounded.codePoint,
        transactionDate: date,
      ));
    }
    _transactions
      ..clear()
      ..addAll(loaded);
    _loadedUserId = userId;
    _goalBalanceAdjustment = 0;
    notifyListeners();
  }

  Future<void> reloadForUser(int userId) async {
    _loadedUserId = null;
    await loadForUser(userId);
  }

  void removeTransaction(int index) {
    _transactions.removeAt(index);
    notifyListeners();
  }
}
