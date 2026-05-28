import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/fixed_expenses/domain/fixed_expense.dart';
import 'package:finance_app/features/fixed_expenses/data/fixed_expense_repository.dart';

final fixedExpenseRepositoryProvider = Provider<FixedExpenseRepository>((ref) {
  return FixedExpenseRepository();
});

final fixedExpensesProvider =
    AsyncNotifierProvider<FixedExpensesNotifier, List<FixedExpense>>(() {
  return FixedExpensesNotifier();
});

class FixedExpensesNotifier extends AsyncNotifier<List<FixedExpense>> {
  late FixedExpenseRepository _repository;

  @override
  Future<List<FixedExpense>> build() async {
    _repository = ref.watch(fixedExpenseRepositoryProvider);
    return _repository.getFixedExpenses();
  }

  Future<void> addFixedExpense(FixedExpense expense) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.insertFixedExpense(expense);
      return _repository.getFixedExpenses();
    });
  }

  Future<void> removeFixedExpense(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteFixedExpense(id);
      return _repository.getFixedExpenses();
    });
  }
}

// Provider para los IDs pagados del mes actual
final paidFixedExpensesProvider =
    FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(fixedExpenseRepositoryProvider);
  final now = DateTime.now();
  return repo.getPaidIdsForMonth(now.year, now.month);
});

// Notifier para marcar pagado/no pagado
final fixedExpensePaymentProvider =
    AsyncNotifierProvider<FixedExpensePaymentNotifier, List<String>>(() {
  return FixedExpensePaymentNotifier();
});

class FixedExpensePaymentNotifier extends AsyncNotifier<List<String>> {
  late FixedExpenseRepository _repository;

  @override
  Future<List<String>> build() async {
    _repository = ref.watch(fixedExpenseRepositoryProvider);
    final now = DateTime.now();
    return _repository.getPaidIdsForMonth(now.year, now.month);
  }

  Future<void> togglePaid(String fixedExpenseId, bool currentlyPaid) async {
    final now = DateTime.now();
    if (currentlyPaid) {
      await _repository.markAsUnpaid(fixedExpenseId, now.year, now.month);
    } else {
      await _repository.markAsPaid(fixedExpenseId, now.year, now.month);
    }
    state = AsyncValue.data(
      await _repository.getPaidIdsForMonth(now.year, now.month),
    );
  }
}