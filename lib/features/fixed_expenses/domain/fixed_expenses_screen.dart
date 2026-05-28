import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:finance_app/features/fixed_expenses/domain/fixed_expense.dart';
import 'package:finance_app/features/fixed_expenses/domain/fixed_expense_provider.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';

class FixedExpensesScreen extends ConsumerWidget {
  const FixedExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(fixedExpensesProvider);
    final paidAsync = ref.watch(fixedExpensePaymentProvider);
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gastos Fijos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          final paidIds = paidAsync.value ?? [];
          final totalFijo = expenses.fold(0.0, (s, e) => s + e.amount);
          final totalPagado = expenses
              .where((e) => paidIds.contains(e.id))
              .fold(0.0, (s, e) => s + e.amount);
          final totalPendiente = totalFijo - totalPagado;

          return Column(
            children: [
              // Resumen
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        label: 'Total fijo',
                        amount: formatter.format(totalFijo),
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        label: 'Pagado',
                        amount: formatter.format(totalPagado),
                        color: Colors.green.shade700,
                      ),
                    ),
                    Expanded(
                      child: _SummaryItem(
                        label: 'Pendiente',
                        amount: formatter.format(totalPendiente),
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              if (expenses.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No tienes gastos fijos registrados.\n¡Agrega uno con el botón +!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final isPaid = paidIds.contains(expense.id);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isPaid
                                ? Colors.green.withValues(alpha: 0.4)
                                : Colors.red.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isPaid
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            child: Icon(
                              isPaid ? Icons.check_circle : Icons.schedule,
                              color: isPaid ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            expense.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Vence el día ${expense.dayOfMonth} de cada mes'
                            '${expense.notes != null ? '\n${expense.notes}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatter.format(expense.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPaid ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPaid ? 'Pagado' : 'Pendiente',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPaid ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            ref.read(fixedExpensePaymentProvider.notifier)
                                .togglePaid(expense.id, isPaid);
                          },
                          onLongPress: () => _confirmDelete(context, ref, expense),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar Gasto Fijo'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int dayOfMonth = 1;
    String? selectedCategoryId;

    final categories = ref.read(categoriesProvider).value ?? [];
    final expenseCategories = categories.where((c) => !c.isIncome).toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Gasto Fijo', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (ej: Arriendo)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [CurrencyTextInputFormatter.currency(symbol: '', decimalDigits: 0)],
                  decoration: const InputDecoration(
                    labelText: 'Monto (\$)',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                  items: expenseCategories.map((cat) {
                    return DropdownMenuItem(value: cat.id, child: Text(cat.name));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Día de vencimiento: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<int>(
                        value: dayOfMonth,
                        isExpanded: true,
                        items: List.generate(28, (i) => i + 1).map((d) {
                          return DropdownMenuItem(value: d, child: Text('Día $d'));
                        }).toList(),
                        onChanged: (val) => setState(() => dayOfMonth = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final rawAmount = amountCtrl.text.replaceAll(',', '');
                final amount = double.tryParse(rawAmount);
                if (name.isEmpty || amount == null || selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor completa todos los campos')),
                  );
                  return;
                }
                final expense = FixedExpense(
                  id: const Uuid().v4(),
                  name: name,
                  amount: amount,
                  categoryId: selectedCategoryId!,
                  dayOfMonth: dayOfMonth,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                ref.read(fixedExpensesProvider.notifier).addFixedExpense(expense);
                Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, FixedExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto fijo'),
        content: Text('¿Eliminar "${expense.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(fixedExpensesProvider.notifier).removeFixedExpense(expense.id);
    }
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryItem({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onPrimaryContainer)),
        const SizedBox(height: 4),
        Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}