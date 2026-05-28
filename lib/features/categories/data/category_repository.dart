import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:sqflite/sqflite.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Category>> getCategories() async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}
