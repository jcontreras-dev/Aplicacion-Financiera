import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/transactions/domain/transaction.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:finance_app/features/budgets/domain/budget_provider.dart';
import 'package:finance_app/core/database/database_helper.dart';
import 'package:finance_app/features/export_import/domain/export_service.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';
import 'package:finance_app/core/design_system/app_section_header.dart';
import 'package:finance_app/features/budgets/presentation/budgets_screen.dart' as finance_app_budgets;
import 'package:finance_app/features/categories/presentation/categories_screen.dart' as finance_app_categories;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Resumen Financiero', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/history'),
            tooltip: 'Historial',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (val) async {
              if (val == 'export_pdf' || val == 'export_csv') {
                _showExportFilterDialog(context, ref, val == 'export_pdf');
              }
              if (val == 'categories') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const finance_app_categories.CategoriesScreen()));
              }
              if (val == 'export_drive') {
                try {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respaldando base local antes de restaurar...')));
                  }
                   await ExportService.exportToGoogleDrive();
                   if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Respaldo guardado en Google Drive con éxito!')));
                   }
                } catch(e) {
                   if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
              if (val == 'import_drive') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Restaurar desde Google Drive', style: AppTextStyles.h3),
                    content: const Text('Esta acción reemplazará los datos actuales de este dispositivo con la copia guardada en Google Drive. Antes de continuar, se creará un respaldo local automático.'),
                    actions: [
                      AppSecondaryButton(
                        text: 'Cancelar',
                        isFullWidth: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                      AppPrimaryButton(
                        text: 'Restaurar',
                        isFullWidth: false,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Creando respaldo y descargando de Google Drive...')));
                     }
                     await DatabaseHelper.instance.close();
                     final success = await ExportService.importFromGoogleDrive();
                     if (success) {
                        ref.invalidate(transactionsProvider);
                        ref.invalidate(categoriesProvider);
                        ref.invalidate(budgetsProvider);
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Respaldo restaurado de Google Drive con éxito!')));
                        }
                     }
                  } catch(e) {
                     if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                  }
                }
              }
            },
            itemBuilder: (context) => [
               const PopupMenuItem(value: 'categories', child: Text('Gestionar Categorías 🏷️')),
               const PopupMenuDivider(),
               const PopupMenuItem(value: 'export_pdf', child: Text('Generar Reporte PDF 📄')),
               const PopupMenuItem(value: 'export_csv', child: Text('Generar Reporte Excel (CSV) 📊')),
               const PopupMenuDivider(),
               const PopupMenuItem(value: 'export_drive', child: Text('Respaldar en Google Drive ☁️')),
               const PopupMenuItem(value: 'import_drive', child: Text('Restaurar desde Google Drive ☁️')),
            ]
          )
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const AppEmptyState(
              title: 'No hay transacciones aún',
              subtitle: '¡Registra tu primer gasto para empezar a gestionar tu dinero!',
              icon: Icons.account_balance_wallet_outlined,
            );
          }

          double totalIncome = 0;
          double totalExpense = 0;
          for (var tx in transactions) {
            if (tx.isIncome) {
              totalIncome += tx.amount;
            } else {
              totalExpense += tx.amount;
            }
          }
          final balance = totalIncome - totalExpense;
          final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

          final now = DateTime.now();
          final currentMonthTxs = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
          final prevMonthDate = DateTime(now.year, now.month - 1);
          final prevMonthTxs = transactions.where((t) => t.date.year == prevMonthDate.year && t.date.month == prevMonthDate.month).toList();

          double currentMonthExpense = currentMonthTxs.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
          double prevMonthExpense = prevMonthTxs.where((t) => !t.isIncome).fold(0.0, (sum, t) => sum + t.amount);
          
          double momDiff = 0;
          if (prevMonthExpense > 0) {
            momDiff = ((currentMonthExpense - prevMonthExpense) / prevMonthExpense) * 100;
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _BalanceCard(balance: balance, income: totalIncome, expense: totalExpense, formatter: formatter, momDiff: momDiff),
                ),
              ),
              SliverToBoxAdapter(
                child: _BudgetProgressSection(transactions: currentMonthTxs, formatter: formatter),
              ),
              SliverToBoxAdapter(
                child: AppSectionHeader(
                  title: 'Transacciones Recientes',
                  actionText: 'Ver todo',
                  onActionTap: () => context.push('/history'),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final tx = transactions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          leading: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: tx.isIncome ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward, 
                              color: tx.isIncome ? AppColors.success : AppColors.danger, size: 20),
                          ),
                          title: Text(tx.description, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(tx.date.toString().substring(0,10), style: AppTextStyles.bodySmall),
                          trailing: Text(formatter.format(tx.amount), 
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: tx.isIncome ? AppColors.success : AppColors.danger,
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      ),
                    );
                  },
                  childCount: transactions.length > 7 ? 7 : transactions.length,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl * 2), // Espacio para el FAB
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: InkWell(
        onLongPress: () => context.push('/add', extra: true),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/add', extra: false),
          label: const Text('Nuevo Registro', style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Future<void> _showExportFilterDialog(BuildContext context, WidgetRef ref, bool isPdf) async {
    DateTime? selectedStartDate;
    DateTime? selectedEndDate;
    String selectedFilter = 'Todos';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Exportar ${isPdf ? "PDF" : "CSV"}', style: AppTextStyles.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: const InputDecoration(labelText: 'Filtrar Periodo', border: OutlineInputBorder()),
                    items: ['Todos', 'Este Mes', 'Mes Pasado', 'Personalizado'].map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) async {
                      if (val == 'Personalizado') {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedFilter = val!;
                            selectedStartDate = picked.start;
                            selectedEndDate = picked.end;
                          });
                        }
                      } else {
                        setState(() {
                          selectedFilter = val!;
                        });
                      }
                    },
                  ),
                  if (selectedFilter == 'Personalizado' && selectedStartDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text('Desde: ${DateFormat('yyyy-MM-dd').format(selectedStartDate!)}\nHasta: ${DateFormat('yyyy-MM-dd').format(selectedEndDate!)}', 
                        textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ),
                ],
              ),
              actions: [
                AppSecondaryButton(
                  text: 'Cancelar',
                  isFullWidth: false,
                  onPressed: () => Navigator.pop(context),
                ),
                AppPrimaryButton(
                  text: 'Generar Reporte',
                  isFullWidth: false,
                  onPressed: () {
                    Navigator.pop(context);
                    _executeExport(context, ref, isPdf, selectedFilter, selectedStartDate, selectedEndDate);
                  },
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _executeExport(BuildContext context, WidgetRef ref, bool isPdf, String filter, DateTime? start, DateTime? end) async {
    final transactions = ref.read(transactionsProvider).value ?? [];
    final categories = ref.read(categoriesProvider).value ?? [];
    
    List<AppTransaction> filtered = transactions;
    final now = DateTime.now();
    String reportLabel = "Todo el Historial Histórico";

    if (filter == 'Este Mes') {
      filtered = transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
      reportLabel = "Mes: ${DateFormat('MM/yyyy').format(now)}";
    } else if (filter == 'Mes Pasado') {
      final prev = DateTime(now.year, now.month - 1);
      filtered = transactions.where((t) => t.date.year == prev.year && t.date.month == prev.month).toList();
      reportLabel = "Mes: ${DateFormat('MM/yyyy').format(prev)}";
    } else if (filter == 'Personalizado' && start != null && end != null) {
      final exactEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
      filtered = transactions.where((t) => t.date.isAfter(start.subtract(const Duration(seconds: 1))) && t.date.isBefore(exactEnd)).toList();
      reportLabel = "Del ${DateFormat('dd/MM/yyyy').format(start)} al ${DateFormat('dd/MM/yyyy').format(end)}";
    }

    double tIncome = 0;
    double tExpense = 0;
    for (var t in filtered) {
      if (t.isIncome) tIncome += t.amount; else tExpense += t.amount;
    }
    final balance = tIncome - tExpense;

    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generando documento ${isPdf ? "PDF" : "CSV"}...')));
      String path;
      if (isPdf) {
        path = await ExportService.exportToPDF(filtered, categories, reportLabel, tIncome, tExpense, balance);
      } else {
        path = await ExportService.exportToCSV(filtered, categories, reportLabel, tIncome, tExpense, balance);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Guardado correctamente en tu dispositivo'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Abrir/Compartir',
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Mi Reporte Financiero: $reportLabel')),
          ),
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
    }
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  final NumberFormat formatter;
  final double momDiff;

  const _BalanceCard({required this.balance, required this.income, required this.expense, required this.formatter, required this.momDiff});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Text('Balance Total', style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
          Text(formatter.format(balance), 
            style: AppTextStyles.h1.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer)),
          if (momDiff != 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(momDiff > 0 ? Icons.trending_up : Icons.trending_down, 
                    color: momDiff > 0 ? AppColors.danger : AppColors.success, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text('${momDiff > 0 ? "+" : ""}${momDiff.toStringAsFixed(1)}% vs mes anterior', 
                    style: AppTextStyles.label.copyWith(color: momDiff > 0 ? AppColors.danger : AppColors.success)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(title: 'Ingresos', amount: income, color: AppColors.success, formatter: formatter, isIncome: true),
              _StatItem(title: 'Gastos', amount: expense, color: AppColors.danger, formatter: formatter, isIncome: false),
            ],
          )
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final NumberFormat formatter;
  final bool isIncome;

  const _StatItem({required this.title, required this.amount, required this.color, required this.formatter, required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 16),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(formatter.format(amount), 
          style: AppTextStyles.h3.copyWith(color: color)),
      ],
    );
  }
}

class _BudgetProgressSection extends ConsumerWidget {
  final List<AppTransaction> transactions;
  final NumberFormat formatter;

  const _BudgetProgressSection({required this.transactions, required this.formatter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    if (budgetsAsync.value == null || budgetsAsync.value!.isEmpty) {
       return const SizedBox.shrink();
    }
    
    final budgets = budgetsAsync.value!;
    final categories = categoriesAsync.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'Presupuestos Mensuales',
          actionText: 'Gestionar',
          onActionTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const finance_app_budgets.BudgetsScreen())),
        ),
        ...budgets.map((budget) {
          final cat = categories.firstWhere((c) => c.id == budget.categoryId, orElse: () => Category(id: '', name: 'Desconocida', icon: 'category', color: '0xFF9E9E9E', isIncome: false));
          final spent = transactions.where((t) => t.categoryId == budget.categoryId && !t.isIncome).fold(0.0, (s, t) => s + t.amount);
          final percent = (budget.amountLimit > 0) ? (spent / budget.amountLimit).clamp(0.0, 1.0) : 1.0;
          
          Color progressColor = AppColors.success;
          if (percent > 0.85) progressColor = AppColors.danger;
          else if (percent > 0.5) progressColor = AppColors.warning;

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
                      Text(cat.name, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text('${formatter.format(spent)} / ${formatter.format(budget.amountLimit)}', style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: AppRadius.borderSm,
                    child: LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      color: progressColor,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
