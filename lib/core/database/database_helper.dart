import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('myfinance.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        display_name TEXT NOT NULL,
        status TEXT DEFAULT '',
        currency TEXT DEFAULT 'THB',
        avatar_url TEXT,
        last_login_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        deleted_at TEXT
      )
    ''');

    // Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        account_name TEXT NOT NULL,
        account_type TEXT CHECK(account_type IN ('CASH', 'BANK', 'CREDIT', 'GOAL')),
        initial_balance REAL DEFAULT 0,
        color_hex TEXT,
        icon_name TEXT,
        is_default INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        name TEXT NOT NULL,
        type TEXT CHECK(type IN ('INCOME', 'EXPENSE')),
        icon TEXT,
        color_hex TEXT,
        is_default INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        from_account_id INTEGER,
        to_account_id INTEGER,
        category_id INTEGER,
        amount REAL NOT NULL CHECK(amount > 0),
        transaction_type TEXT CHECK(transaction_type IN ('INCOME', 'EXPENSE', 'TRANSFER', 'TOP_UP')),
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (from_account_id) REFERENCES accounts (id),
        FOREIGN KEY (to_account_id) REFERENCES accounts (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Saving Goals Table
    await db.execute('''
      CREATE TABLE saving_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        target_name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        icon_code_point INTEGER NOT NULL DEFAULT 59621,
        status TEXT CHECK(status IN ('IN_PROGRESS', 'COMPLETED', 'CANCELLED')) DEFAULT 'IN_PROGRESS',
        deadline_date TEXT,
        completed_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id)
      )
    ''');

    // Goal Contributions Table
    await db.execute('''
      CREATE TABLE goal_contributions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL,
        account_id INTEGER NOT NULL,
        transaction_id INTEGER,
        amount REAL NOT NULL,
        contribution_date TEXT NOT NULL,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (goal_id) REFERENCES saving_goals (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id),
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_transactions_user ON transactions(user_id)');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(transaction_date)');
    await db.execute('CREATE INDEX idx_accounts_user ON accounts(user_id)');
    await db.execute('CREATE INDEX idx_categories_user ON categories(user_id)');

    // Insert Default Categories
    await _insertDefaultCategories(db);
  }

  Future _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      // Income
      {'name': 'เงินเดือน', 'type': 'INCOME', 'icon': '💰', 'color_hex': '#5B7A5E', 'is_default': 1},
      {'name': 'รายได้เสริม', 'type': 'INCOME', 'icon': '💼', 'color_hex': '#8B6B52', 'is_default': 1},
      {'name': 'โบนัส', 'type': 'INCOME', 'icon': '🎁', 'color_hex': '#D4A373', 'is_default': 1},
      {'name': 'ดอกเบี้ย', 'type': 'INCOME', 'icon': '📈', 'color_hex': '#6B4F3A', 'is_default': 1},
      
      // Expense
      {'name': 'อาหาร & เครื่องดื่ม', 'type': 'EXPENSE', 'icon': '🍽️', 'color_hex': '#B85C5C', 'is_default': 1},
      {'name': 'ค่าเดินทาง', 'type': 'EXPENSE', 'icon': '🚗', 'color_hex': '#E07A5F', 'is_default': 1},
      {'name': 'ค่าที่พัก', 'type': 'EXPENSE', 'icon': '🏠', 'color_hex': '#6B4F3A', 'is_default': 1},
      {'name': 'ค่าสาธารณูปโภค', 'type': 'EXPENSE', 'icon': '💡', 'color_hex': '#F2CC8F', 'is_default': 1},
      {'name': 'การศึกษา', 'type': 'EXPENSE', 'icon': '📚', 'color_hex': '#81B29A', 'is_default': 1},
      {'name': 'สุขภาพ & ความงาม', 'type': 'EXPENSE', 'icon': '💊', 'color_hex': '#A8DADC', 'is_default': 1},
      {'name': 'บันเทิง', 'type': 'EXPENSE', 'icon': '🎬', 'color_hex': '#F4A261', 'is_default': 1},
      {'name': 'ช้อปปิ้ง', 'type': 'EXPENSE', 'icon': '🛍️', 'color_hex': '#E76F51', 'is_default': 1},
      {'name': 'อื่นๆ', 'type': 'EXPENSE', 'icon': '📦', 'color_hex': '#8A7B70', 'is_default': 1},
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', category);
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE saving_goals ADD COLUMN current_amount REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE saving_goals ADD COLUMN icon_code_point INTEGER NOT NULL DEFAULT 59621',
      );
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE users ADD COLUMN status TEXT DEFAULT ''");
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<void> resetUserFinancialData(int userId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawDelete('''
        DELETE FROM goal_contributions
        WHERE goal_id IN (SELECT id FROM saving_goals WHERE user_id = ?)
           OR account_id IN (SELECT id FROM accounts WHERE user_id = ?)
      ''', [userId, userId]);
      await txn.delete('transactions', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('saving_goals', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('categories', where: 'user_id = ?', whereArgs: [userId]);
      await txn.delete('accounts', where: 'user_id = ?', whereArgs: [userId]);
      await txn.insert('accounts', {
        'user_id': userId,
        'account_name': 'เงินสด',
        'account_type': 'CASH',
        'initial_balance': 0,
        'is_default': 1,
        'color_hex': '#6B4F3A',
        'icon_name': 'cash',
      });
    });
  }
}
