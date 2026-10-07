import '../../../../core/database/database_helper.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int?> getDefaultAccountId(int userId) async {
    final db = await _dbHelper.database;
    final accounts = await db.query(
      'accounts',
      columns: ['id'],
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'is_default DESC, id ASC',
      limit: 1,
    );
    return accounts.isEmpty ? null : accounts.first['id'] as int;
  }

  Future<int> createTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      // Insert transaction
      final id = await txn.insert('transactions', transaction.toMap());
      
      // Update account balance
      if (transaction.transactionType == 'EXPENSE' && transaction.fromAccountId != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET initial_balance = initial_balance - ? WHERE id = ?',
          [transaction.amount, transaction.fromAccountId],
        );
      } else if (transaction.transactionType == 'INCOME' && transaction.toAccountId != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET initial_balance = initial_balance + ? WHERE id = ?',
          [transaction.amount, transaction.toAccountId],
        );
      }
      
      return id;
    });
  }

  Future<List<TransactionModel>> getTransactions(int userId, {int? limit}) async {
    final db = await _dbHelper.database;
    
    final result = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'transaction_date DESC',
      limit: limit,
    );
    
    return result.map((map) => TransactionModel.fromMap(map)).toList();
  }

  Future<Map<String, double>> getMonthlySummary(int userId, int year, int month) async {
    final db = await _dbHelper.database;
    
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();
    
    final result = await db.rawQuery('''
      SELECT 
        transaction_type,
        SUM(amount) as total
      FROM transactions
      WHERE user_id = ? AND transaction_date >= ? AND transaction_date < ?
      GROUP BY transaction_type
    ''', [userId, startDate, endDate]);
    
    double income = 0;
    double expense = 0;
    
    for (var row in result) {
      if (row['transaction_type'] == 'INCOME') {
        income = (row['total'] as num?)?.toDouble() ?? 0;
      } else if (row['transaction_type'] == 'EXPENSE') {
        expense = (row['total'] as num?)?.toDouble() ?? 0;
      }
    }
    
    return {'income': income, 'expense': expense};
  }

  Future<Map<String, dynamic>> getReportData({
    required int userId,
    required int year,
    required int month,
    required String transactionType,
  }) async {
    final db = await _dbHelper.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT t.id, t.amount, t.description, t.transaction_date,
             COALESCE(f.account_name, ta.account_name) AS account_name,
             COALESCE(c.name, t.description, 'อื่นๆ') AS category
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts f ON f.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      WHERE t.user_id = ? AND t.transaction_type = ?
        AND t.transaction_date >= ? AND t.transaction_date < ?
      ORDER BY t.transaction_date DESC
    ''', [userId, transactionType, start, end]);

    final totals = <String, double>{};
    var total = 0.0;
    for (final row in rows) {
      final category = (row['category'] as String?)?.trim();
      final name = category == null || category.isEmpty ? 'อื่นๆ' : category;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      totals[name] = (totals[name] ?? 0) + amount;
      total += amount;
    }
    return {'total': total, 'categories': totals, 'transactions': rows};
  }

  Future<double> getTotalBalance(int userId) async {
    final db = await _dbHelper.database;
    
    final result = await db.rawQuery('''
      SELECT SUM(initial_balance) as total
      FROM accounts
      WHERE user_id = ? AND is_active = 1
    ''', [userId]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) return;
      final row = rows.first;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final type = row['transaction_type'] as String?;
      final fromAccountId = (row['from_account_id'] as num?)?.toInt();
      final toAccountId = (row['to_account_id'] as num?)?.toInt();

      final contributions = await txn.query(
        'goal_contributions',
        where: 'transaction_id = ?',
        whereArgs: [id],
      );
      for (final contribution in contributions) {
        final goalId = (contribution['goal_id'] as num?)?.toInt();
        final delta = (contribution['amount'] as num?)?.toDouble() ?? 0;
        if (goalId == null) continue;
        final goals = await txn.query('saving_goals',
            where: 'id = ?', whereArgs: [goalId], limit: 1);
        if (goals.isEmpty) continue;
        final goal = goals.first;
        final current = (goal['current_amount'] as num?)?.toDouble() ?? 0;
        final target = (goal['target_amount'] as num?)?.toDouble() ?? 0;
        final updated = current - delta;
        await txn.update(
          'saving_goals',
          {
            'current_amount': updated,
            'status': updated >= target ? 'COMPLETED' : 'IN_PROGRESS',
            'completed_at': updated >= target ? goal['completed_at'] : null,
          },
          where: 'id = ?',
          whereArgs: [goalId],
        );
      }
      await txn.delete('goal_contributions', where: 'transaction_id = ?', whereArgs: [id]);

      if (type == 'EXPENSE' && fromAccountId != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET initial_balance = initial_balance + ? WHERE id = ?',
          [amount, fromAccountId],
        );
      } else if (type == 'INCOME' && toAccountId != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET initial_balance = initial_balance - ? WHERE id = ?',
          [amount, toAccountId],
        );
      }
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
  }
}
