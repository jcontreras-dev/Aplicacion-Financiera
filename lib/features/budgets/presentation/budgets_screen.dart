import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/budgets/domain/budget_provider.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:intl/intl.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showBudgetForm(BuildContext context, WidgetRef ref, {String? categoryId, double? currentLimit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BudgetFormSheet(categoryId: categoryId, currentLimit: currentLimit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Presupuestos', style: AppTextStyles.h2),
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return AppEmptyState(
              title: 'No hay presupuestos',
              subtitle: 'Crea un presupuesto para controlar tus gastos por categoría.',
              icon: Icons.pie_chart_outline,
              action: AppPrimaryButton(
                text: 'Crear Presupuesto',
                icon: Icons.add,
                onPressed: () => _showBudgetForm(context, ref),
                isFullWidth: false,
              ),
            );
          }

          final categories = categoriesAsync.value ?? [];
          final transactions = transactionsAsync.value ?? [];

          final now = DateTime.now();
          final currentMonthTxs = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Aquí puedes establecer límites de gasto para cada categoría. Los colores te indicarán tu progreso mensual.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final budget = budgets[index];
                    final cat = categories.firstWhere((c) => c.id == budget.categoryId, orElse: () => Category(id: '', name: 'Desconocida', icon: 'category', color: '0xFF9E9E9E', isIncome: false));
                    final spent = currentMonthTxs.where((t) => t.categoryId == budget.categoryId && !t.isIncome).fold(0.0, (s, t) => s + t.amount);
                    final percent = (budget.amountLimit > 0) ? (spent / budget.amountLimit).clamp(0.0, 1.0) : 1.0;
                    
                    Color progressColor = AppColors.success;
                    if (percent > 0.85) progressColor = AppColors.danger;
                    else if (percent > 0.5) progressColor = AppColors.warning;

                    final remaining = budget.amountLimit - spent;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: AppColors.secondary, size: 20),
                                      onPressed: () => _showBudgetForm(context, ref, categoryId: budget.categoryId, currentLimit: budget.amountLimit),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                      onPressed: () {
                                        ref.read(budgetsProvider.notifier).removeBudget(budget.categoryId);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Gastado: ${formatter.format(spent)}', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                Text('Límite: ${formatter.format(budget.amountLimit)}', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: AppRadius.borderSm,
                              child: LinearProgressIndicator(
                                value: percent,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                color: progressColor,
                                minHeight: 12,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              remaining >= 0 ? 'Disponible: ${formatter.format(remaining)}' : 'Excedido: ${formatter.format(remaining.abs())}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: progressColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: budgets.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl * 2)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetForm(context, ref),
        label: const Text('Nuevo Presupuesto', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

class _BudgetFormSheet extends ConsumerStatefulWidget {
  final String? categoryId;
  final double? currentLimit;

  const _BudgetFormSheet({this.categoryId, this.currentLimit});

  @override
  ConsumerState<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<_BudgetFormSheet> {
  final _amountController = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categoryId;
    if (widget.currentLimit != null) {
      final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
      _amountController.text = formatter.format(widget.currentLimit).trim();
    }
  }

  void _save() {
    if (_selectedCategory == null || _amountController.text.isEmpty) return;
    
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    ref.read(budgetsProvider.notifier).setBudget(_selectedCategory!, amount);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Presupuesto guardado correctamente'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.categoryId == null ? 'Crear Presupuesto' : 'Editar Presupuesto', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.lg),
            categoriesAsync.when(
              data: (cats) {
                final expenseCats = cats.where((c) => !c.isIncome).toList();
                
                String? safeValue = _selectedCategory;
                if (safeValue != null && !expenseCats.any((c) => c.id == safeValue)) {
                  safeValue = null;
                }

                return DropdownButtonFormField<String>(
                  initialValue: safeValue,
                  decoration: InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                    prefixIcon: const Icon(Icons.category),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  items: expenseCats.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: widget.categoryId == null 
                    ? (val) => setState(() => _selectedCategory = val)
                    : null, // Si está editando, no permitir cambiar categoría
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => const Text('Error al cargar categorías'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                CurrencyTextInputFormatter.currency(
                  symbol: '',
                  decimalDigits: 2,
                )
              ],
              decoration: InputDecoration(
                labelText: 'Monto Límite (\$)',
                border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                prefixIcon: const Icon(Icons.attach_money),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    text: 'Cancelar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppPrimaryButton(
                    text: 'Guardar',
                    onPressed: _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
