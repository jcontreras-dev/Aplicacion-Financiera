import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finance_app/features/transactions/domain/transaction_provider.dart';
import 'package:finance_app/features/categories/domain/category_provider.dart';
import 'package:finance_app/features/export_import/domain/export_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import 'package:finance_app/core/design_system/app_colors.dart';
import 'package:finance_app/core/design_system/app_spacing.dart';
import 'package:finance_app/core/design_system/app_radius.dart';
import 'package:finance_app/core/design_system/app_text_styles.dart';
import 'package:finance_app/core/design_system/app_card.dart';
import 'package:finance_app/core/design_system/app_button.dart';
import 'package:finance_app/core/design_system/app_empty_state.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  String _filterType = 'all'; // 'all', 'income', 'expense'
  String _searchQuery = '';

  void _exportCsv() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      final txs = await ref.read(transactionsProvider.future);
      final cats = await ref.read(categoriesProvider.future);
      double tIncome = 0;
      double tExpense = 0;
      for (var t in txs) {
        if (t.isIncome) tIncome += t.amount; else tExpense += t.amount;
      }
      final balance = tIncome - tExpense;
      final path = await ExportService.exportToCSV(txs, cats, 'Todo el Historial', tIncome, tExpense, balance);
      if (mounted) {
         SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Historial Financiero CSV'));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _exportPdf() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    try {
      final txs = await ref.read(transactionsProvider.future);
      final cats = await ref.read(categoriesProvider.future);
      double tIncome = 0;
      double tExpense = 0;
      for (var t in txs) {
        if (t.isIncome) tIncome += t.amount; else tExpense += t.amount;
      }
      final balance = tIncome - tExpense;
      final path = await ExportService.exportToPDF(txs, cats, 'Todo el Historial', tIncome, tExpense, balance);
      if (mounted) {
         SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Reporte Financiero PDF'));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cats = categoriesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial', style: AppTextStyles.h2),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar Datos',
            onSelected: (val) {
              if (val == 'csv') _exportCsv();
              if (val == 'pdf') _exportPdf();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'csv', child: Text('Generar CSV')),
              const PopupMenuItem(value: 'pdf', child: Text('Generar PDF')),
            ]
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar transacción...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderMd,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.toLowerCase());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filterType == 'all',
                    onSelected: (_) => setState(() => _filterType = 'all'),
                  ),
                  ChoiceChip(
                    label: const Text('Ingresos'),
                    selected: _filterType == 'income',
                    onSelected: (_) => setState(() => _filterType = 'income'),
                    selectedColor: AppColors.success.withValues(alpha: 0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Gastos'),
                    selected: _filterType == 'expense',
                    onSelected: (_) => setState(() => _filterType = 'expense'),
                    selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (txs) {
                final filtered = txs.where((tx) {
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
                    title: 'No se encontraron registros',
                    subtitle: 'Intenta cambiar los filtros o la búsqueda',
                    icon: Icons.search_off_rounded,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        onTap: () {
                           if (tx.receiptImagePath != null) {
                              showDialog(context: context, builder: (_) => AlertDialog(
                                 title: const Text('Comprobante Adjunto', style: AppTextStyles.h3),
                                 content: ClipRRect(
                                   borderRadius: AppRadius.borderMd,
                                   child: Image.file(File(tx.receiptImagePath!))
                                 ),
                                 actions: [
                                   AppSecondaryButton(
                                     text: 'Cerrar',
                                     isFullWidth: false,
                                     onPressed: ()=>Navigator.pop(context),
                                   )
                                 ]
                              ));
                           }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: tx.isIncome ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(tx.isIncome ? Icons.arrow_downward : Icons.arrow_upward, 
                                color: tx.isIncome ? AppColors.success : AppColors.danger, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(tx.description, 
                                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        )
                                      ),
                                      Text(NumberFormat.currency(symbol: '\$').format(tx.amount), 
                                        style: AppTextStyles.bodyLarge.copyWith(
                                          color: tx.isIncome ? AppColors.success : AppColors.danger,
                                          fontWeight: FontWeight.bold,
                                        )
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(DateFormat('yyyy-MM-dd hh:mm a').format(tx.date), style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                      if (tx.receiptImagePath != null)
                                        Row(
                                          children: [
                                            Icon(Icons.image, size: 14, color: AppColors.secondary),
                                            const SizedBox(width: 4),
                                            Text('Recibo', style: AppTextStyles.label.copyWith(color: AppColors.secondary))
                                          ],
                                        )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () {
                                 showDialog(context: context, builder: (ctx) => AlertDialog(
                                   title: const Text('Eliminar Registro', style: AppTextStyles.h3),
                                   content: const Text('¿Estás seguro que deseas eliminar esta transacción? Tu saldo se recalculará.\n\nEsta acción no se puede deshacer.'),
                                   actions: [
                                     AppSecondaryButton(
                                       text: 'Cancelar',
                                       isFullWidth: false,
                                       onPressed: () => Navigator.pop(ctx)
                                     ),
                                     AppPrimaryButton(
                                       text: 'Eliminar',
                                       isFullWidth: false,
                                       backgroundColor: AppColors.danger,
                                       onPressed: () {
                                          ref.read(transactionsProvider.notifier).removeTransaction(tx.id);
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                            content: const Row(children: [Icon(Icons.delete, color: Colors.white), SizedBox(width: 8), Text('Transacción eliminada')]),
                                            behavior: SnackBarBehavior.floating,
                                            margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 120, left: 16, right: 16),
                                            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                                            backgroundColor: AppColors.danger,
                                          ));
                                       }, 
                                     )
                                   ]
                                 ));
                              }
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, s) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      )
    );
  }
}
