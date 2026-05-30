import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import 'package:finance_app/features/dashboard/presentation/main_scaffold.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/categories/domain/category.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen Ejecutivo', style: AppTextStyles.h2),
        centerTitle: false,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const AppEmptyState(
              title: 'Bienvenido a tu panel',
              subtitle: 'Registra transacciones para visualizar tus métricas',
              icon: Icons.dashboard_customize_outlined,
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

          final selectedMonth = ref.watch(selectedMonthProvider);
          final currentMonthTxs = transactions.where((t) => t.date.year == selectedMonth.year && t.date.month == selectedMonth.month).toList();
          
          double currentMonthIncome = 0;
          double currentMonthExpense = 0;
          final Map<String, double> expensesByCategory = {};

          for (var tx in currentMonthTxs) {
            if (tx.isIncome) {
              currentMonthIncome += tx.amount;
            } else {
              currentMonthExpense += tx.amount;
              expensesByCategory[tx.categoryId] = (expensesByCategory[tx.categoryId] ?? 0) + tx.amount;
            }
          }

          const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
          final monthStr = '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: _ExecutiveBalanceCard(
                    balance: balance,
                    income: totalIncome,
                    expense: totalExpense,
                    formatter: formatter,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                  child: Text('Acciones rápidas', style: AppTextStyles.h3),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: _QuickActions(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Resumen del mes', style: AppTextStyles.h3),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                            onPressed: () {
                              ref.read(selectedMonthProvider.notifier).update((state) => DateTime(state.year, state.month - 1));
                            },
                          ),
                          Text(monthStr, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                            onPressed: () {
                              ref.read(selectedMonthProvider.notifier).update((state) => DateTime(state.year, state.month + 1));
                            },
                          ),
                        ]
                      )
                    ],
                  )
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ingresos', style: AppTextStyles.label.copyWith(color: AppColors.success)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatter.format(currentMonthIncome), style: AppTextStyles.h2.copyWith(color: AppColors.success))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gastos', style: AppTextStyles.label.copyWith(color: AppColors.danger)),
                              const SizedBox(height: 4),
                              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(formatter.format(currentMonthExpense), style: AppTextStyles.h2.copyWith(color: AppColors.danger))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (currentMonthExpense > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.lg, bottom: AppSpacing.sm),
                    child: _ExpensePieChart(expensesByCategory: expensesByCategory, formatter: formatter),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100), // Espacio para el BottomNavBar y FAB
              ),
            ],
          );
        },
        loading: () => const _DashboardSkeleton(),
        error: (err, stack) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.warning),
                SizedBox(height: AppSpacing.md),
                Text('Servicio temporalmente indisponible', style: AppTextStyles.h2, textAlign: TextAlign.center),
                SizedBox(height: AppSpacing.sm),
                Text('No se pudo cargar la información financiera. Por favor, reinicia la aplicación o revisa tus respaldos en el Centro de Seguridad.', 
                  style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
              ],
            ),
          )
        ),
      ),
    );
  }
}

class _ExecutiveBalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  final NumberFormat formatter;

  const _ExecutiveBalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Balance Histórico', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70, fontWeight: FontWeight.w500)),
              const Icon(Icons.remove_red_eye_outlined, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(formatter.format(balance), 
            style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36)),
          
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Ingresos', style: AppTextStyles.label.copyWith(color: Colors.white70)),
                  Text(formatter.format(income), style: AppTextStyles.bodyLarge.copyWith(color: AppColors.successLight, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Gastos', style: AppTextStyles.label.copyWith(color: Colors.white70)),
                  Text(formatter.format(expense), style: AppTextStyles.bodyLarge.copyWith(color: AppColors.dangerLight, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickActionIcon(icon: Icons.add, label: 'Nuevo', color: AppColors.secondary, onTap: () => context.push('/add', extra: false)),
        _QuickActionIcon(icon: Icons.list_alt, label: 'Historial', color: AppColors.primary, onTap: () => ref.read(bottomNavIndexProvider.notifier).setIndex(1)),
        _QuickActionIcon(icon: Icons.pie_chart_outline, label: 'Presupuestos', color: AppColors.primary, onTap: () => ref.read(bottomNavIndexProvider.notifier).setIndex(2)),
        _QuickActionIcon(icon: Icons.category_outlined, label: 'Categorías', color: AppColors.primary, onTap: () => ref.read(bottomNavIndexProvider.notifier).setIndex(3)),
        _QuickActionIcon(icon: Icons.cloud_upload_outlined, label: 'Exportar', color: AppColors.success, onTap: () => ref.read(bottomNavIndexProvider.notifier).setIndex(4)),
      ],
    );
  }
}

class _QuickActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionIcon({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}


class _ExpensePieChart extends ConsumerWidget {
  final Map<String, double> expensesByCategory;
  final NumberFormat formatter;

  const _ExpensePieChart({required this.expensesByCategory, required this.formatter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final cats = categoriesAsync.value ?? [];

    final total = expensesByCategory.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final sections = expensesByCategory.entries.map((e) {
      final cat = cats.firstWhere((c) => c.id == e.key, orElse: () => Category(id: '', name: 'Otros', icon: 'money', color: '0xFF9E9E9E', isIncome: false));
      final val = (e.value / total) * 100;
      final color = Color(int.parse(cat.color));
      return PieChartSectionData(
        color: color,
        value: val,
        title: '${val.toStringAsFixed(0)}%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribución de Gastos (Mes)', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: expensesByCategory.entries.map((e) {
               final cat = cats.firstWhere((c) => c.id == e.key, orElse: () => Category(id: '', name: 'Otros', icon: 'money', color: '0xFF9E9E9E', isIncome: false));
               return Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(width: 12, height: 12, decoration: BoxDecoration(color: Color(int.parse(cat.color)), shape: BoxShape.circle)),
                   const SizedBox(width: 4),
                   Text(cat.name, style: AppTextStyles.label),
                 ],
               );
            }).toList()
          )
        ],
      )
    );
  }
}


class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.borderLight,
      highlightColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderLg)),
            const SizedBox(height: AppSpacing.md),
            Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderLg)),
            const SizedBox(height: AppSpacing.md),
            Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.borderLg)),
          ],
        ),
      ),
    );
  }
}
