import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

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
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}