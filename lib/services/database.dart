import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide Transaction;

import '../models/transaction.dart';
import 'store.dart';

/// Lưu dữ liệu trên máy (SQLite). Sao lưu đám mây sẽ đồng bộ từ đây.
class AppDatabase implements TxStore {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'tp_wallet.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount INTEGER NOT NULL,
              type TEXT NOT NULL,
              category_id TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              date INTEGER NOT NULL,
              source TEXT NOT NULL,
              bank TEXT,
              raw_text TEXT,
              needs_review INTEGER NOT NULL DEFAULT 0
            )''');
          await db.execute('CREATE INDEX idx_tx_date ON transactions(date)');
          await db.execute('''
            CREATE TABLE category_rules(
              keyword TEXT PRIMARY KEY,
              category_id TEXT NOT NULL
            )''');
        },
      ),
    );
    return AppDatabase._(db);
  }

  @override
  Future<int> insert(Transaction t) => db.insert('transactions', t.toMap());

  @override
  Future<void> update(Transaction t) =>
      db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);

  @override
  Future<void> delete(int id) =>
      db.delete('transactions', where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<Transaction>> inRange(DateTime from, DateTime to) async {
    final rows = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Transaction.fromMap).toList();
  }

  @override
  Future<List<Transaction>> needingReview() async {
    final rows = await db.query('transactions',
        where: 'needs_review = 1', orderBy: 'date DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  /// Đã có giao dịch giống hệt (cùng số tiền, chiều, ngân hàng) trong ±3 phút
  /// chưa? Thông báo ngân hàng hay bị gửi lặp lại.
  @override
  Future<bool> hasNear(Transaction t, {Duration window = const Duration(minutes: 3)}) async {
    final from = t.date.subtract(window).millisecondsSinceEpoch;
    final to = t.date.add(window).millisecondsSinceEpoch;
    final rows = await db.query(
      'transactions',
      columns: ['id'],
      where: 'amount = ? AND type = ? AND date >= ? AND date <= ? AND source != ?'
          ' AND IFNULL(bank, "") = ?',
      whereArgs: [t.amount, t.type.name, from, to, TxSource.manual.name, t.bank ?? ''],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<Map<String, String>> rules() async {
    final rows = await db.query('category_rules');
    return {
      for (final r in rows) r['keyword'] as String: r['category_id'] as String,
    };
  }

  @override
  Future<void> saveRule(String keyword, String categoryId) => db.insert(
        'category_rules',
        {'keyword': keyword, 'category_id': categoryId},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<List<Transaction>> all() async {
    final rows = await db.query('transactions', orderBy: 'date DESC');
    return rows.map(Transaction.fromMap).toList();
  }

  @override
  Future<void> clearAll() async {
    await db.delete('transactions');
    await db.delete('category_rules');
  }
}
