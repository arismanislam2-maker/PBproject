import '../../../../core/database/database_helper.dart';
import '../../../../shared/models/goal_model.dart';

class GoalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<GoalModel>> getGoals(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'saving_goals',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) {
      final current = (row['current_amount'] as num?)?.toDouble() ?? 0;
      return GoalModel(
        id: row['id'].toString(),
        title: row['target_name'] as String,
        currentAmount: current,
        targetAmount: (row['target_amount'] as num).toDouble(),
        iconCodePoint: (row['icon_code_point'] as num?)?.toInt() ?? 0xe8e5,
        isCompleted: current >= (row['target_amount'] as num).toDouble(),
      );
    }).toList();
  }

  Future<GoalModel> createGoal(int userId, GoalModel goal) async {
    final db = await _dbHelper.database;
    final accounts = await db.query(
      'accounts',
      columns: ['id'],
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'is_default DESC, id ASC',
      limit: 1,
    );
    if (accounts.isEmpty) throw StateError('ไม่พบบัญชีสำหรับเป้าหมายออมเงิน');
    final id = await db.insert('saving_goals', {
      'user_id': userId,
      'account_id': accounts.first['id'],
      'target_name': goal.title,
      'target_amount': goal.targetAmount,
      'current_amount': 0,
      'icon_code_point': goal.iconCodePoint,
      'status': 'IN_PROGRESS',
    });
    return goal.copyWith(id: id.toString());
  }

  /// Moves money between an account and a goal and records the contribution.
  Future<double> transferToGoal({
    required int userId,
    required int goalId,
    required double amount,
    required bool deposit,
    required String? note,
  }) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT g.account_id, g.target_name, g.current_amount, g.target_amount, a.initial_balance
        FROM saving_goals g JOIN accounts a ON a.id = g.account_id
        WHERE g.id = ? AND g.user_id = ? AND a.is_active = 1
      ''', [goalId, userId]);
      if (rows.isEmpty) throw StateError('ไม่พบเป้าหมายหรือบัญชี');
      final current = (rows.first['current_amount'] as num).toDouble();
      final target = (rows.first['target_amount'] as num).toDouble();
      final balance = (rows.first['initial_balance'] as num).toDouble();
      if (deposit && amount > balance) throw StateError('ยอดเงินคงเหลือไม่เพียงพอ');
      if (!deposit && amount > current) throw StateError('ยอดเงินในเป้าหมายไม่เพียงพอ');
      final accountId = rows.first['account_id'] as int;
      final date = DateTime.now().toIso8601String();
      final delta = deposit ? amount : -amount;
      await txn.update('accounts', {'initial_balance': balance + (deposit ? -amount : amount)},
          where: 'id = ?', whereArgs: [accountId]);
      final newAmount = current + delta;
      await txn.update('saving_goals', {
        'current_amount': newAmount,
        'status': newAmount >= target ? 'COMPLETED' : 'IN_PROGRESS',
      }, where: 'id = ?', whereArgs: [goalId]);
      final transactionId = await txn.insert('transactions', {
        'user_id': userId,
        'from_account_id': deposit ? accountId : null,
        'to_account_id': deposit ? null : accountId,
        'amount': amount,
        'transaction_type': deposit ? 'EXPENSE' : 'INCOME',
        'description': deposit
            ? 'เข้าเป้าหมาย: ${rows.first['target_name']}'
            : 'ถอนจากเป้าหมาย: ${rows.first['target_name']}',
        'transaction_date': date,
      });
      await txn.insert('goal_contributions', {
        'goal_id': goalId,
        'account_id': accountId,
        'transaction_id': transactionId,
        'amount': delta,
        'contribution_date': date,
        'note': note,
      });
      return newAmount;
    });
  }
}
