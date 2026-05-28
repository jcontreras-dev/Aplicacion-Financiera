import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/transactions/data/transaction_repository.dart';
import 'package:finance_app/features/export_import/domain/export_service.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<AppTransaction>>(() {
  return TransactionsNotifier();
});

class TransactionsNotifier extends AsyncNotifier<List<AppTransaction>> {
  late TransactionRepository _repository;

  @override
  Future<List<AppTransaction>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    return _fetchTransactions();
  }

  Future<List<AppTransaction>> _fetchTransactions() async {
    return await _repository.getTransactions();
  }

  Future<void> addTransaction(AppTransaction transaction) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.insertTransaction(transaction);
      final txs = await _fetchTransactions();
      ExportService.createAutoJsonBackup(txs);
      return txs;
    });
  }

  Future<void> removeTransaction(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.deleteTransaction(id);
      final txs = await _fetchTransactions();
      ExportService.createAutoJsonBackup(txs);
      return txs;
    });
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(() {
  return SelectedMonthNotifier();
});

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void update(DateTime Function(DateTime) cb) {
    state = cb(state);
  }
}
