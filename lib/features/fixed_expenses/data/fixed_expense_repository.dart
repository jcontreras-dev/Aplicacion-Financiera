import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/features/fixed_expenses/domain/fixed_expense.dart';
import 'package:sqflite/sqflite.dart';

class FixedExpenseRepository {
  final _db = DatabaseHelper.instance;

  Future<List<FixedExpense>> getFixedExpenses() async {
    final db = await _db.database;
    final result = await db.query('fixed_expenses', orderBy: 'dayOfMonth ASC');
    return result.map((map) => FixedExpense.fromMap(map)).toList();
  }

  Future<void> insertFixedExpense(FixedExpense expense) async {
    final db = await _db.database;

    final data = {
      'id': expense.id,
      'name': expense.name,
      'amount': expense.amount,
      'categoryId': expense.categoryId,
      'dayOfMonth': expense.dayOfMonth,
      'notes': expense.notes,
    };

    await db.insert(
      'fixed_expenses',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFixedExpense(String id) async {
    final db = await _db.database;
    await db.delete('fixed_expenses', where: 'id = ?', whereArgs: [id]);
  }

  // Pagos realizados este mes
  Future<List<String>> getPaidIdsForMonth(int year, int month) async {
    final db = await _db.database;
    final key = '$year-$month';

    final result = await db.query(
      'fixed_expense_payments',
      where: 'monthKey = ?',
      whereArgs: [key],
    );

    return result.map((r) => r['fixedExpenseId'] as String).toList();
  }

  Future<void> markAsPaid(String fixedExpenseId, int year, int month) async {
    final db = await _db.database;
    final key = '$year-$month';

    final data = {
      'fixedExpenseId': fixedExpenseId,
      'monthKey': key,
    };

    await db.insert(
      'fixed_expense_payments',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markAsUnpaid(String fixedExpenseId, int year, int month) async {
    final db = await _db.database;
    final key = '$year-$month';

    await db.delete(
      'fixed_expense_payments',
      where: 'fixedExpenseId = ? AND monthKey = ?',
      whereArgs: [fixedExpenseId, key],
    );
  }
}