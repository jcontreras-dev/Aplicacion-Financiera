import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/categories/domain/category.dart';

class TransactionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertTransaction(AppTransaction transaction) async {
    final db = await _dbHelper.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<AppTransaction>> getTransactions() async {
    final db = await _dbHelper.database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((map) => AppTransaction.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories');
    return maps.map((map) => Category.fromMap(map)).toList();
  }
}
