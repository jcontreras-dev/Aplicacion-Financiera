import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/categories/domain/category.dart';
import 'package:intl/intl.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';
import 'package:finance_app/features/receipts/domain/image_service.dart';
import 'package:shimmer/shimmer.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  String _filterType = 'all'; // 'all', 'income', 'expense'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cats = categoriesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracto de Movimientos', style: AppTextStyles.h2),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar transacción...',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Consumer(
              builder: (context, ref, child) {
                final selectedMonth = ref.watch(selectedMonthProvider);
                const monthNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
                final monthStr = '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Periodo:', style: AppTextStyles.bodyMedium),
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
                );
              }
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Todos')),
                      ButtonSegment(value: 'income', label: Text('Ingresos')),
                      ButtonSegment(value: 'expense', label: Text('Gastos')),
                    ],
                    selected: {_filterType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _filterType = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.primary;
                        }
                        return AppColors.surfaceLight;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return AppColors.textPrimaryLight;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Expanded(
            child: transactionsAsync.when(
              data: (txs) {
                final selectedMonth = ref.watch(selectedMonthProvider);
                final filtered = txs.where((tx) {
                  if (tx.date.year != selectedMonth.year || tx.date.month != selectedMonth.month) return false;
                  if (_filterType == 'income' && !tx.isIncome) return false;
                  if (_filterType == 'expense' && tx.isIncome) return false;
                  
                  if (_searchQuery.isNotEmpty) {
                    final descMatch = tx.description.toLowerCase().contains(_searchQuery);
                    final amountMatch = tx.amount.toString().contains(_searchQuery);
                    final catMatch = cats.any((c) => c.id == tx.categoryId && c.name.toLowerCase().contains(_searchQuery));
                    if (!descMatch && !amountMatch && !catMatch) return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const AppEmptyState(
                    title: 'No se encontraron movimientos',
                    subtitle: 'No hay transacciones registradas que coincidan con estos filtros.',
                    icon: Icons.receipt_long_rounded,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 100),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.borderLight, indent: 64),
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final cat = cats.firstWhere((c) => c.id == tx.categoryId, orElse: () => Category(id: '', name: 'Otros', icon: 'money', color: '0xFF9E9E9E', isIncome: false));
                    return Dismissible(
                      key: Key(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        color: AppColors.danger,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        ref.read(transactionsProvider.notifier).removeTransaction(tx.id);
                      },
                      child: InkWell(
                        onTap: () async {
                           if (tx.receiptImagePath != null) {
                              final realPath = await ImageService.getResolvedPath(tx.receiptImagePath!);
                              if (context.mounted) _showReceiptModal(context, realPath);
                           }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: tx.isIncome ? AppColors.successLight : AppColors.dangerLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(tx.isIncome ? Icons.add : Icons.remove, 
                                  color: tx.isIncome ? AppColors.success : AppColors.danger, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tx.description, 
                                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(cat.name, style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('•', style: TextStyle(color: AppColors.borderLight)),
                                        const SizedBox(width: 4),
                                        Text(DateFormat('dd MMM').format(tx.date), style: AppTextStyles.label.copyWith(color: AppColors.textSecondaryLight)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${tx.isIncome ? "+" : "-"}${NumberFormat.currency(symbol: '\$').format(tx.amount)}', 
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        color: tx.isIncome ? AppColors.success : AppColors.textPrimaryLight,
                                        fontWeight: FontWeight.w800,
                                      )
                                    ),
                                    if (tx.receiptImagePath != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.attachment, size: 12, color: AppColors.secondary),
                                            Text('Comprobante', style: AppTextStyles.label.copyWith(color: AppColors.secondary, fontSize: 10)),
                                          ],
                                        ),
                                      )
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                  onPressed: () {
                                    ref.read(transactionsProvider.notifier).removeTransaction(tx.id);
                                  },
                                ),
                              ],
                            ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: 6,
                itemBuilder: (context, index) => Shimmer.fromColors(
                  baseColor: AppColors.borderLight,
                  highlightColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: [
                        Container(width: 40, height: 40, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: double.infinity, height: 16, color: Colors.white),
                              const SizedBox(height: 4),
                              Container(width: 100, height: 12, color: Colors.white),
                            ],
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              error: (err, s) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                      SizedBox(height: AppSpacing.md),
                      Text('Hubo un problema', style: AppTextStyles.h2, textAlign: TextAlign.center),
                      SizedBox(height: AppSpacing.sm),
                      Text('No pudimos cargar el historial. Intenta nuevamente.', style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      )
    );
  }

  void _showReceiptModal(BuildContext context, String imagePath) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Comprobante', style: TextStyle(color: Colors.white)),
          ),
          body: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: AppRadius.borderLg,
                child: Image.file(
                  File(imagePath), 
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
