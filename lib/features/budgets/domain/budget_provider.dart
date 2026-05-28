import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/features/budgets/domain/budget.dart';
import 'package:sqflite/sqflite.dart';

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(() {
  return BudgetsNotifier();
});

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() async {
    return _fetchBudgets();
  }

  Future<List<Budget>> _fetchBudgets() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('budgets');
    return maps.map((e) => Budget.fromMap(e)).toList();
  }

  Future<void> setBudget(String categoryId, double limit) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = await DatabaseHelper.instance.database;
      final budget = Budget(categoryId: categoryId, amountLimit: limit);
      await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return _fetchBudgets();
    });
  }

  Future<void> removeBudget(String categoryId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('budgets', where: 'categoryId = ?', whereArgs: [categoryId]);
      return _fetchBudgets();
    });
  }
}

